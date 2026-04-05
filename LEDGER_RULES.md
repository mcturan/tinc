# LEDGER RULES

All state changes must be recorded as immutable entries.

---

## RULE 1 — IMMUTABILITY (MANDATORY)
Ledger entries are write-once. No updates, no deletes.
Corrections require a new compensating entry.

## RULE 2 — COMPLETENESS
Every QSO_START must produce a SESSION_OPEN entry pair (DR + CR).
Every QSO_END must produce a SESSION_CLOSE entry pair (DR + CR).
A SESSION_OPEN without SESSION_CLOSE = open session (valid while active).

## RULE 3 — REQUIRED FIELDS
Every ledger entry must contain:
`id, eventId, type, side, accountId, amount, sessionId, userId, callsign, at`

## RULE 4 — TYPE CONSTRAINT
`type` must be one of: `SESSION_OPEN` | `SESSION_CLOSE`
No other types allowed.

## RULE 5 — ORDERING
Entries ordered by `at` (Timestamp) ascending.
For the same session: SESSION_OPEN must precede SESSION_CLOSE.

## RULE 6 — SESSION INTEGRITY
A session cannot have two SESSION_OPEN entry pairs.
A session cannot have two SESSION_CLOSE entry pairs.
Duplicate eventId = REJECT.

## RULE 7 — VALIDATION
If any rule fails → reject entire entry. No partial write.

## RULE 8 — DOUBLE ENTRY (MANDATORY)
Every transaction must produce exactly two ledger entries: one DR, one CR.
`side` must be `DR` (debit) or `CR` (credit).

Accounts:
- `OperatorActivity` — tracks active operator slots
- `SessionPool`      — tracks session lifecycle

Mappings:

| Event | DR | CR |
|-------|----|----|
| SESSION_OPEN | OperatorActivity +1 | SessionPool -1 |
| SESSION_CLOSE | SessionPool +1 | OperatorActivity -1 |

## RULE 9 — BALANCE (MANDATORY)
For every transaction:
```
SUM(DR amounts) + SUM(CR amounts) == 0
```
DR amounts are positive. CR amounts are negative.
Balance check performed before write. Imbalance = REJECT.

## RULE 10 — IDEMPOTENCY
`eventId` on a ledger entry must be unique.
Before writing: check if `eventId` already exists in ledger.
If exists → skip write, return OK (idempotent, not an error).
