# RUN LOG — TASK-009

**Date:** 2026-03-30
**Phase:** 2
**Status:** COMPLETE

---

## SUMMARY

Refactored the event system Cloud Functions infrastructure introduced in TASK-008.

Two changes:
1. **Handler separation** — moved all consumer handler logic out of `router.ts` into dedicated files under `events/handlers/`. Router now contains only: schema validation, event_processing record creation, and dispatch. No business logic.
2. **Run log system** — created `/tinc/RUN_LOG/` directory as the canonical execution trace location for all future tasks.

No behavior was changed. TypeScript build: zero errors before and after.

---

## FILES

### Created
| File | Purpose |
|------|---------|
| `firebase/functions/src/events/handlers/lock.ts`   | Shared locking utilities: acquireLock, markDone, markFailed |
| `firebase/functions/src/events/handlers/pnot.ts`   | PNOT consumer handler (session.started, qso.logged) |
| `firebase/functions/src/events/handlers/qrv.ts`    | QRVEE consumer handler (stub) |
| `firebase/functions/src/events/handlers/tinc.ts`   | TINC consumer handler (stub) |
| `firebase/functions/src/events/handlers/minwin.ts` | MINWIN consumer handler (stub) |
| `tinc/RUN_LOG/TASK-009.md`                          | This file |

### Modified
| File | Change |
|------|--------|
| `firebase/functions/src/events/router.ts` | Removed all handler/locking code. Now imports from handlers/. Contains: makeRouter factory, CF exports, dispatchHandler only. |

---

## TECHNICAL NOTES

### Why lock.ts is a shared module
`acquireLock`, `markDone`, and `markFailed` are used by every handler. Duplicating them in each handler file would create divergence risk. A single `lock.ts` is the only source of truth for processing state writes.

### Why _sourceApp is prefixed with underscore in dispatchHandler
`noUnusedLocals: true` is set in tsconfig. The `sourceApp` parameter is required in the function signature for the Retry CF call site (which passes it), but the dispatch switch only needs `consumerApp`. Prefixing with `_` signals intentional non-use to the TypeScript compiler.

### Handler stub pattern
`handleQrvee`, `handleTinc`, and `handleMinwin` acquire the lock and immediately mark done. This keeps the event system operational end-to-end (no stuck 'pending' records) while the actual consumer logic is built in future tasks.

### Router is now a pure dispatcher
After this refactor, `router.ts` has no knowledge of what any handler does. Adding a new consumer app requires: (1) create `handlers/{app}.ts`, (2) add a case to `dispatchHandler`. No other changes needed.
