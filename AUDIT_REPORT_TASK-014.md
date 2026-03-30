# AUDIT REPORT — TASK-014

**Date:** 2026-03-30
**Phase:** 2
**Auditor:** Claude Code (automated)
**Scope:** workspace structure, event system, logging, code structure, drift analysis

---

## SUMMARY

| Section | Result |
|---------|--------|
| PART 1 — Structure | PASS (1 note) |
| PART 2 — Event System | PASS |
| PART 3 — Logging | PASS |
| PART 4 — Code Structure | PASS |
| PART 5 — Drift Analysis | 2 RISKS, 2 MISSING |

**Overall: PASS with known gaps — no blocking issues for Phase 2 continuation.**

---

## PART 1 — STRUCTURE AUDIT

### Workspace layout

```
/home/turan/workspace/
├── tinc/     ✓ present
└── qrvee/    ✓ present
```

pnot/ and minwin/ not yet in workspace — acceptable (marked optional in task).

**LAW CHECK:**
- tinc NOT inside any app: ✓ (moved out in TASK-013)
- apps NOT depending on each other directly: CONDITIONAL PASS — see note below

**NOTE — pnot-client.ts:**
`/workspace/qrvee/apps/web/src/lib/api/pnot-client.ts` exists and is imported
in `verificationEngine.ts` and `CharacterWidget.tsx`. This file calls
`https://api.pnot.io/v1` directly.

At the time of audit, only `mockExportToPnot` and `mockFetchPnotStats` are
called — both return static mock data, no real HTTP call is made.

This is a V1 pattern that predates the event system. It is listed as deprecated
in DECISION_LOG TASK-004. It does not violate the event system contract today
(mock-only), but the file and its imports must be migrated before production.

**Result: PASS** (mock-mode only; tracked as RISK-001 below)

---

## PART 2 — EVENT SYSTEM AUDIT

### Collections

| Collection | Firestore Rule Exists | allow update: if false | allow delete: if false |
|------------|----------------------|------------------------|------------------------|
| events_qrvee  | ✓ | ✓ | ✓ |
| events_pnot   | ✓ | ✓ | ✓ |
| events_minwin | ✓ | ✓ | ✓ |
| event_processing | ✓ (CF-only write) | ✓ | ✓ |

### Schema compliance

- `processedBy` field: NOT FOUND anywhere in codebase ✓
- `BaseEvent` fields match EVENT_SYSTEM_V2.md v2.3 spec ✓
- `EventProcessingRecord` fields match spec ✓
- `validateEvent()` enforces all required fields ✓

### Router compliance

- router.ts contains: schema validation, batch event_processing creation, dispatchHandler ✓
- router.ts does NOT contain: business logic, locking, Firestore writes to other collections ✓
- `dispatchHandler` is a pure switch statement ✓

### Handler separation

| Handler | File | Type |
|---------|------|------|
| pnot | handlers/pnot.ts | Operational — session.started, qso.logged |
| qrvee | handlers/qrv.ts | Stub (by design) |
| tinc | handlers/tinc.ts | Stub (by design) |
| minwin | handlers/minwin.ts | Stub (by design) |
| shared lock | handlers/lock.ts | acquireLock / markDone / markFailed |

All handlers use acquireLock (Firestore transaction CAS) before any write ✓
All handlers call markDone or markFailed in all exit paths ✓
Layer 2 deduplication in pnot.ts (sourceEventId query on pnot_notes) ✓

**Result: PASS**

---

## PART 3 — LOGGING AUDIT

### RUN_LOG

| File | Present |
|------|---------|
| TASK-009.md | ✓ |
| TASK-010.md | ✓ |
| TASK-011.md | ✓ |
| TASK-012.md | ✓ |
| TASK-013.md | ✓ |

RUN_LOG canonical path: `/home/turan/workspace/tinc/RUN_LOG/` ✓

### DECISION_LOG

Entries verified for TASK-001 through TASK-013.
All entries follow the required FORMAT (TYPE / SOURCE / DESCRIPTION / REASON / IMPACT / STATUS).
LAWS (LAW-001, LAW-002) present and in effect.
Append-only notice present.

**Result: PASS**

---

## PART 4 — CODE STRUCTURE AUDIT

### Handler modularity

Each consumer app has exactly one handler file. Adding a new consumer requires:
1. Create `handlers/{app}.ts`
2. Add one case to `dispatchHandler`
No other files change — confirmed by code review. ✓

### No logic in router

router.ts is 85 lines. The only logic is:
- `makeRouter`: CF trigger wrapper, validates, batch-creates records, calls Promise.allSettled
- `dispatchHandler`: 10-line switch, no conditions, no data access

No business logic present. ✓

### No cross-layer violation

- Client layer: does not run consumer logic (stubs and CF are server-only) ✓
- CF layer: does not expose internal state to client beyond `event_processing` reads ✓
- Event documents: never mutated after creation ✓

### TypeScript

