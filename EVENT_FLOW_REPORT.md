# EVENT FLOW REPORT — TASK-016

**Date:** 2026-03-30
**Phase:** 3
**Method:** Static code-level validation (emulator not available — JAR download required)
**Scope:** Full lifecycle from client write → Router CF → handlers → event_processing state

---

## VALIDATION METHOD

The Firebase emulator requires downloading a cloud-firestore-emulator JAR (~30 MB)
which is not available in this offline environment. This report is based on a
complete code-level trace of the event lifecycle across all 8 relevant files.

Live Firestore confirmation requires: deploy code + trigger actions in running app +
inspect `events_qrvee` and `event_processing` in Firebase Console.

---

## STEP 1 — CLIENT EVENT WRITE

**Code:** `apps/web/src/lib/events/qrveeEvents.ts` + mobile equivalent

**Payload written to `events_qrvee`:**
```
schemaVersion: 1
sourceApp:     'qrvee'
type:          'session.started' | 'session.ended' | 'session.renewed' | 'qso.logged'
userId:        <auth.uid>
targetApps:    ['pnot', 'tinc']
payload:       { sessionId/qsoId, callsign, band, mode, ... }
clientTime:    ISO 8601 string
serverTime:    Firestore serverTimestamp() sentinel → resolved Timestamp
sourceEventId: null
```

**Firestore rule check:**
```
allow create: if isApproved()
  && request.resource.data.userId == request.auth.uid   ✓
  && request.resource.data.sourceApp == 'qrvee'         ✓
  && request.resource.data.schemaVersion == 1           ✓
```

**Result: PASS** — All fields satisfy the rule.

---

## STEP 2 — SCHEMA VALIDATION (Router CF)

**Code:** `validateEvent()` in `events/schema.ts`

Traced validation for each event type written by client:

| Check | session.started | session.ended | session.renewed | qso.logged |
|-------|:-:|:-:|:-:|:-:|
| schemaVersion === 1 | ✓ | ✓ | ✓ | ✓ |
| sourceApp in valid list | ✓ | ✓ | ✓ | ✓ |
| type in VALID_TYPES['qrvee'] | ✓ | ✓ | ✓ | ✓ |
| userId is string | ✓ | ✓ | ✓ | ✓ |
| targetApps non-empty array | ✓ | ✓ | ✓ | ✓ |
| all targetApps in VALID_CONSUMERS | ✓ | ✓ | ✓ | ✓ |
| clientTime is string | ✓ | ✓ | ✓ | ✓ |
| payload is object | ✓ | ✓ | ✓ | ✓ |
| sourceEventId is null | ✓ | ✓ | ✓ | ✓ |

**Result: PASS** — All 4 event types pass validation.

---

## STEP 3 — event_processing BATCH CREATE (Router CF)

**Code:** `makeRouter()` in `events/router.ts`

For `targetApps: ['pnot', 'tinc']`, the router creates 2 records:

| Document ID | Fields |
|-------------|--------|
| `{eventId}_pnot` | status: 'pending', attempts: 0, app: 'pnot', ... |
| `{eventId}_tinc` | status: 'pending', attempts: 0, app: 'tinc', ... |

`batch.commit()` completes before handlers are dispatched — records exist when
handlers call `acquireLock()`. ✓

**Result: PASS** — Batch create logic is correct.

---

## STEP 4 — HANDLER DISPATCH

**Code:** `dispatchHandler()` in `events/router.ts`

```
consumerApp 'pnot' → handlePnot(eventId, eventData)   ✓
consumerApp 'tinc' → handleTinc(eventId)               ✓
```

Both dispatched via `Promise.allSettled` — one failure doesn't block the other. ✓

**Result: PASS**

---

## STEP 5 — PNOT HANDLER (session.started)

**Code:** `events/handlers/pnot.ts`

Payload written by client: `{ sessionId, callsign, band, mode, frequencyMHz, ... }`

PNOT handler reads:
- `payload['callsign']` → used in note title ✓
- `payload['band']` → used in note title ✓
- `payload['mode']` → uppercased, used in title ✓
- `payload['potaRef']`, `payload['sotaRef']`, `payload['contestName']` → extras line ✓

pnot_notes document written:
```
userId:        <user.uid>
sourceEventId: <eventId>       ← Layer 2 dedup key
title:         "Session started: TA1ABC on 20m / SSB"
category:      "qrvee_session"
source:        "qso"
syncedToPnot:  false
createdAt:     serverTimestamp()
```

**Result: PASS** — All payload fields present, note created correctly.

---

## STEP 6 — PNOT HANDLER (qso.logged)

**Code:** `events/handlers/pnot.ts`

Payload written by client: `{ qsoId, callsign, band, mode, frequencyMHz, rstSent, rstReceived, notes }`

PNOT handler reads:
- `payload['callsign']` → note title ✓
- `payload['frequencyMHz']` → formatted to 4 decimal places ✓
- `payload['mode']` → note title ✓
- `payload['band']`, `payload['rstSent']`, `payload['rstReceived']` → details ✓

