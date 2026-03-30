# UI Platform Architecture

**Version:** 1.0
**Date:** 2026-03-30
**Phase:** 4
**Status:** Design — implementation pending

---

## 1. Purpose

This document defines the modular UI platform shared across all QRV ecosystem apps (QRVEE web, QRVEE mobile, PNOT, MINWIN). It establishes:

- A common vocabulary for UI components
- Widget contracts: what a widget is, how it receives data, how it renders
- A layout engine shared across platforms
- A state model driven by the TINC event system
- Modularity rules that prevent duplication and enable central control

The design is inspired by Home Assistant's dashboard (tile-based, user-configurable, persistent layout) combined with iOS UX principles (fluid motion, clear hierarchy, immediate feedback).

---

## 2. Core Concepts

### 2.1 Dashboard

A **Dashboard** is a configurable canvas of widgets for a single user on a single platform. Each app may have one or more dashboards.

Properties:
```
Dashboard {
  id:          string          // "{appId}_{userId}_{dashboardSlug}"
  appId:       AppId           // 'qrvee' | 'pnot' | 'minwin'
  userId:      string
  layout:      LayoutMode      // 'bento' | 'grid' | 'list'
  widgets:     WidgetInstance[]
  lastUpdated: Timestamp
}
```

Persistence: `Firestore /users/{uid}/dashboards/{dashboardId}`

### 2.2 Widget

A **Widget** is a self-contained UI unit. It knows its own data requirements, renders independently, and communicates via well-defined events. Widgets do not talk to each other directly.

A **Widget Definition** (static, registered at app start):
```
WidgetDefinition {
  type:         string              // unique ID: 'oracle', 'rig', 'league', ...
  title:        string              // display name
  description:  string              // shown in marketplace
  icon:         LucideIcon
  category:     WidgetCategory      // 'Radio' | 'Weather' | 'Social' | 'Utilities' | 'Pro'
  platforms:    Platform[]          // ['web'] | ['mobile'] | ['web', 'mobile']
  dataSource:   DataSourceRef[]     // what feeds this widget
  defaultSize:  WidgetSize          // 'small' | 'medium' | 'large' | 'full'
  pro:          boolean             // Pro subscription required
  render:       WidgetRenderer      // platform-specific render function
}
```

A **Widget Instance** (per-user config stored in Firestore):
```
WidgetInstance {
  id:       string                  // unique per dashboard: "{type}_{index}"
  type:     string                  // references WidgetDefinition.type
  visible:  boolean
  order:    number
  size:     WidgetSize              // user override (within allowed range)
  config:   Record<string, any>     // widget-specific user settings
}
```

### 2.3 Layout

A **Layout** defines how widgets are arranged on the canvas.

| Mode | Description | Use Case |
|------|-------------|----------|
| `bento` | Variable-size tiles, Pinterest-style grid | Web dashboard (default) |
| `grid` | Equal-size tiles, fixed columns | Mobile home screen |
| `list` | Single-column stack | Accessibility, small screens |

Layout engine responsibilities:
- Compute grid positions from `order` + `size`
- Handle drag-to-reorder (web) / long-press reorder (mobile)
- Persist layout changes to Firestore debounced (500ms)
- Animate transitions (CSS grid or Reanimated)

### 2.4 Data Source

A **Data Source** is the origin of data that feeds a widget. Three types:

| Type | Description | Examples |
|------|-------------|---------|
| `firestore` | Real-time Firestore listener | sessions, users, logbook |
| `event` | TINC event stream (event_processing / events_*) | processing status, new session events |
| `callable` | Firebase callable CF (on-demand fetch) | oracle, dx_cluster, propagation |

Each widget declares its data sources in `WidgetDefinition.dataSource`. The platform subscribes/unsubscribes automatically when a widget is shown/hidden.

---

## 3. Widget Component Model

### 3.1 Widget Contract

Every widget must implement this contract:

```typescript
interface WidgetContract<TData, TConfig> {
  // Called once when widget is mounted — set up subscriptions
  initialize(context: WidgetContext): void;

  // Receive updated data from the platform data bus
  onData(data: TData): void;

  // Render the widget (platform-specific)
  render(state: WidgetState<TData, TConfig>): UINode;

  // Handle user interactions — emit WidgetEvents
  onInteraction(event: WidgetInteractionEvent): void;

  // Cleanup subscriptions on unmount
  destroy(): void;
}
```

### 3.2 Widget Context

The platform injects context into every widget:

