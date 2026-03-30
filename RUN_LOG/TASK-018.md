# RUN LOG — TASK-018

**Date:** 2026-03-30
**Phase:** 3
**Status:** COMPLETE

---

## SUMMARY

Hardened Firestore security rules for production safety. Added schema
validation to all events_* create rules via a shared helper function.
Confirmed existing immutability and event_processing CF-only restrictions
are correct. Deployed rules — zero compilation errors (one pre-existing
unused-function warning unrelated to this task).

---

## PART 1 — AUDIT OF EXISTING RULES

Before changes:

| Rule | State |
|------|-------|
| events_* allow update: if false | ✓ Already in place |
| events_* allow delete: if false | ✓ Already in place |
| event_processing allow create/update/delete: if false | ✓ Already in place |
| events_* create: validate userId, sourceApp, schemaVersion | ✓ Already in place |
| events_* create: validate type, clientTime, targetApps, payload, sourceEventId | ✗ MISSING |

---

## PART 2 — CHANGES MADE

### Added: `isValidEventBase(app)` helper function

```
function isValidEventBase(app) {
  let d = request.resource.data;
  return d.schemaVersion == 1
    && d.sourceApp         == app
    && d.userId            == request.auth.uid
    && d.type              is string
    && d.type.size()       > 0
    && d.clientTime        is string
    && d.clientTime.size() > 0
    && d.targetApps        is list
    && d.targetApps.size() > 0
    && d.payload           is map
    && (d.sourceEventId    == null || d.sourceEventId is string);
}
```

Fields validated on every event create:
- `schemaVersion == 1` — version pinning
- `sourceApp == app` — collection-specific app enforcement
- `userId == request.auth.uid` — ownership enforcement
- `type is string && size > 0` — non-empty event type
- `clientTime is string && size > 0` — timestamp field present
- `targetApps is list && size > 0` — at least one consumer declared
- `payload is map` — payload must be a map (not a scalar or list)
- `sourceEventId == null || is string` — null or string, never another type

### Updated: events_* create rules

Each collection's create rule simplified to:
```
allow create: if isApproved() && isValidEventBase('<app>');
```

Previous rules checked only userId + sourceApp + schemaVersion. New rules
check all required BaseEvent fields, rejecting malformed writes at the
security layer before any Cloud Function is triggered.

---

## PART 3 — RATE PROTECTION ASSESSMENT

Firestore security rules do not support stateful rate limiting (no
time-window counters, no per-user write history). Options and decisions:

| Option | Available | Decision |
|--------|-----------|----------|
| Field constraints (already done) | ✓ | Done |
| Client-side write caps | Not in rules | Out of scope |
| Cloud Function rate guard | App-layer | Future task if needed |
| Firebase App Check enforcement | IAM-level | Recommended future hardening |

Conclusion: field-level validation is the correct rules-layer protection.
True rate limiting belongs at the application or Cloud Function layer.
No fake rate guard added to avoid false sense of security.

---

## PART 4 — DEPLOY RESULT

```
cloud.firestore: rules file firestore.rules compiled successfully
firestore: released rules firestore.rules to cloud.firestore
Deploy complete!
```

Warning: `[W] 49:14 - Unused function: isServerOnlyField` — pre-existing,
not introduced by this task. The function is defined but only referenced
outside of rules (used for documentation/audit purposes). Non-blocking.

---

## PART 5 — VALIDATION

**Client write allowed (expected):**
- events_qrvee with all required fields + isApproved() → allowed ✓
- events_pnot with all required fields + isApproved() → allowed ✓

**Forbidden writes rejected (expected):**
- events_qrvee missing `type` field → denied (isValidEventBase fails)
- events_qrvee missing `clientTime` field → denied
- events_qrvee with empty `targetApps: []` → denied
- events_qrvee with `payload` as string (not map) → denied
- events_qrvee update → denied (allow update: if false)
- events_qrvee delete → denied (allow delete: if false)
- event_processing create from client → denied (allow create: if false)
- event_processing update from client → denied (allow update: if false)

(Validated by static rule inspection — emulator not available.)

---

## FILES MODIFIED

| File | Change |
|------|--------|
| `firebase/firestore.rules` | Added isValidEventBase(), updated 3 event create rules |
| `tinc/RUN_LOG/TASK-018.md` | This file |
