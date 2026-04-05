# VALIDATION RULES

Reject any invalid or incomplete data. (LAW-006)

Failure at any gate = stop process, return INVALID. No partial writes.

---

## User

| Rule | Field | Reject if |
|------|-------|-----------|
| V-U1 | callsign | not matching `^[A-Z0-9]{3,10}$` |
| V-U2 | callsign | not unique across all users |
| V-U3 | status | not one of: `active` `pending` `suspended` |
| V-U4 | continent | not one of: `AF` `AN` `AS` `EU` `NA` `OC` `SA` |

---

## Session

| Rule | Field | Reject if |
|------|-------|-----------|
| V-S1 | userId | does not reference valid User |
| V-S2 | callsign | does not match User.callsign |
| V-S3 | expiresAt | ≤ startedAt |
| V-S4 | latitude | < -90 or > +90 |
| V-S5 | longitude | < -180 or > +180 |
| V-S6 | mode | not in Mode enum |
| V-S7 | band | present but not in Band enum |
| V-S8 | frequencyMHz | present but ≤ 0 |

---

## QSO

| Rule | Field | Reject if |
|------|-------|-----------|
| V-Q1 | ownerCallsign | equals callsign (self-QSO forbidden) |
| V-Q2 | frequencyMHz | ≤ 0 |
| V-Q3 | datetime | > serverTime + 60s |
| V-Q4 | band | not in Band enum |
| V-Q5 | mode | not in Mode enum |
| V-Q6 | ownerUid | does not reference valid User |

---

## Event

| Rule | Field | Reject if |
|------|-------|-----------|
| V-E1 | id | not unique (if exists and processed → skip, not reject) |
| V-E2 | type | not in defined event types list |
| V-E3 | clientTime | > serverTime + 300s |
| V-E4 | userId | does not reference valid User |
| V-E5 | payload | any required field missing |
| V-E6 | sourceApp | not one of: `qrvee` `pnot` `minwin` |
| V-E7 | QSO_START payload.latitude | < -90 or > +90 |
| V-E8 | QSO_START payload.longitude | < -180 or > +180 |

---

## OperatorState

| Rule | Field | Reject if |
|------|-------|-----------|
| V-O1 | online=true | activeSessionId is null |
| V-O2 | online=false | activeSessionId is not null |
| V-O3 | activeSessionId | present but Session does not exist |

---

## WorkItem

| Rule | Field | Reject if |
|------|-------|-----------|
| V-W1 | title | empty or missing |
| V-W2 | endAt | ≤ startAt |
| V-W3 | progress | < 0 or > 100 |
| V-W4 | status | not in WorkItemStatus enum |
| V-W5 | WORK_STARTED | WorkItem.status ≠ PLANNED |
| V-W6 | WORK_STARTED | any dependency WorkItem.status ≠ DONE |
| V-W7 | WORK_STARTED | serverTime < WorkItem.startAt |
| V-W8 | WORK_COMPLETED | WorkItem.status ≠ ACTIVE |
| V-W9 | ownerId | does not reference valid User |
| V-W10 | dependencies | any entry does not reference valid WorkItem |

---

## Concurrency

| Rule | Condition | Reject if |
|------|-----------|-----------|
| V-C1 | QSO_START | OperatorState.activeSessionId is not null — error: `CONCURRENT_SESSION_CONFLICT` |
| V-C2 | QSO_END | Session.active is already false — error: `SESSION_ALREADY_CLOSED` |

---

## Security

| Rule | Condition | Reject if |
|------|-----------|-----------|
| V-SEC1 | all events | event.userId ≠ auth.uid (Firebase verified) |
| V-SEC2 | QSO_END | Session.userId ≠ event.userId (not session owner) |
| V-SEC3 | QSO write | QSO.ownerUid ≠ auth.uid |
| V-SEC4 | OperatorState write | document userId ≠ auth.uid (users write only own state) |

---

## Ledger

| Rule | Field | Reject if |
|------|-------|-----------|
| V-L1 | SUM(amount) per transaction | ≠ 0 |
| V-L2 | eventId | already exists in ledger (idempotent skip, not error) |
| V-L3 | side | not `DR` or `CR` |
| V-L4 | accountId | not `OperatorActivity` or `SessionPool` |