pnot_notes document written:
```
title:    "QSO: DL1ABC on 14.0740 MHz (FT8)"
category: "qso"
details:  "Band: 20m · RST Sent: 59 / Rcvd: 57"
```

**Result: PASS** — All payload fields present, note created correctly.

---

## STEP 7 — PNOT HANDLER (session.ended / session.renewed)

**Code:** `events/handlers/pnot.ts`

Both types hit the `default` case in the switch — but wait, they are explicitly
listed:

```typescript
case 'session.ended':
case 'session.renewed':
case 'broadcast.sent':
  // Acknowledged — no PNOT note required for these types in Phase 2
  break;
```

Both fall through to `markDone(recordId)`. Processing record moves to 'done'. ✓

**Result: PASS**

---

## STEP 8 — TINC HANDLER (all types)

**Code:** `events/handlers/tinc.ts`

Stub behavior:
1. `acquireLock(eventId + '_tinc')` — compare-and-swap: 'pending' → 'processing' ✓
2. `markDone(recordId)` — 'processing' → 'done' ✓

Processing record for tinc completes immediately. No stuck records expected. ✓

**Result: PASS**

---

## STEP 9 — LAYER 2 DEDUPLICATION

**Code:** `events/handlers/pnot.ts` (lines checking `pnot_notes` by `sourceEventId`)

If CF is re-triggered or retried on an already-processed event:
1. `acquireLock` returns `false` if status is already 'done' → early return ✓
2. Even if lock acquired (e.g. after manual reset), the `pnot_notes` query
   where `sourceEventId == eventId` returns the existing doc → `markDone` (skip) ✓

Two independent dedup layers. ✓

**Result: PASS**

---

## STEP 10 — RETRY CF

**Code:** `events/retry.ts`

| Scenario | Logic | Verdict |
|----------|-------|---------|
| Stuck 'processing' >10 min | Reset to 'failed' | ✓ |
| Failed, attempts < 4, backoff elapsed | Re-dispatch via redispatch() | ✓ |
| Missed 'pending' >2 min | Re-dispatch via redispatch() | ✓ |
| Dead-letter (failed, attempts ≥ 4) | Log count, no auto-delete | ✓ |

`redispatch()` re-reads the source event from `events_qrvee` — the document is
immutable so it will always be present. ✓

**Result: PASS**

---

## ISSUES FOUND

### ISSUE-001 — Live verification not performed

**Severity:** Informational
**Detail:** The Firebase emulator requires a Java runtime and JAR download
(~30 MB) not available in this environment. Live Firestore testing requires
the developer to:
1. Deploy functions: `firebase deploy --only functions`
2. Run the app and trigger: session start → end → QSO log
3. Check `events_qrvee` in Firebase Console for documents
4. Check `event_processing` for status transitions (pending → processing → done)
5. Check `pnot_notes` for created note documents
6. Check Cloud Functions logs for `[Router]`, `[PNOT]`, `[Retry]` entries

### ISSUE-002 — broadcast.sent and user.approved have no client writers

**Severity:** Low
**Detail:** Both types are in `VALID_TYPES['qrvee']` but no client code writes them.
`broadcast.sent` may come from the `sendOrgBroadcast` Cloud Function in future;
`user.approved` from `approveUser`. Neither is a blocker for Phase 3.

### ISSUE-003 — session.ended payload does not include callsign

**Severity:** Low
**Detail:** The `session.ended` and `session.renewed` payloads only contain
`sessionId` (and `durationMinutes` for renew). The PNOT handler acknowledges
these without creating a note, so callsign is not needed. Future consumers that
need more context will require richer payloads.

---

## SUMMARY

| Step | Status | Method |
|------|--------|--------|
| Client event write | PASS | Code trace + rule check |
| Schema validation | PASS | Full field trace |
| event_processing batch create | PASS | Code trace |
| Handler dispatch | PASS | Code trace |
| PNOT handler — session.started | PASS | Payload field alignment |
| PNOT handler — qso.logged | PASS | Payload field alignment |
| PNOT handler — session.ended/renewed | PASS | Code trace |
| TINC handler (stub) | PASS | Code trace |
| Layer 2 deduplication | PASS | Two-layer verified |
| Retry CF | PASS | All 4 scenarios verified |
| **Live Firestore** | **NOT TESTED** | Emulator unavailable |

**Overall: All code paths validate correctly. Live testing required before production.**

---

## LIVE VALIDATION CHECKLIST (for developer)

After deploying functions (`firebase deploy --only functions`):

- [ ] Start a broadcast session in the app
- [ ] Verify `events_qrvee/{id}` document appears in Firebase Console
- [ ] Verify `event_processing/{id}_pnot` and `{id}_tinc` appear with status 'pending'
- [ ] Wait ~10 seconds for CF to execute
- [ ] Verify `event_processing/{id}_pnot` status = 'done'
- [ ] Verify `pnot_notes/{id}` document created with correct title
- [ ] End the session
- [ ] Verify `events_qrvee` second document for session.ended
- [ ] Log a QSO and verify qso.logged event + pnot_notes entry
- [ ] Check Cloud Functions logs for zero errors