Build confirmed zero errors (`npm run build` — tsc exits 0) ✓
`noUnusedLocals: true` compliance: `_sourceApp` prefix used correctly ✓

**Result: PASS**

---

## PART 5 — DRIFT ANALYSIS

### Planned vs Implemented

| Planned (EVENT_SYSTEM_V2.md) | Implemented | Status |
|------------------------------|-------------|--------|
| events_* immutable collections | ✓ | DONE |
| event_processing mutable state | ✓ | DONE |
| Router CF (onDocumentCreated) | ✓ | DONE |
| Retry CF (onSchedule every 5 min) | ✓ | DONE |
| Firestore CAS locking | ✓ | DONE |
| 4-attempt retry with backoff | ✓ | DONE |
| Dead-letter detection | ✓ | DONE |
| PNOT handler operational | ✓ | DONE |
| QRVEE client writes to events_qrvee | ✗ | MISSING |
| QRVEE handler (consumer logic) | stub | PLANNED |
| TINC handler (consumer logic) | stub | PLANNED |
| MINWIN handler (consumer logic) | stub | PLANNED |
| Local processing layer (TASK-007) | not started | MISSING |

### RISK-001 — Direct PNOT API client in qrvee web app

**Severity:** Medium
**File:** `apps/web/src/lib/api/pnot-client.ts`
**Issue:** This file imports and calls the PNOT external API directly (`https://api.pnot.io/v1`).
It is imported in `verificationEngine.ts` and `CharacterWidget.tsx`.
Currently only mock functions are called — no real HTTP traffic.
**Risk:** If real API key is added and production mock flag is removed, qrvee will
bypass the event system and write directly to PNOT, violating V2 architecture.
**Recommendation:** Remove or replace with an event-system-based call before
`CLAUDE_API_KEY` or PNOT API key is added to production config.
**Blocks production deploy:** YES (if not addressed before PNOT goes live)

### RISK-002 — tinc directory is not tracked by any git repo

**Severity:** Low (currently)
**Issue:** After TASK-013, tinc/ was moved out of qrvee. It is no longer tracked by
any git repo. workspace/tinc has no .git, and qrvee no longer contains it.
All documentation and logs in tinc/ are currently unversioned.
**Risk:** File loss if machine issue occurs before a backup mechanism is in place.
**Recommendation:** Either: (a) initialize a git repo in workspace/tinc and push to
a remote, or (b) accept unversioned state until a workspace-level git strategy
is defined in a future task.
**Blocks current work:** NO

### MISSING-001 — QRVEE client does not write to events_qrvee

**Severity:** High (for event system to function end-to-end)
**Issue:** The QRVEE web/mobile app still writes sessions to the `sessions` collection
(V1 path). The `events_qrvee` collection is defined and the Router CF is deployed,
but no client code currently writes to it.
**Impact:** The entire event system is deployed but receives no real events.
PNOT handler, retry logic, and all downstream consumers are unreachable from
live user actions.
**Recommendation:** Implement dual-write in QRVEE client: write to `sessions`
(V1, keep for now) AND `events_qrvee` (V2, new). This is the V1→V2 migration
step defined in EVENT_SYSTEM_V2.md §9.
**Blocks Phase 2 completion:** YES

### MISSING-002 — Local processing layer not started

**Severity:** Medium
**Issue:** EVENT_SYSTEM_V2.md §11 (TASK-007) defines the local processing layer:
optimistic local store, Firestore listeners as reconciliation, IndexedDB for
offline queue. This has been designed but not implemented in client code.
**Impact:** Offline-first behavior is not yet functional. UI waits for Firestore
round-trip on every action.
**Recommendation:** Implement local store (Zustand) + OfflineQueue flush logic
as a future task before mobile soft launch.
**Blocks soft launch:** YES

---

## CRITICAL ISSUES

1. **MISSING-001** — QRVEE client must begin writing to events_qrvee for the event
   system to process any real data. This is the highest priority gap.

2. **RISK-001** — pnot-client.ts direct API usage must be removed or mocked-out
   permanently before any PNOT API key enters the codebase.

---

## RECOMMENDATIONS

1. Create TASK-015: Implement dual-write in QRVEE client (sessions → events_qrvee)
2. Create TASK-016: Remove or replace pnot-client.ts with event-based stub
3. Create TASK-017: Initialize git tracking for workspace/tinc (or define workspace git strategy)
4. Defer MISSING-002 (local processing layer) to Phase 3

---

## OPEN QUESTIONS (from EVENT_SYSTEM_V2.md)

| # | Question | Status |
|---|----------|--------|
| 1 | PNOT external API (api.pnot.io) status | OPEN — pnot-client.ts exists, mock only |
| 2 | MINWIN event producers don't exist | OPEN — Phase 3+ |
| 3 | Scheduled poller vs Cloud Tasks | CLOSED — scheduled poller chosen (TASK-006) |
| 4 | Event retention period (90 days) | OPEN — Phase 5 |
| 5 | Cross-user fan-out events | OPEN — Phase 3 |
