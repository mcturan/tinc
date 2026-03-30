# RUN LOG — TASK-021

**Date:** 2026-03-30
**Phase:** 4
**Status:** COMPLETE

---

## SUMMARY

Designed the modular UI platform for all QRV ecosystem apps. Created
UI_PLATFORM.md with full architecture: core concepts, widget contract,
layout engine, state model, and modularity rules. Design is grounded in
the existing QRVEE web dashboard (17 tiles, Zustand + Firestore) and
extensible to PNOT and MINWIN.

---

## DESIGN DECISIONS

### Widget Contract vs. Current Implementation

Current QRVEE dashboard.tsx is a monolith (499 lines) — all tile rendering
inline. The design formalizes this into a `WidgetDefinition` registry +
`WidgetContract` interface. Existing tiles map 1:1 to the new model without
behavior changes.

### State Layers

Three-layer model: Firestore → Zustand → React. This is already how the
codebase works (implicit). The design makes it explicit and adds the rule
that each layer is reconstructable from the one above it.

### Event-Driven vs. Poll

All real-time widgets use Firestore onSnapshot listeners (already in place).
Callable CF widgets (oracle, dx_cluster) are demand-fetch with no real-time
subscription. This distinction is codified in `DataSourceRef.type`.

### Cross-App Reuse

`DashboardConfig` and `DashboardTile` types in @qrvee/shared are already
app-agnostic. Firestore paths use `dashboards/{appId}` per app — zero schema
changes needed for PNOT/MINWIN dashboards.

### Pro Gating

Declarative via `WidgetDefinition.pro = true`. Dashboard shell owns the
overlay — widgets are unaware of subscription status.

---

## CATALOG ANALYSIS

Current QRVEE catalog: 17 widget types, 5 categories.
- 15 free, 2 Pro (ai_companions, smart_shack)
- 10 web-only, 5 web+mobile, 0 mobile-only (gap — 4C/4E phases needed)

---

## OUTPUT

- `workspace/tinc/UI_PLATFORM.md` — created (9 sections, 250 lines)
- No code written (design-only per task constraints)
