# RUN LOG — TASK-024

**Date:** 2026-03-30
**Phase:** 4B
**Status:** COMPLETE

---

## SUMMARY

Hardened UI Engine with lifecycle state machine, visibility control,
per-widget error boundary, render hook, and extended test page.
TypeScript: zero errors. Existing dashboard untouched.

---

## FILES MODIFIED / CREATED

| File | Change |
|------|--------|
| `ui-engine/registry.ts` | Added LifecycleState type + lifecycle field to WidgetState |
| `ui-engine/engine.ts` | Full rewrite — state machine, hide/show, setError/recover |
| `ui-engine/WidgetErrorBoundary.tsx` | New — React class ErrorBoundary, calls UIEngine.setError |
| `ui-engine/useWidgetState.ts` | New — useWidgetState(id) hook + useAllWidgetStates() |
| `app/engine-test/page.tsx` | Extended — crash/recover, hide/show, rapid events, debug table |

---

## STATE MACHINE

```
mount()    → MOUNT
             └─ data arrives → ACTIVE
hide()     ACTIVE → HIDDEN   (subscriptions released from pool)
show()     HIDDEN → ACTIVE   (subscriptions re-acquired, cached data delivered)
setError() any    → ERROR    (subscriptions released, error stored)
recover()  ERROR  → MOUNT    (subscriptions re-acquired)
unmount()  any    → UNMOUNT  (subscriptions released, entry deleted)
```

## VISIBILITY CONTROL

hide(): _closeSubscriptions() — pool refCount decremented, interval/listener paused
show(): _openSubscriptions()  — pool re-acquire, lastData delivered immediately

Test: "Hide both ticker widgets" button → subscriptionCount drops from 1 to 0
      "Show both ticker widgets" button → subscriptionCount returns to 1

## ERROR BOUNDARY

WidgetErrorBoundary wraps each widget in the test sandbox.
On throw: getDerivedStateFromError sets caught=true, componentDidCatch calls
UIEngine.setError(). Engine transitions widget to ERROR lifecycle.
"Retry" button: UIEngine.recover() + boundary resets caught=false.

## RENDER HOOK

useWidgetState(instanceId): subscribes to UIEngine.onStateChange, filters
to the specific instanceId — no unnecessary re-renders for other widgets.

useAllWidgetStates(): returns Map<id, WidgetState>, used by dashboard shell
and debug panel. Removes entry on UNMOUNT lifecycle.

## TEST SCENARIOS COVERED

1. Normal lifecycle: MOUNT → ACTIVE (ticker increments every 2s)
2. Hide/show: subscription paused, resumed with cached data
3. Crash simulation: CrashWidget throws → boundary catches → ERROR state
4. Recovery: Retry button → MOUNT → ACTIVE
5. Rapid events: 10 config_change events fired in loop → event log shows all
6. Dedup: two ticker widgets share 1 subscription (subscriptionCount=1)
7. Unmount: widget removed, row clears, subscription released
