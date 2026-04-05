# DATA MODEL

Strict schema definitions. No extra fields allowed. (LAW-003)

---

## User

| Field | Type | Constraints |
|-------|------|-------------|
| id | string | Firebase UID, unique, immutable |
| callsign | string | uppercase, unique, regex: `^[A-Z0-9]{3,10}$` |
| displayName | string | non-empty, max 80 chars |
| country | string | ISO 3166-1 alpha-2 |
| continent | string | AF \| AN \| AS \| EU \| NA \| OC \| SA |
| status | enum | `active` \| `pending` \| `suspended` |
| createdAt | Timestamp | UTC, immutable |

---

## Session

| Field | Type | Constraints |
|-------|------|-------------|
| id | string | UUID, unique, immutable |
| userId | string | → User.id, required |
| callsign | string | denormalized from User.callsign |
| band | string? | see Band enum |
| frequencyMHz | number? | > 0 |
| mode | string | see Mode enum |
| latitude | number | -90 to +90 |
| longitude | number | -180 to +180 |
| country | string | ISO 3166-1 alpha-2 |
| continent | string | see continent enum |
| active | boolean | true while session is live |
| startedAt | Timestamp | UTC |
| expiresAt | Timestamp | > startedAt |

---

## QSO

| Field | Type | Constraints |
|-------|------|-------------|
| id | string | UUID, unique, immutable |
| ownerUid | string | → User.id |
| ownerCallsign | string | denormalized, ≠ callsign |
| callsign | string | other station, ≠ ownerCallsign |
| band | string | see Band enum |
| mode | string | see Mode enum |
| frequencyMHz | number | > 0 |
| datetime | Timestamp | UTC, must not be in future |
| createdAt | Timestamp | UTC, immutable |

---

## OperatorState

Document ID = User.id

| Field | Type | Constraints |
|-------|------|-------------|
| userId | string | → User.id |
| callsign | string | denormalized |
| online | boolean | |
| activeSessionId | string? | → Session.id; required if online=true; null if online=false |
| band | string? | current band if online |
| mode | string? | current mode if online |
| lastSeenAt | Timestamp | UTC |
| updatedAt | Timestamp | UTC |

---

## WorkItem

| Field | Type | Constraints |
|-------|------|-------------|
| id | string | UUID, unique, immutable |
| title | string | required, non-empty, max 200 chars |
| startAt | Timestamp | UTC |
| endAt | Timestamp | UTC, > startAt |
| status | enum | `PLANNED` \| `ACTIVE` \| `DONE` \| `BLOCKED` |
| progress | integer | 0–100 inclusive |
| ownerId | string | → User.id |
| dependencies | string[] | array of WorkItem.id; may be empty |
| createdAt | Timestamp | UTC, immutable |
| updatedAt | Timestamp | UTC |

---

## Enums

**Band:** `160m` `80m` `60m` `40m` `30m` `20m` `17m` `15m` `12m` `10m` `6m` `4m` `2m` `70cm` `23cm`

**Mode:** `SSB` `CW` `FT8` `FT4` `FM` `AM` `DMR` `DSTAR` `C4FM` `APRS` `SSTV` `ECHOLINK` `OTHER`

**WorkItemStatus:** `PLANNED` `ACTIVE` `DONE` `BLOCKED`
