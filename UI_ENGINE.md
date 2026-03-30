# UI Runtime Engine

**Version:** 1.0
**Date:** 2026-03-30
**Phase:** 4
**Input:** UI_PLATFORM.md
**Status:** Design — implementation pending

---

## 1. Engine Role

The UI Engine is the runtime layer that sits between the Dashboard shell and the individual widgets. It owns three responsibilities:

### 1.1 Widget Lifecycle Management

The engine controls when widgets are born, fed, and destroyed:

```
MOUNT     → initialize(context)  — subscriptions set up
ACTIVE    → onData(data)         — data pushed whenever source updates
HIDDEN    → subscriptions paused — no data push, no re-render
UNMOUNT   → destroy()            — all subscriptions torn down
ERROR     → error boundary       — widget isolated, rest of dashboard unaffected
```

Visibility is the key lifecycle trigger. A hidden widget (visible: false) has its data subscriptions paused — not destroyed — so it can resume instantly when made visible again.

### 1.2 Data Distribution

The engine is the sole owner of data subscriptions. Widgets never open Firestore listeners or call Cloud Functions directly. Instead:

1. Engine reads each widget's `dataSource` declaration at mount time
2. Engine opens one subscription per unique data source (deduplication — two widgets sharing the same Firestore collection share one listener)
3. When a subscription emits new data, engine calls `widget.onData(data)` for all mounted widgets that declared that source
4. On widget unmount, engine checks reference count — closes subscription only when zero widgets use it

### 1.3 Render Orchestration

The engine does not render widgets itself. It triggers widget re-renders by updating widget state, which React/RN reconciles. The engine manages:

- **Batching:** Multiple data updates in the same tick are batched into one render cycle
- **Priority:** User-interaction-triggered updates (e.g., config change) render synchronously; background data updates render via scheduler (low priority)
- **Skeletons:** Engine shows loading skeleton from mount until first `onData()` call completes

---

## 2. Execution Flow

### 2.1 App Load → Dashboard Ready

```
1. App boots
   └─ AuthProvider confirms user session
        └─ DashboardShell mounts

2. DashboardShell loads config
   └─ Firestore: GET /users/{uid}/dashboards/{appId}
        └─ If missing → write DEFAULT_TILES config
        └─ Resolves: DashboardConfig { layout, widgets: WidgetInstance[] }

3. Engine.init(config)
   └─ For each WidgetInstance where visible == true:
        a. Resolve WidgetDefinition from WidgetRegistry[instance.type]
        b. Build WidgetContext (userId, appId, config, emit, refresh, isPro, theme)
        c. Deduplicate data sources across all visible widgets
        d. Open subscriptions for unique data sources
        e. Call widget.initialize(context)
        f. Render widget shell with loading skeleton

4. Subscriptions emit initial data
   └─ Engine calls widget.onData(data) for each subscriber
        └─ Widget state transitions: loading=true → loading=false, data=<payload>
        └─ React reconciler renders widget content (skeleton removed)

5. Dashboard is interactive
```

### 2.2 Widget Becomes Visible (user toggles on)

```
User enables widget in marketplace modal
  └─ DashboardConfig updated in Firestore (optimistic)
       └─ Engine.onWidgetVisible(instance)
            └─ Resolve WidgetDefinition
            └─ Build WidgetContext
            └─ Resume or open data source subscriptions (refcount++)
            └─ widget.initialize(context)
            └─ Animate widget into grid (CSS transition / Reanimated)
```

### 2.3 Widget Becomes Hidden

```
User disables widget
  └─ DashboardConfig updated in Firestore (optimistic)
       └─ Engine.onWidgetHidden(instanceId)
            └─ widget.destroy()
            └─ Decrement refcount for each data source
            └─ If refcount == 0 → close subscription
            └─ Animate widget out of grid
```

### 2.4 Real-Time Data Update

```
Firestore listener fires (e.g., new session document)
  └─ Engine.onSourceUpdate(sourceId, data)
       └─ Find all mounted widgets subscribed to sourceId
       └─ Batch updates (flush next animation frame)
       └─ For each widget: widget.onData(transformedData)
            └─ Widget local state updates
            └─ React schedules re-render (low priority)
```

### 2.5 Widget Interaction → Shell

