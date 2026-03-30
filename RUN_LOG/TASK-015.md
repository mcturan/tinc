# RUN LOG — TASK-015

**Date:** 2026-03-30
**Phase:** 3
**Status:** COMPLETE

---

## SUMMARY

Activated the Event System V2 by integrating QRVEE client (web + mobile) as an event
producer. Both platforms now write to `events_qrvee` in parallel with existing
`sessions` and `logbook` writes (dual-write). The Router CF will trigger on every
new event document.

---

## EVENTS ACTIVATED

| Event Type | Trigger | Platforms |
|------------|---------|-----------|
| `session.started` | User starts broadcast | Web + Mobile |
| `session.ended` | User ends session | Web + Mobile |
| `session.renewed` | User renews session | Web + Mobile |
| `qso.logged` | User logs a QSO | Web + Mobile |

---

## FILES CREATED

| File | Purpose |
|------|---------|
| `apps/web/src/lib/events/qrveeEvents.ts` | Web event writer utility |
| `apps/mobile/src/lib/events/qrveeEvents.ts` | Mobile event writer utility |

---

## FILES MODIFIED

| File | Change |
|------|--------|
| `apps/web/src/lib/sessions.ts` | Added `writeQrveeEvent` calls after createSession, endSession, renewSession |
| `apps/web/src/app/dashboard/logbook/page.tsx` | Added `writeQrveeEvent` call after QSO addDoc |
| `apps/mobile/app/(tabs)/broadcast.tsx` | Added `writeQrveeEvent` calls after session start, end, renew |
| `apps/mobile/app/(tabs)/logbook.tsx` | Added `writeQrveeEvent` call after QSO add |

---

## DESIGN DECISIONS

### Fire-and-forget with silent catch
Both event writers wrap the `addDoc`/`add` call in try-catch and log errors via
`console.error` without rethrowing. A failed event write must never prevent the
primary user action (session start, QSO log) from completing.

### Dual-write (V1 + V2 in parallel)
`sessions` collection writes are fully preserved — no behavior change.
`logbook` collection writes are fully preserved — no behavior change.
V2 event writes happen after the primary write succeeds.

### Optional userId in sessions.ts
`endSession` and `renewSession` gained an optional `userId?: string` parameter.
Existing callers without userId still work; event is only written when userId
is provided. This is backward compatible.

### targetApps: ['pnot', 'tinc']
All QRVEE events target pnot and tinc for Phase 2. minwin and qrvee-as-consumer
will be added when their handlers gain real logic.

---

## PAYLOAD SHAPES

### session.started
```json
{
  "sessionId": "...",
  "callsign": "TA1ABC",
  "band": "20m",
  "mode": "ssb",
  "frequencyMHz": 14.225,
  "digitalNetwork": null,
  "note": null,
  "potaRef": null,
  "sotaRef": null,
  "contestName": null
}
```

### session.ended / session.renewed
```json
{ "sessionId": "...", "durationMinutes": 60 }
```

### qso.logged
```json
{
  "qsoId": "...",
  "callsign": "DL1ABC",
  "band": "20m",
  "mode": "FT8",
  "frequencyMHz": 14.074,
  "rstSent": "59",
  "rstReceived": "57",
  "notes": null
}
```

---

## TYPESCRIPT

- Cloud Functions build: zero errors ✓
- Web `tsc --noEmit`: zero errors ✓
