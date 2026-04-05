# EVENT CONTRACTS

All events must follow predefined structure. (LAW-008)

---

## Envelope (all events)

| Field | Type | Constraints |
|-------|------|-------------|
| id | string | UUID — **idempotency key**, globally unique |
| type | string | one of defined event types |
| userId | string | → User.id; must equal auth.uid (server-verified) |
| sourceApp | string | `qrvee` \| `pnot` \| `minwin` |
| targetApps | string[] | subset of app names |
| payload | object | type-specific, see below |
| clientTime | Timestamp | device UTC |
| serverTime | Timestamp | server UTC; must be ≥ clientTime - 300s |
| processedBy | string[] | apps that have consumed this event |

**Idempotency:** Before processing, check if `id` already exists in the event collection.
If found and `sourceApp` in `processedBy` → skip, return OK. Do not process twice.

**Defined event types:** `QSO_START` `QSO_END` `USER_ONLINE` `USER_OFFLINE` `WORK_CREATED` `WORK_STARTED` `WORK_PROGRESS` `WORK_COMPLETED`

---

## QSO_START

Emitted when an operator begins a session.

**Pre-condition:** `OperatorState.activeSessionId` must be `null`.
If not null → REJECT with `CONCURRENT_SESSION_CONFLICT`. Client must emit QSO_END first.

**payload:**

| Field | Type | Required |
|-------|------|----------|
| sessionId | string | ✓ |
| callsign | string | ✓ |
| band | string | ✓ |
| mode | string | ✓ |
| frequencyMHz | number | — |
| latitude | number | ✓ — must be ∈ [-90, 90] |
| longitude | number | ✓ — must be ∈ [-180, 180] |
| country | string | ✓ |
| continent | string | ✓ |

---

## QSO_END

Emitted when a session ends (manual stop or expiry).

**Pre-condition:** `Session.userId` must equal `event.userId` (ownership check).

**payload:**

| Field | Type | Required |
|-------|------|----------|
| sessionId | string | ✓ |
| callsign | string | ✓ |
| durationMinutes | number | ✓ — integer, ≥ 0 |
| reason | string | ✓ — `manual` \| `expired` \| `error` |

---

## USER_ONLINE

Emitted when a user becomes reachable (app foreground, auth complete).

**payload:**

| Field | Type | Required |
|-------|------|----------|
| userId | string | ✓ — must equal event.userId |
| callsign | string | ✓ |
| sessionId | string | ✓ — active session if one exists |

---

## USER_OFFLINE

Emitted when a user becomes unreachable (app background, signout, expiry).

**payload:**

| Field | Type | Required |
|-------|------|----------|
| userId | string | ✓ — must equal event.userId |
| callsign | string | ✓ |
| sessionId | string? | — active session ID if one was running |
| reason | string | ✓ — `manual` \| `expired` \| `error` |

---

## WORK_CREATED

Emitted when a new work item is defined.

**Pre-condition:** none

**payload:**

| Field | Type | Required |
|-------|------|----------|
| workItemId | string | ✓ — UUID, must not already exist |
| title | string | ✓ — non-empty |
| startAt | Timestamp | ✓ |
| endAt | Timestamp | ✓ — > startAt |
| ownerId | string | ✓ — → User.id |
| dependencies | string[] | ✓ — may be empty array |

---

## WORK_STARTED

Emitted when work begins execution.

**Pre-condition:** `WorkItem.status == PLANNED` AND all dependencies have `status == DONE` AND `serverTime >= WorkItem.startAt`

**payload:**

| Field | Type | Required |
|-------|------|----------|
| workItemId | string | ✓ |

---

## WORK_PROGRESS

Emitted when progress is updated.

**Pre-condition:** `WorkItem.status == ACTIVE`

**payload:**

| Field | Type | Required |
|-------|------|----------|
| workItemId | string | ✓ |
| progress | integer | ✓ — 0–100 inclusive |

---

## WORK_COMPLETED

Emitted when work is finished.

**Pre-condition:** `WorkItem.status == ACTIVE`

**payload:**

| Field | Type | Required |
|-------|------|----------|
| workItemId | string | ✓ |
