# TRANSACTION MAPPING

Every event produces defined state changes and ledger entries. No other mappings allowed.

---

## QSO_START

**Pre-condition:** `OperatorState.activeSessionId == null` — reject if not met (V-C1)

**State changes:**
- `Session.active` = `true`
- `OperatorState.online` = `true`
- `OperatorState.activeSessionId` = `payload.sessionId`
- `OperatorState.band` = `payload.band`
- `OperatorState.mode` = `payload.mode`
- `OperatorState.updatedAt` = `serverTime`

**Ledger entries (double-entry):**
```
Entry 1 — DR:
  id:        UUID
  eventId:   event.id
  type:      SESSION_OPEN
  side:      DR
  accountId: OperatorActivity
  amount:    +1
  sessionId: payload.sessionId
  userId:    event.userId
  callsign:  payload.callsign
  at:        serverTime

Entry 2 — CR:
  id:        UUID
  eventId:   event.id
  type:      SESSION_OPEN
  side:      CR
  accountId: SessionPool
  amount:    -1
  sessionId: payload.sessionId
  userId:    event.userId
  callsign:  payload.callsign
  at:        serverTime

SUM(DR + CR) = +1 + (-1) = 0 ✓
```

---

## QSO_END

**Pre-condition:** `Session.userId == event.userId` — reject if not met (V-SEC2)

**State changes:**
- `Session.active` = `false`
- `OperatorState.online` = `false`
- `OperatorState.activeSessionId` = `null`
- `OperatorState.band` = `null`
- `OperatorState.mode` = `null`
- `OperatorState.lastSeenAt` = `serverTime`
- `OperatorState.updatedAt` = `serverTime`

**Ledger entries (double-entry):**
```
Entry 1 — DR:
  id:              UUID
  eventId:         event.id
  type:            SESSION_CLOSE
  side:            DR
  accountId:       SessionPool
  amount:          +1
  sessionId:       payload.sessionId
  userId:          event.userId
  callsign:        payload.callsign
  durationMinutes: payload.durationMinutes
  reason:          payload.reason
  at:              serverTime

Entry 2 — CR:
  id:              UUID
  eventId:         event.id
  type:            SESSION_CLOSE
  side:            CR
  accountId:       OperatorActivity
  amount:          -1
  sessionId:       payload.sessionId
  userId:          event.userId
  callsign:        payload.callsign
  durationMinutes: payload.durationMinutes
  reason:          payload.reason
  at:              serverTime

SUM(DR + CR) = +1 + (-1) = 0 ✓
```

---

## USER_ONLINE

**Pre-condition:** none

**State changes:**
- `OperatorState.online` = `true`
- `OperatorState.updatedAt` = `serverTime`

**Ledger entries:** none (presence-only event)

---

## USER_OFFLINE

**Pre-condition:** none

**State changes:**
- `OperatorState.online` = `false`
- `OperatorState.activeSessionId` = `null`
- `OperatorState.lastSeenAt` = `serverTime`
- `OperatorState.updatedAt` = `serverTime`

**Ledger entries:**
- If `payload.sessionId` present → emit SESSION_CLOSE pair (same as QSO_END, reason = payload.reason)
- If `payload.sessionId` null → no ledger entries

---

## WORK_CREATED

**Pre-condition:** `WorkItem` with `payload.workItemId` must not already exist

**State changes:**
- Create `WorkItem`:
  - `id` = `payload.workItemId`
  - `title` = `payload.title`
  - `startAt` = `payload.startAt`
  - `endAt` = `payload.endAt`
  - `status` = `PLANNED`
  - `progress` = `0`
  - `ownerId` = `payload.ownerId`
  - `dependencies` = `payload.dependencies`
  - `createdAt` = `serverTime`
  - `updatedAt` = `serverTime`

**Ledger entries:** OPTIONAL. If included, must be double-entry (SUM == 0).

---

## WORK_STARTED

**Pre-condition:**
- `WorkItem.status == PLANNED` (V-W5)
- All `WorkItem.dependencies` have `status == DONE` (V-W6)
- `serverTime >= WorkItem.startAt` (V-W7)

**State changes:**
- `WorkItem.status` = `ACTIVE`
- `WorkItem.updatedAt` = `serverTime`

**Ledger entries:** none

---

## WORK_PROGRESS

**Pre-condition:** `WorkItem.status == ACTIVE`

**State changes:**
- `WorkItem.progress` = `payload.progress`
- `WorkItem.updatedAt` = `serverTime`

**Ledger entries:** none

---

## WORK_COMPLETED

**Pre-condition:** `WorkItem.status == ACTIVE`

**State changes:**
- `WorkItem.status` = `DONE`
- `WorkItem.progress` = `100`
- `WorkItem.updatedAt` = `serverTime`

**Ledger entries:** none

---

## Ledger Entry Schema

| Field | Type | Note |
|-------|------|------|
| id | string | UUID — unique per entry |
| eventId | string | → event.id — idempotency key |
| type | enum | `SESSION_OPEN` \| `SESSION_CLOSE` |
| side | enum | `DR` \| `CR` |
| accountId | enum | `OperatorActivity` \| `SessionPool` |
| amount | number | DR = +1, CR = -1 |
| sessionId | string | |
| userId | string | |
| callsign | string | |
| at | Timestamp | |
| durationMinutes | number? | SESSION_CLOSE only |
| reason | string? | SESSION_CLOSE only |

Balance invariant: SUM(amount) per transaction == 0. (LAW-001)
Entries are immutable. (LAW-002)
