# EVENT SYSTEM — CURRENT STATE

> Reality extraction only. No redesign. No improvements. As-is snapshot.
> Source: QRVEE codebase at /home/turan/qrv-project — 2026-03-29

---

## 1. COLLECTIONS

| Collection       | Role                              | Producer         | Consumer              |
|------------------|-----------------------------------|------------------|-----------------------|
| `sessions`       | Active broadcast events           | QRVEE client     | Cloud Function, Feed  |
| `notifications`  | In-app notification records       | Cloud Function   | QRVEE client          |
| `pnot_notes`     | Cross-app QSO notes for PNOT      | Cloud Function   | PNOT (external API)   |
| `broadcasts`     | Org-level broadcast records       | Cloud Function   | QRVEE client          |
| `fcmTokens`      | FCM device tokens per user        | QRVEE client     | Cloud Function (FCM)  |

> **No dedicated event bus collection exists.** The `sessions` collection acts as the de facto event source.
> There is no `events_qrvee`, `events_pnot`, or similar named event collection.

---

## 2. SESSION EVENT SCHEMA (QRVEE Producer)

Written to `sessions/{sessionId}` by `createSession()` in `apps/web/src/lib/sessions.ts`.

### Required fields (always written)

| Field             | Type                | Description                            |
|-------------------|---------------------|----------------------------------------|
| `userId`          | string              | Firebase Auth UID of broadcaster       |
| `callsign`        | string              | Ham radio callsign                     |
| `displayName`     | string              | User display name                      |
| `mode`            | ActivityMode        | ssb/cw/fm/am/ft8/ft4/dmr/dstar/c4fm/echolink/aprs/sstv/other |
| `latitude`        | number              | GPS latitude                           |
| `longitude`       | number              | GPS longitude                          |
| `geohash`         | string              | Computed via geohashForLocation()      |
| `country`         | string (2-char ISO) | Country code                           |
| `continent`       | string              | Continent code                         |
| `radiusKm`        | number              | Notification radius in km              |
| `durationMinutes` | number              | Session length (15–60 min)             |
| `startedAt`       | Timestamp           | Server timestamp at creation           |
| `expiresAt`       | Timestamp           | Computed: startedAt + durationMinutes  |
| `active`          | boolean             | True when session is live              |

### Optional fields (may be undefined/missing in docs)

| Field            | Type    | Description                                    |
|------------------|---------|------------------------------------------------|
| `photoURL`       | string  | Profile photo URL                              |
| `band`           | Band    | 160m/80m/.../23cm/other — absent for network modes |
| `frequencyMHz`   | number  | Exact frequency in MHz                         |
| `digitalNetwork` | string  | DMR talkgroup / D-STAR reflector / etc.        |
| `note`           | string  | Free text, max 140 chars                       |
| `potaRef`        | string  | POTA reference e.g. "TA-001"                   |
| `sotaRef`        | string  | SOTA reference e.g. "TA/AN-001"                |
| `contestName`    | string  | Contest name string                            |
| `city`           | string  | City name (user-entered, not validated)        |

### Fields added on renewal (not present on first write)

| Field          | Type      | Description                          |
|----------------|-----------|--------------------------------------|
| `renewedAt`    | Timestamp | Set on renewSession()                |
| `warningSent`  | boolean   | Set to false on renewal; true after warning |

### Field set only by Cloud Function (not client)

| Field         | Type    | Description                              |
|---------------|---------|------------------------------------------|
| `warningSent` | boolean | Set true by cleanExpiredSessions trigger |

---

## 3. NOTIFICATION EVENT SCHEMA

Written to `notifications/{notifId}` by Cloud Functions.

### Common fields (always present)

| Field          | Type      | Description                          |
|----------------|-----------|--------------------------------------|
| `targetUserId` | string    | UID of notification recipient        |
| `type`         | NotifType | See types below                      |
| `title`        | string    | Notification title                   |
| `body`         | string    | Notification body text               |
| `read`         | boolean   | Always false on creation             |
| `createdAt`    | Timestamp | Server timestamp                     |

### Optional/type-specific fields

| Field             | Type   | Present when                         |
|-------------------|--------|--------------------------------------|
| `sessionId`       | string | type = follow_active / region_active / session_expiring |
| `senderCallsign`  | string | type = follow_active / region_active |
| `senderUid`       | string | type = follow_active / region_active |
| `orgId`           | string | type = org_broadcast                 |
| `readAt`          | Timestamp | Set when read = true (via client)  |

### NotifType values

| Value              | Trigger                                           |
|--------------------|---------------------------------------------------|
| `follow_active`    | Followed user starts session                      |
| `region_active`    | Nearby user (within regionRadiusKm) starts session |
| `org_broadcast`    | Org admin sends broadcast                        |
| `session_expiring` | Scheduler detects session expiring in 15 min     |
| `admin_message`    | (Defined in type, no producer found in code)     |

---

## 4. PNOT_NOTES SCHEMA

Written to `pnot_notes/{auto-id}` by `createPnotProjectNote()` in `firebase/functions/src/pnot.ts`.