```typescript
interface WidgetContext {
  userId:    string
  appId:     AppId
  config:    Record<string, any>    // this widget's instance config
  emit:      (event: WidgetEvent) => void   // interaction → parent
  refresh:   () => void             // force data re-fetch
  isPro:     boolean
  theme:     Theme
}
```

### 3.3 Widget State

```typescript
interface WidgetState<TData, TConfig> {
  data:      TData | null
  loading:   boolean
  error:     string | null
  config:    TConfig
  lastFetch: number | null          // unix ms
}
```

### 3.4 Widget Events (Interaction → Platform)

Widgets communicate outward only through typed events:

```typescript
type WidgetEvent =
  | { type: 'navigate';   payload: { route: string } }
  | { type: 'tune';       payload: { frequency: number } }
  | { type: 'log_qso';    payload: { callsign?: string } }
  | { type: 'open_modal'; payload: { modalId: string; data?: unknown } }
  | { type: 'config_change'; payload: Record<string, any> }
```

The dashboard shell handles all widget events — widgets never import routing or store dependencies directly.

---

## 4. Shared UI Core

### 4.1 Navigation Bar

Platform-specific implementation, shared contract:

```
Navbar {
  items:    NavItem[]           // defined per app
  active:   string              // current route
  badge:    Record<string, number>  // notification counts per item
  actions:  NavAction[]         // top-right area (theme, search, profile)
}
```

Web: top horizontal bar with icons + labels
Mobile: bottom tab bar (iOS-style, safe-area aware)

### 4.2 Theme System

Single theme token set shared across all apps:

```
Theme {
  // Surface hierarchy
  bg:       string    // main background
  surface:  string    // card surface
  surface2: string    // elevated surface
  border:   string    // dividers

  // Text
  text:     string    // primary text
  muted:    string    // secondary text

  // Brand colors
  blue:     string    // primary actions
  green:    string    // positive / on-air
  yellow:   string    // warning / pending
  red:      string    // error / danger
  purple:   string    // Pro / premium
  orange:   string    // alert / broadcast

  // Mode
  mode: 'dark' | 'light'
}
```

Token naming convention: `qrv-{token}` (Tailwind CSS) / `colors.qrv.{token}` (React Native StyleSheet).

Dark mode is the default. Light mode support is additive (no breaking changes to token names).

### 4.3 Layout System

Grid units (web: CSS Grid, mobile: Flexbox):

| Size | Web columns (of 12) | Mobile rows |
|------|---------------------|-------------|
| small | 3 | 1 |
| medium | 6 | 2 |
| large | 9 | 3 |
| full | 12 | full screen |

Breakpoints (web only):
- `sm` ≥640px → 4-col grid
- `md` ≥768px → 8-col grid
- `lg` ≥1024px → 12-col grid (bento enabled)

---

## 5. State Model

### 5.1 State Layers

Three layers, strict separation:

```
┌─────────────────────────────────────────┐
│  Layer 3 — Server State (Firestore)     │  Source of truth for all persistent data
│  Managed by: Firestore real-time listeners  │
├─────────────────────────────────────────┤
│  Layer 2 — App State (Zustand stores)   │  Derived from server; drives UI
│  Managed by: store subscriptions        │
├─────────────────────────────────────────┤
│  Layer 1 — Local State (React/RN)       │  Ephemeral UI state (loading, open, hover)
│  Managed by: useState / useReducer      │
└─────────────────────────────────────────┘
```

**Rule:** Only Layer 3 is persisted. Layer 2 is always reconstructable from Layer 3. Layer 1 is always reconstructable from Layer 2.

### 5.2 Event-Driven Widget Updates

Widgets that consume TINC events use this flow:

```
TINC Event (events_qrvee / events_pnot)
  └─ Firestore listener (Layer 3)
       └─ Zustand store update (Layer 2)
            └─ Widget.onData() called
                 └─ Widget re-renders (Layer 1)
```

Example: A new `session.started` event triggers the Social Feed widget and the Nearby Friends widget independently — both listen to the same Firestore collection but maintain separate local state.

### 5.3 Real-Time Sync Pattern

```typescript
// Canonical pattern for all event-driven widgets
function useEventFeed(collection: string, userId: string) {
  const [items, setItems] = useState([]);

  useEffect(() => {
    const unsub = onSnapshot(
      query(
        collection(db, collection),
        where('userId', '==', userId),
        orderBy('serverTime', 'desc'),
        limit(50)
      ),
      (snap) => setItems(snap.docs.map(d => ({ id: d.id, ...d.data() })))
    );
    return unsub;    // cleanup on unmount
  }, [userId]);

  return items;
}
```

### 5.4 Offline Behavior