```
User clicks button inside widget
  └─ widget.onInteraction(event)
       └─ widget calls context.emit(WidgetEvent)
            └─ Engine.onWidgetEvent(instanceId, event)
                 └─ Switch on event.type:
                      'navigate'     → router.push(route)
                      'tune'         → radioStore.setFrequency(freq)
                      'log_qso'      → router.push('/logbook?callsign=...')
                      'open_modal'   → modalStore.open(modalId, data)
                      'config_change'→ Engine.updateWidgetConfig(instanceId, payload)
```

---

## 3. Widget Registry

The **WidgetRegistry** is a plain map from `type` string → `WidgetDefinition`. It is the single source of truth for what widgets exist.

### 3.1 Structure

```typescript
type WidgetRegistry = Map<string, WidgetDefinition>;

// Singleton per app — initialized at app startup, never mutated at runtime
const WIDGET_REGISTRY: WidgetRegistry = new Map([
  ['oracle',        OracleWidgetDefinition],
  ['rig',           RigWidgetDefinition],
  ['league',        LeagueWidgetDefinition],
  ['signal_stream', SignalStreamWidgetDefinition],
  ['stats',         StatsWidgetDefinition],
  ['friends',       FriendsWidgetDefinition],
  ['dx_cluster',    DXClusterWidgetDefinition],
  ['grayline',      GraylineWidgetDefinition],
  ['world_clock',   WorldClockWidgetDefinition],
  ['map',           MapWidgetDefinition],
  ['actions',       ActionsWidgetDefinition],
  ['ai_companions', AICompanionsWidgetDefinition],
  ['smart_shack',   SmartShackWidgetDefinition],
  // ... add new widgets here only
]);
```

### 3.2 Registry Rules

- **Immutable at runtime.** The registry is built once at app start and never modified.
- **Unknown types are safe.** If `WidgetInstance.type` is not in the registry, the engine renders an `UnknownWidget` placeholder (not a crash).
- **Platform filtering.** On mobile, the engine filters the registry to `definition.platforms.includes('mobile')` before resolving. A web-only tile on a mobile dashboard renders the `UnknownWidget` placeholder.
- **Pro filtering.** Engine checks `definition.pro && !isPro` before calling `initialize()`. Pro widgets for non-Pro users render a `ProGateWidget` overlay — the actual widget component is never loaded.

### 3.3 Adding a New Widget

1. Create `WidgetDefinition` object (type, title, dataSource, render, ...)
2. Add one entry to `WIDGET_REGISTRY`
3. Create the widget component file
4. Done — no other files change

---

## 4. Render Loop

### 4.1 Update Pipeline

```
Data source emits
  │
  ▼
Engine.onSourceUpdate(sourceId, rawData)
  │
  ├─ transform(rawData) → typed TData      (widget-specific transform fn)
  │
  ├─ diff(prevData, newData)               (skip if identical — no re-render)
  │
  ├─ batch queue: [{ widgetId, data }]     (collect within 16ms frame)
  │
  ▼
requestAnimationFrame / React scheduler
  │
  ▼
For each queued update:
  widget.onData(data)
    └─ setWidgetState({ data, loading: false, lastFetch: Date.now() })
         └─ React re-renders widget (diff only — no full tree rebuild)
```

### 4.2 Render Triggers

| Trigger | Priority | Path |
|---------|----------|------|
| User interaction | Synchronous | `onInteraction` → `emit` → shell handler |
| Widget config change | Synchronous | `context.emit('config_change')` → `updateWidgetConfig` → re-render |
| Real-time data update | Low (deferred) | `onSourceUpdate` → batch → `onData` → re-render |
| Manual refresh | High | `context.refresh()` → re-fetch → `onData` → re-render |
| Visibility toggle | Synchronous | `onWidgetVisible/Hidden` → mount/unmount |

### 4.3 Skeleton → Content Transition

```
Widget mounted
  └─ State: { loading: true, data: null }
       └─ Renders: <WidgetSkeleton size={instance.size} />

First onData() call
  └─ State: { loading: false, data: TData }
       └─ Renders: widget content
       └─ Transition: opacity 0→1 (200ms ease-out)

Subsequent onData() calls
  └─ State: { loading: false, data: newData }
       └─ Renders: updated content (no skeleton — content stays visible)
```

### 4.4 Error Handling

Each widget is wrapped in an error boundary at the engine level. If a widget throws:

```
widget.render() throws
  └─ ErrorBoundary catches
       └─ Renders: <WidgetErrorFallback type={instance.type} error={error} />
       └─ Engine logs: console.error('[Engine] widget error', instanceId, error)
       └─ Other widgets: unaffected
       └─ User can: click "Reload" → engine calls widget.destroy() + re-initialize()
```

---

## 5. Isolation Model

### 5.1 Widget Boundary Guarantees

Each widget is isolated at four levels:

| Level | Isolation mechanism |
|-------|-------------------|
| **Data** | Engine dispatches data to specific widget IDs only — no broadcast |
| **State** | Each widget instance has its own `WidgetState` — never shared |
| **Error** | ErrorBoundary per widget — one crash does not cascade |
| **Events** | Widgets emit typed events upward only — no direct widget-to-widget calls |

### 5.2 No Direct Communication Rule

Widgets must not:
- Import other widget components
- Read another widget's state
- Call another widget's methods
- Access global stores directly (stores are injected via context or hook)

If two widgets need to respond to the same user action (e.g., "tune to frequency" updates both the Rig widget and the DX Cluster widget), the event goes through the engine:

```
Widget A emits: { type: 'tune', payload: { frequency: 14074 } }
  └─ Engine handles: radioStore.setFrequency(14074)
       └─ Rig widget re-renders (via store subscription)
       └─ DX Cluster widget re-renders (via store subscription)
```

Both widgets react to the same store change independently. Neither knows the other exists.

### 5.3 Context Injection vs. Global Import

| Allowed | Forbidden |
|---------|-----------|
| `context.userId` | `import { auth } from '@/lib/firebase'` inside widget |
| `context.emit(event)` | `import { useRouter } from 'next/navigation'` inside widget |
| `context.refresh()` | `import { useRadioStore } from '@/store/useRadioStore'` inside widget |
| `context.config` | Accessing `window`, `localStorage` directly |

All external dependencies are injected by the engine via `WidgetContext`. Widgets are pure functions of their state and context.

---

## 6. Engine API (TypeScript Interface)

```typescript
interface UIEngine {
  // Lifecycle
  init(config: DashboardConfig, registry: WidgetRegistry): void;
  destroy(): void;

  // Widget management
  onWidgetVisible(instance: WidgetInstance): void;
  onWidgetHidden(instanceId: string): void;
  updateWidgetConfig(instanceId: string, config: Record<string, any>): void;

  // Data bus
  onSourceUpdate(sourceId: string, data: unknown): void;

  // Event bus
  onWidgetEvent(instanceId: string, event: WidgetEvent): void;

  // Layout
  reorder(fromIndex: number, toIndex: number): void;
  persistLayout(): void;   // debounced Firestore write

  // State inspection (debug/testing)
  getWidgetState(instanceId: string): WidgetState<unknown, unknown> | null;
  getActiveSubscriptions(): string[];
}
```

---

## 7. Subscription Deduplication

Multiple widgets can declare the same data source. The engine maintains a reference-counted subscription pool:

```
SubscriptionPool {
  sourceId: string           // e.g. "firestore:sessions"
  refCount: number           // how many mounted widgets use this source
  unsubscribe: () => void    // cleanup fn returned by onSnapshot / callable
  lastData: unknown          // cached for newly mounted widgets
}
```

When a widget mounts:
- If pool has `sourceId` → refCount++ → immediately call `widget.onData(pool.lastData)` (no wait)
- If pool missing `sourceId` → open new subscription → add to pool (refCount=1)

When a widget unmounts:
- refCount--
- If refCount == 0 → call `pool.unsubscribe()` → remove from pool

This means: if 3 widgets all watch `events_qrvee`, only ONE Firestore listener is open. All 3 get the same data push simultaneously.

---

## 8. Implementation Notes

This design maps directly onto the existing QRVEE codebase:

| Design concept | Current equivalent | Gap |
|----------------|-------------------|-----|
| WidgetRegistry | `TILE_CATALOG` array in dashboard.tsx | Not a Map; no lifecycle methods |
| Engine.init() | implicit component mount in dashboard.tsx | Scattered across 499 lines |
| onData() | individual `useEffect` hooks per tile | Each tile manages its own subscription |
| emit() | ad-hoc callbacks passed as props | No typed event system |
| Subscription dedup | none — each tile opens its own listener | Duplicate Firestore listeners exist |
| Error boundary | none — one crash breaks full dashboard | Missing |

Phase 4B (dashboard refactor) closes all these gaps without changing any widget behavior.