| Field           | Type      | Description                                    |
|-----------------|-----------|------------------------------------------------|
| `userId`        | string    | Owner UID                                      |
| `title`         | string    | Note title                                     |
| `category`      | string    | Category string                                |
| `details`       | string    | Note body                                      |
| `source`        | string    | 'marketplace' / 'qso' / 'manual'              |
| `createdAt`     | Timestamp | Server timestamp                               |
| `syncedToPnot`  | boolean   | Always false — external sync not implemented  |
| `serialNumber`  | string?   | Optional                                       |
| `transactionId` | string?   | Optional                                       |
| `amount`        | number?   | Optional                                       |
| `currency`      | string?   | Optional                                       |
| `metadata`      | object?   | Optional freeform                              |

---

## 5. PRODUCER BEHAVIOR — QRVEE

### How sessions are created (client-side)
- File: `apps/web/src/lib/sessions.ts:createSession()`
- Writes directly to Firestore `sessions` collection via `addDoc()`
- No Cloud Function is called for creation — Firestore trigger fires instead

### How sessions end
- Client calls `updateDoc({ active: false })` via `endSession()`
- No webhook or notification fired on manual end — only on timer expiry via scheduler

### Session lifecycle
```
createSession() → sessions/{id} created (active: true)
    ↓
onSessionCreated trigger fires (Cloud Function)
    ↓
Followers + nearby users notified (FCM + notifications collection)
    ↓
[every 5 min] cleanExpiredSessions scheduler
    ↓
    → expired: active = false, session_end webhook fired
    → expiring (15 min warn): session_expiring notification written, warningSent = true
```

### Webhook events fired (external, per user config)

| Event              | Triggered by                          |
|--------------------|---------------------------------------|
| `own_session_start`| Session owner — onSessionCreated      |
| `followed_qrv`     | Each follower — onSessionCreated      |
| `nearby_qrv`       | Each nearby user — onSessionCreated   |
| `session_end`      | Session owner — cleanExpiredSessions  |

Webhook payload schema (`WebhookPayload`):
```
source: 'qrvee'
type: WebhookEventType
callsign: string
band?: string
mode?: string
lat?: number
lng?: number
city?: string
country?: string
timestamp: string (ISO 8601)
```

---

## 6. CONSUMER BEHAVIOR — PNOT

### What PNOT actually is (as implemented)

There are **two separate PNOT integration paths**:

#### Path A: Internal Firestore bridge (`pnot_notes` collection)
- Function: `createPnotProjectNote()` in `firebase/functions/src/pnot.ts`
- Writes a note to internal `pnot_notes` Firestore collection
- `syncedToPnot: false` — the external sync is **not implemented**
- This collection is a staging area, not a real event

#### Path B: External PNOT API client (`pnot-client.ts`)
- File: `apps/web/src/lib/api/pnot-client.ts`
- Calls `https://api.pnot.io/v1` — external PNOT service
- Converts QSO logbook entries (`OfflineQSO`) into PNOT notes via `qsoToNote()`
- Functions: `exportToPnot()`, `fetchPnotStats()`, `syncPnotToCharacters()`
- Requires user API key stored in settings
- Also has mock mode: `mockExportToPnot()`, `mockFetchPnotStats()`

### PNOT filtering / processing logic

**Path A** — No filtering. Writes unconditionally when called.

**Path B** — Client reads QSO from local logbook, converts to note format:
```
OfflineQSO → qsoToNote() → POST /notes (PNOT API)
```
Fields mapped:
- `callsign`, `frequency`, `mode`, `band`, `rstSent`, `rstReceived`, `datetimeMs`, `notes`
- Title format: `QSO: {callsign} on {freqMhz} MHz ({mode})`
- Tags: `['qso', 'ham-radio', mode, band]`
- Source: `'qrvee'`

**Stats sync** (`syncPnotToCharacters()`):
- Fetches `noteCount` and `streak` from PNOT
- Every note = 10 XP to QRVEE character
- streak ≥ 7 days = bonus 100 XP

---

## 7. DETECTED PROBLEMS

### Schema inconsistencies

1. **`band` is optional in sessions but assumed present** — `onSessionCreated` uses `band` in notification body without null check; missing band → "Bant: undefined" in notification text
2. **`warningSent` field not set on session creation** — cleanExpiredSessions queries `warningSent == false` but field doesn't exist on new sessions; Firestore treats missing field differently than `false` — this query likely fails silently for new sessions

### Missing fields

3. **No `endedAt` field** — sessions set `active: false` but never record when they ended; no way to calculate session duration after the fact
4. **No version field** — no schema version on any document; impossible to migrate without full collection scan
5. **`admin_message` NotifType has no producer** — defined in shared types, no Cloud Function writes it

### Implicit assumptions

6. **PNOT external API (`api.pnot.io`) may not exist** — there is a full mock mode, suggesting the real API is not production-ready or not live
7. **`pnot_notes` collection is a dead-end** — `syncedToPnot: false` is set but never flipped; no scheduled job or trigger reads this collection to sync externally
8. **No event ordering guarantee** — consumers read from `notifications` ordered by `createdAt` (client-set serverTimestamp), but FCM delivery and Firestore reads are not transactional; FCM may arrive before Firestore doc is readable
9. **Webhook delivery is fire-and-forget** — errors are silently swallowed; no retry, no delivery confirmation, no dead-letter queue
10. **No event for manual session end** — `endSession()` sets `active: false` but fires no webhook and writes no notification; only timer-based expiry fires `session_end` webhook

---