- Firestore SDK caches all listener results locally (IndexedDB on web, SQLite on mobile)
- Widgets render from cache immediately; show staleness indicator if `lastFetch > 5 min`
- Write operations queue locally (OfflineQueue) and flush on reconnect
- OfflineBanner shown when `navigator.onLine === false`

---

## 6. Modularity Rules

### Rule 1 — One Definition, Many Instances

A widget type is defined once in the shared `@qrvee/shared` types package and in the app's widget registry. It can be instantiated multiple times on the same dashboard with different configs.

### Rule 2 — No Cross-Widget Imports

Widgets must never import each other. Shared behavior belongs in a hook (`use*.ts`) or a store (`use*Store.ts`), not in a widget component.

### Rule 3 — Data Source Declaration

Every widget declares its data sources at definition time. The platform uses this to:
- Set up/tear down subscriptions when widget visibility changes
- Show loading skeleton during initial fetch
- Show error state on subscription failure

### Rule 4 — Platform Isolation

Widgets that work on both web and mobile have:
- Shared logic in `@qrvee/shared` or a platform-agnostic hook
- Platform-specific render functions in `apps/web/` and `apps/mobile/` separately
- No `import { Platform } from 'react-native'` in shared logic

### Rule 5 — Config Schema Required

Every widget with user-configurable settings must define a config schema (TypeScript interface + default values) in the `WidgetDefinition`. No inline `Record<string, any>` configs in production widgets.

### Rule 6 — Pro Gating is Declarative

`WidgetDefinition.pro = true` is the sole mechanism for Pro gating. Widgets do not implement their own subscription checks. The dashboard shell renders a "Upgrade to Pro" overlay when a non-Pro user enables a Pro widget.

### Rule 7 — Central Catalog = Single Source of Truth

The `TILE_CATALOG` (web) / `WIDGET_REGISTRY` (mobile) is the only place where widget types are registered. Adding a new widget = adding one entry to the catalog + creating one widget component. No other files change.

---

## 7. Widget Catalog (Current — QRVEE)

| Type | Category | Platforms | Data Source | Pro |
|------|----------|-----------|-------------|-----|
| `league` | Social | Web | Firestore (users) | No |
| `signal_stream` | Social | Web | Firestore (sessions) | No |
| `oracle` | Radio | Web, Mobile | CF callable (getPropagationData) | No |
| `rig` | Radio | Web, Mobile | Firestore (rig state) | No |
| `dx_cluster` | Radio | Web | CF callable (fetchDxCluster) | No |
| `solar_flux_history` | Weather | Web | CF callable (oracle) | No |
| `grayline` | Weather | Web | Computed (no fetch) | No |
| `world_clock` | Utilities | Web | Computed (no fetch) | No |
| `stats` | Utilities | Web, Mobile | Firestore (logbook, sessions) | No |
| `friends` | Social | Web, Mobile | Firestore (follows, sessions) | No |
| `social` | Social | Web | Firestore (sessions, follows) | No |
| `map` | Utilities | Web, Mobile | Firestore (sessions) | No |
| `actions` | Utilities | Web, Mobile | None | No |
| `ai_companions` | Pro | Web | CF callable (generateCompanionAdvice) | Yes |
| `smart_shack` | Pro | Web, Mobile | Webhook store (IoT events) | Yes |

---

## 8. Cross-App Extension Points

When PNOT or MINWIN implement their own dashboards, they follow the same model:

| Concern | QRVEE | PNOT | MINWIN |
|---------|-------|------|--------|
| Widget registry | `TILE_CATALOG` | `PNOT_WIDGET_CATALOG` | `MINWIN_WIDGET_CATALOG` |
| Shared types | `@qrvee/shared` / dashboard.ts | same | same |
| Firestore path | `/users/{uid}/dashboards/qrvee` | `/users/{uid}/dashboards/pnot` | `/users/{uid}/dashboards/minwin` |
| Theme tokens | `qrv-*` | `qrv-*` (shared) | `qrv-*` (shared) |
| Event source | `events_qrvee` | `events_pnot` | `events_minwin` |

The `DashboardConfig` and `DashboardTile` types in `@qrvee/shared` are already app-agnostic and usable across all apps without modification.

---

## 9. Implementation Phases

| Phase | Deliverable |
|-------|-------------|
| 4A (current) | Design (this document) |
| 4B | Refactor QRVEE web dashboard.tsx to use WidgetDefinition registry |
| 4C | Extract shared widget hooks into `@qrvee/shared` |
| 4D | PNOT dashboard scaffold using same model |
| 4E | Mobile dashboard parity (widget registry + layout engine) |
