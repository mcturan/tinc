# MASTER SPEC

Authoritative system definition.

All logic MUST be derived from sub-specs.

---

## SYSTEM

TINC — event-driven, offline-first platform.
Apps: QRVEE · PNOT · MINWIN
Communication: Firebase event collections only. No direct app calls.

---

## ENTITIES

| Entity | Defined in |
|--------|-----------|
| User | DATA_MODEL.md |
| Session | DATA_MODEL.md |
| QSO | DATA_MODEL.md |
| OperatorState | DATA_MODEL.md |
| WorkItem | DATA_MODEL.md |

---

## EVENTS

| Event | Trigger | Pre-condition | Defined in |
|-------|---------|---------------|-----------|
| QSO_START | operator begins session | activeSessionId == null | EVENT_CONTRACTS.md |
| QSO_END | session ends | Session.userId == auth.uid | EVENT_CONTRACTS.md |
| USER_ONLINE | user becomes reachable | — | EVENT_CONTRACTS.md |
| USER_OFFLINE | user becomes unreachable | — | EVENT_CONTRACTS.md |
| WORK_CREATED | work item defined | workItemId not exists | EVENT_CONTRACTS.md |
| WORK_STARTED | work begins | status==PLANNED, deps DONE, time reached | EVENT_CONTRACTS.md |
| WORK_PROGRESS | progress updated | status==ACTIVE | EVENT_CONTRACTS.md |
| WORK_COMPLETED | work finished | status==ACTIVE | EVENT_CONTRACTS.md |

---

## STATE CHANGES & LEDGER

Every event → defined state changes + double-entry ledger pair (where applicable).
Full mapping: TRANSACTION_MAPPING.md
Ledger rules: LEDGER_RULES.md

Double-entry invariant: SUM(DR + CR) == 0 per transaction. (LAW-001)

---

## FLOW ENGINE

The Flow Engine is a core system layer, not a page or UI component.

**Responsibilities:**
- Consumes all events
- Updates WorkItem state based on events and serverTime
- Emits visual state for dashboard consumption
- Re-evaluates `isActive` as serverTime advances (time-driven)

**Rules:**
- serverTime is the only time authority (no clientTime in business logic)
- No client may directly mutate WorkItem state — only via events
- Flow Engine operates server-side (Cloud Function or equivalent)
- Idempotent: replaying events produces identical state

**Dashboard integration:**
- Flow Engine is NOT a page
- Flow Engine feeds ALL dashboards as a data layer
- Dashboard implementations:
  - Full-screen timeline: WorkItems on time axis, colored by status
  - Widget embedding: any dashboard may embed WorkItem status widgets
- UI reads derived state from Flow Engine output — never computes state client-side

---

## IDEMPOTENCY

All events are idempotent. Key = event.id (UUID).
Duplicate processing = skip, not error.
Ledger entries keyed by eventId — duplicate write = skip.

---

## CONCURRENCY

One active session per user at a time.
Concurrent session attempt → REJECT (CONCURRENT_SESSION_CONFLICT).
Client must emit QSO_END before starting a new QSO_START.

---

## SECURITY

| Rule | Constraint |
|------|-----------|
| Identity | event.userId must equal Firebase auth.uid |
| Ownership | session close only by session owner |
| Write isolation | OperatorState writable only by owning user |
| QSO authorship | QSO.ownerUid must equal auth.uid |

---

## GEO CONSTRAINTS

latitude: ∈ [-90, 90]
longitude: ∈ [-180, 180]
Enforced on Session write and QSO_START payload.

---

## VALIDATION

All entities and events validated before write.
Full rules: VALIDATION_RULES.md

---

## CALCULATIONS

All derived values (durations, counts, aggregations, progressRate, isActive) are deterministic.
Full rules: CALCULATION_RULES.md

---

## UI BRIDGE

The UI Bridge is the contract layer between the Flow Engine and all dashboard components.
Full definition: FLOW_UI_BRIDGE.md

**FlowViewModel buckets:**
- `activeWorkItems` — status==ACTIVE AND isActive==true
- `upcomingWorkItems` — status==PLANNED, sorted by startAt ASC
- `completedWorkItems` — status==DONE, sorted by updatedAt DESC
- `blockedWorkItems` — status==BLOCKED

**FlowWidget:**
- Stateless, read-only component
- Receives FlowViewModel — does not query Firestore
- Modes: `timeline` (time axis) | `list` (grouped)
- Embeddable in any dashboard

**Plan Dashboard:**
- Full-screen FlowWidget in timeline mode
- Sole data source: FlowViewModel from Flow Engine

**Invariant:** No dashboard reads WorkItems from Firestore directly. All UI state derives from FlowViewModel. (FD-5)

---

## GAME LAYER

The Game Layer is a non-core, non-intrusive engagement system layered on top of the existing architecture.

**Position in architecture:**
- Sits above the UI Bridge
- Reads from FlowViewModel only — never from raw data sources
- No write access to any store, ledger, or Firestore collection

**Strict constraints:**
- MUST NOT mutate any WorkItem, FlowViewModel, or ledger entry
- MUST NOT block or delay any core system operation
- MUST NOT render unless user has opted in (non-mandatory)
- MUST NOT affect performance of the core flow engine

**No mutation rule:**
Game system components are read-only observers. Any state the game maintains is isolated in `useGameStore`. No side effects on system state.

**View-model-only rule:**
All game logic derives exclusively from FlowViewModel fields. No direct Firestore access. No computed state outside the game layer.

**Boundary:** Game layer may be entirely disabled without affecting any other system behavior.

Full definition: GAME_SYSTEM_MASTER.md + GAME_SYSTEM_INTENT.md

---

## DESIGN PIPELINE

The design pipeline defines how UI components are specified and implemented.

**Flow:** Gemini → DesignSpec (FINAL) → Codex (implements) → Claude (validates)

**DesignSpec:**
- Markdown file produced by Gemini
- Defines: intent, layout, states, tokens, motion, constraints, anti-patterns
- Must reach FINAL status before Codex begins
- Stored in: `/DESIGN_SPECS/` directory

**No deviation rule:**
Codex output that deviates from a FINAL DesignSpec = INVALID. (LAW-016)

Full format: DESIGN_SPEC_FORMAT.md
Agent roles: AGENT_PROTOCOL.md

---

## ENFORCEMENT

Any deviation from this spec = REJECT.
Full triggers: ENFORCEMENT.md
