# FLOW UI BRIDGE

Defines the contract between the Flow Engine and the Dashboard System.
No styling rules. No rendering implementation.
All data is derived from Flow Engine output — never computed client-side.

---

## PART 1 — FlowViewModel

The FlowViewModel is the single object passed to any dashboard component that displays WorkItem state.

```
FlowViewModel {
  activeWorkItems:    WorkItemView[]   // status == ACTIVE AND isActive == true
  upcomingWorkItems:  WorkItemView[]   // status == PLANNED, sorted by startAt ASC
  completedWorkItems: WorkItemView[]   // status == DONE, sorted by updatedAt DESC
  blockedWorkItems:   WorkItemView[]   // status == BLOCKED
  asOf:               Timestamp        // serverTime at which this view was produced
}
```

**WorkItemView** — a read-only projection of WorkItem for UI consumption:

| Field | Type | Source | Notes |
|-------|------|--------|-------|
| id | string | WorkItem.id | |
| title | string | WorkItem.title | |
| status | WorkItemStatus | WorkItem.status | |
| progress | integer | WorkItem.progress | 0–100 |
| startAt | Timestamp | WorkItem.startAt | |
| endAt | Timestamp | WorkItem.endAt | |
| duration | integer | CALCULATION_RULES.md | milliseconds, derived |
| progressRate | float | CALCULATION_RULES.md | progress/duration, derived |
| isActive | boolean | CALCULATION_RULES.md | derived at read time |
| ownerCallsign | string | resolved from User.callsign | denormalized |
| dependencyCount | integer | COUNT(WorkItem.dependencies) | |
| dependenciesMet | boolean | all dependencies have status == DONE | |

**Rules:**
- `activeWorkItems` includes only items where `isActive == true` (both status==ACTIVE AND time window active)
- Items with `status == ACTIVE` but `isActive == false` (time window expired) are NOT included in any list — they represent a stale state requiring Flow Engine correction
- All lists are immutable snapshots — no client mutation
- `asOf` must be the serverTime used to evaluate `isActive` — not client clock

---

## PART 2 — DATA TRANSFORM

Transform: `WorkItem[] + serverTime → FlowViewModel`

```
FUNCTION buildFlowViewModel(items: WorkItem[], serverTime: Timestamp) → FlowViewModel:

  FOR EACH item IN items:
    duration      = item.endAt.toMillis() - item.startAt.toMillis()
    progressRate  = item.progress / duration
    isActive      = (item.status == ACTIVE)
                    AND (serverTime >= item.startAt)
                    AND (serverTime <= item.endAt)
    dependenciesMet = ALL(dep.status == DONE FOR dep IN item.dependencies)

  PARTITION:
    activeWorkItems    = items WHERE (status == ACTIVE AND isActive == true)
                         SORTED BY startAt ASC
    upcomingWorkItems  = items WHERE (status == PLANNED)
                         SORTED BY startAt ASC
    completedWorkItems = items WHERE (status == DONE)
                         SORTED BY updatedAt DESC
    blockedWorkItems   = items WHERE (status == BLOCKED)
                         SORTED BY updatedAt DESC

  RETURN FlowViewModel {
    activeWorkItems,
    upcomingWorkItems,
    completedWorkItems,
    blockedWorkItems,
    asOf: serverTime
  }
```

**Constraints:**
- `serverTime` is the sole time authority — client clock MUST NOT be used (LAW from MASTER_SPEC)
- Items in status == ACTIVE with expired time window are excluded from output (anomaly — Flow Engine must correct)
- Derived fields (duration, progressRate, isActive) are computed here, not stored
- Transform is deterministic: same inputs → identical output (LAW-007)

---

## PART 3 — UI CONTRACT (FlowWidget API)

FlowWidget is a composable, stateless UI component.

```
FlowWidget {
  input:   FlowViewModel        // required — injected by dashboard
  mode:    "timeline" | "list"  // required — display mode
  filter:  WorkItemStatus[]?    // optional — show only listed statuses
}
```

**Behavior contract:**

| Rule | Constraint |
|------|-----------|
| FW-1 | FlowWidget is READ-ONLY — no mutations |
| FW-2 | FlowWidget receives FlowViewModel — does not query Firestore directly |
| FW-3 | FlowWidget does not compute state — renders only what FlowViewModel provides |
| FW-4 | `mode: "timeline"` — renders WorkItems on time axis (startAt → endAt), colored by status |
| FW-5 | `mode: "list"` — renders WorkItems as grouped list (active / upcoming / completed / blocked) |
| FW-6 | `filter` — if present, only the specified statuses are rendered |
| FW-7 | Empty lists render as empty state — no errors |
| FW-8 | `asOf` timestamp must be displayed or available to consumer for staleness detection |

**Status color mapping** (semantic only — no hex values defined here):

| Status | Semantic |
|--------|---------|
| ACTIVE | active / in-progress indicator |
| PLANNED | neutral / upcoming indicator |
| DONE | complete indicator |
| BLOCKED | warning indicator |

---

## PART 4 — DASHBOARD INTEGRATION

### FlowWidget in any dashboard

Any dashboard may embed a FlowWidget by:
1. Obtaining a `FlowViewModel` from the Flow Engine output layer
2. Passing it to `<FlowWidget input={viewModel} mode="list" />`
3. Optionally filtering by status via `filter` prop

### Plan Dashboard (full-screen)

The Plan Dashboard is the canonical full-screen FlowWidget consumer.

```
PlanDashboard {
  layout:    full-screen
  component: FlowWidget
  mode:      "timeline"
  filter:    null (show all statuses)
  data:      FlowViewModel from Flow Engine (live, server-pushed)
}
```

**Integration rules:**

| Rule | Constraint |
|------|-----------|
| FD-1 | Dashboard never holds local WorkItem state — it subscribes to Flow Engine output |
| FD-2 | Dashboard re-renders when FlowViewModel.asOf advances |
| FD-3 | Plan Dashboard is a full-screen FlowWidget in timeline mode — no additional data sources |
| FD-4 | Widget-embedded dashboards use FlowWidget in list mode with status filter as needed |
| FD-5 | No dashboard may bypass FlowViewModel — direct Firestore WorkItem reads in dashboard = REJECT |

---

## SUMMARY

```
Firestore (WorkItem events)
        ↓
  Flow Engine (server-side)
        ↓
  FlowViewModel (buildFlowViewModel transform)
        ↓
  FlowWidget (stateless, read-only, mode: timeline | list)
        ↓
  Dashboard (Plan Dashboard = full-screen timeline / any dashboard = embedded widget)
```

Data flows in one direction. No client computes state. No dashboard reads Firestore directly.
