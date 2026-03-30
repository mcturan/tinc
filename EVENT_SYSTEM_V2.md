# EVENT SYSTEM V2 — PRODUCTION DESIGN

> Design only. No UI. No app redesign. Event system scope only.
> Informed by: EVENT_SYSTEM_CURRENT.md, MASTER_GUIDE.md, ARCHITECTURE.md
> Updated: 2026-03-30 (TASK-007 — local processing layer added)

---

## CHANGELOG

| Version | Date       | Change                                                         |
|---------|------------|----------------------------------------------------------------|
| v2.0    | 2026-03-29 | Initial design (TASK-004)                                      |
| v2.1    | 2026-03-30 | Removed processedBy from event schema. Introduced event_processing collection. Events now fully immutable. (TASK-005) |
| v2.2    | 2026-03-30 | Added Section 10: Execution Model — actors, responsibilities, execution flow, locking, offline model, scheduling. (TASK-006) |
| v2.3    | 2026-03-30 | Updated Section 10.1 actor table. Added Section 11: Local Processing — scope, local flow, reconciliation, conflict resolution. (TASK-007) |

---

## 1. COLLECTIONS

Four collections total. Three event sources, one processing tracker.

| Collection          | Source          | Purpose                                           |
|---------------------|-----------------|---------------------------------------------------|
| `events_qrvee`      | QRVEE           | Session, QSO, broadcast events — immutable        |
| `events_pnot`       | PNOT            | Note, task, project events — immutable            |
| `events_minwin`     | MINWIN          | Auction, offer, match events — immutable          |
| `event_processing`  | Cloud Functions | Per-consumer processing state — mutable           |

**Event collections:** write-once, append-only. Never mutated after creation. No status fields.
**event_processing:** the only mutable collection in the event system. Owned by Cloud Functions.

---

## 2. STRICT EVENT SCHEMA

Every document in `events_qrvee`, `events_pnot`, `events_minwin` must conform to this schema.
Events are written once and never updated. Firestore rules enforce `allow update: if false`.

### 2.1 Base Event Schema (all event collections)

```
{
  // Identity
  schemaVersion: number          // Always 1 for V2 events. Increment on breaking changes.
  sourceApp:     'qrvee' | 'pnot' | 'minwin'
  type:          string          // Event type — see type registry below

  // Ownership
  userId:        string          // Firebase Auth UID of the user who caused this event
  targetApps:    string[]        // Which apps should consume this event e.g. ['pnot', 'tinc']

  // Payload
  payload:       object          // Event-specific data — see per-type definitions below

  // Timing
  clientTime:    string          // ISO 8601 — set by producing client at write time
  serverTime:    Timestamp       // Firestore serverTimestamp() — set at write

  // Deduplication
  sourceEventId: string | null   // If derived from another event, its Firestore doc ID. Else null.
                                 // Prevents cascading duplicate chains across apps.
}
```

**Removed from v2.0:** `processedBy`, `status` — these are no longer in the event document.
The event document is now a pure, immutable fact. All processing state is external.

### 2.2 event_processing Schema

One document per (eventId, consuming app) pair.
Document ID: `{eventId}_{app}` (e.g. `abc123_pnot`)

```
{
  // Reference
  eventId:       string          // Firestore doc ID of the source event
  sourceApp:     string          // Which event collection: 'qrvee' | 'pnot' | 'minwin'
  app:           string          // Consuming app: 'pnot' | 'qrvee' | 'minwin' | 'tinc'
  userId:        string          // Copied from event for efficient querying

  // State
  status:        'pending' | 'processing' | 'done' | 'failed' | 'skipped'

  // Retry tracking
  attempts:      number          // How many times processing was attempted (starts at 0)
  lastAttemptAt: Timestamp | null
  completedAt:   Timestamp | null // Set when status = 'done'

  // Error tracking
  error:         string | null   // Last error message if status = 'failed'

  // Timestamps
  createdAt:     Timestamp       // When this processing record was created
}
```

### 2.3 Event Type Registry — events_qrvee

| type                  | Trigger                                    | targetApps       |
|-----------------------|--------------------------------------------|------------------|
| `session.started`     | User goes QRV (session created)            | `['pnot']`       |
| `session.ended`       | Session expired OR manually ended          | `['pnot']`       |
| `session.renewed`     | User renews active session                 | `['pnot']`       |
| `qso.logged`          | User logs a QSO contact                    | `['pnot']`       |
| `broadcast.sent`      | Org admin sends broadcast                  | `['pnot']`       |
| `user.approved`       | Admin approves a new user                  | `['tinc']`       |

### 2.4 Event Type Registry — events_pnot

| type                  | Trigger                                    | targetApps       |
|-----------------------|--------------------------------------------|------------------|
| `note.created`        | User creates a note in PNOT                | `['qrvee']`      |
| `note.streak.reached` | User hits a streak milestone (7, 30, 100d) | `['qrvee']`      |
| `task.completed`      | User completes a PNOT task                 | `['qrvee']`      |

### 2.5 Event Type Registry — events_minwin

| type                   | Trigger                                   | targetApps          |
|------------------------|-------------------------------------------|---------------------|
| `auction.created`      | Buyer posts a wanted ad / contract        | `['qrvee', 'pnot']` |
| `offer.submitted`      | Seller submits an offer                   | `['qrvee', 'pnot']` |
| `offer.accepted`       | Buyer accepts an offer                    | `['qrvee', 'pnot']` |
| `auction.expired`      | Auction closes with no accepted offer     | `['qrvee', 'pnot']` |

### 2.6 Payload Schemas (per type)

#### session.started
```
payload: {
  callsign:        string          // required
  mode:            string          // required
  band:            string | null   // null for network modes — never undefined
  frequencyMHz:    number | null
  digitalNetwork:  string | null
  latitude:        number
  longitude:       number
  country:         string          // ISO 2-char
  continent:       string
  city:            string | null
  radiusKm:        number
  durationMinutes: number
  sessionId:       string          // Firestore sessions/{id}
  note:            string | null
  potaRef:         string | null
  sotaRef:         string | null
  contestName:     string | null
}
```

#### session.ended
```
payload: {
  sessionId:  string
  callsign:   string
  startedAt:  string    // ISO 8601
  endedAt:    string    // ISO 8601
  reason:     'expired' | 'manual'
}
```

#### qso.logged
```
payload: {
  logbookId:    string
  callsign:     string
  frequencyMHz: number | null
  band:         string | null
  mode:         string | null
  rstSent:      string | null
  rstReceived:  string | null
  datetimeMs:   number          // UTC epoch ms
  notes:        string | null
}
```

#### note.streak.reached
```
payload: {
  streakDays:   number
  noteCount:    number
  lastNoteDate: string          // ISO date YYYY-MM-DD
}
```

#### auction.created / offer.submitted / offer.accepted / auction.expired
```
payload: {
  contractId:   string
  category:     string          // MinWinCategory
  title:        string
  scope:        'local' | 'regional' | 'global'
  priceOffered: number | null   // null for auction.created and auction.expired
  currency:     string | null
}
```

---

## 3. EVENT LIFECYCLE

```
[Producer App]
    │
    ▼
1. CREATION
   Producer writes event to events_{app}/{id}
   Fields: schemaVersion, sourceApp, type, userId, targetApps,
           payload, clientTime, serverTime, sourceEventId
   Event is complete. Never touched again.
    │
    ▼
2. DETECTION
   Cloud Function trigger: onDocumentCreated('events_{app}/{eventId}')
   OR scheduled poll (fallback for offline-written events)
   Validates schema — logs invalid events, does not write processing records for them
    │
    ▼
3. ROUTING
   For each app in event.targetApps[]:
     Create event_processing document: {eventId}_{app}
     status = 'pending', attempts = 0
   Dispatch one handler per consumer (Promise.allSettled)
    │
    ▼
4. CONSUMPTION
   Each consumer handler:
     a. Read event_processing/{eventId}_{app}
     b. If status = 'done' or 'skipped' → return immediately (idempotency guard)
     c. If status = 'processing' → another instance is running → return (concurrency guard)
     d. Update event_processing: status = 'processing', lastAttemptAt = now, attempts += 1
     e. Execute business logic
     f. On success: update status = 'done', completedAt = now, error = null
     g. On failure: update status = 'failed', error = message
    │
    ▼
5. COMPLETION
   No status field on the event itself.
   Overall state is derived by querying event_processing for a given eventId:
     - All 'done'/'skipped' → complete
     - Any 'failed' with attempts >= 4 → needs attention
     - Any 'pending'/'processing' → in progress
    │
    ▼
6. RETENTION
   Events are never deleted.
   Archived after 90 days (status='done' in all processing records).
   event_processing records for failed events retained indefinitely.
```

---

## 4. PRODUCER RULES — QRVEE

### Rule P-1: Event on every state change
Any action that changes user or session state MUST write an event before the action is considered complete.
Order: write event first, then perform action (or atomically via Firestore batch).

### Rule P-2: Optional payload fields are always null, never absent
Optional fields in `payload` must be written as `null` explicitly, never omitted.
This eliminates the V1 `band: undefined` class of bugs.

### Rule P-3: Session end always fires an event
Both `endSession()` (manual) and `cleanExpiredSessions()` (timer) must write `session.ended`.
The `reason` field distinguishes them. Closes V1 problem #10.

### Rule P-4: clientTime is always set by the client at write time
`clientTime = new Date().toISOString()` before the Firestore write.
`serverTime = serverTimestamp()`. Both required.

### Rule P-5: sourceEventId links derived events
If event B is triggered by event A, set `sourceEventId = A_doc_id`.
If not derived from another event, set `sourceEventId = null`.
Enables loop detection and deduplication at the data layer.

### Rule P-6: schemaVersion must be 1
Producers write `schemaVersion: 1`. Consumers reject unknown versions — no silent ignoring.

### When QRVEE must write events

| Action                      | Event to write                          |
|-----------------------------|-----------------------------------------|
| createSession() called      | `session.started`                       |
| endSession() called         | `session.ended` (reason: manual)        |
| cleanExpiredSessions fires  | `session.ended` (reason: expired) × N  |
| renewSession() called       | `session.renewed`                       |
| QSO written to logbook      | `qso.logged`                            |
| Org broadcast sent          | `broadcast.sent`                        |

---

## 5. CONSUMER RULES — PNOT

### Rule C-1: Always read event_processing before acting
Before any logic, read `event_processing/{eventId}_pnot`.
If `status = 'done'` or `'skipped'` → return immediately.
If `status = 'processing'` → another execution is live → return immediately.

### Rule C-2: Set 'processing' atomically before acting
Use a Firestore transaction to:
  1. Read current status
  2. Confirm it is 'pending' or 'failed' (eligible for processing)
  3. Write status = 'processing', attempts += 1, lastAttemptAt = now
If transaction fails (contention) → abort; the other execution will handle it.

### Rule C-3: Never process events not in targetApps
If `'pnot'` is not in `event.targetApps`, set `event_processing` status = 'skipped'.
No business logic runs.

### Rule C-4: Filter by userId — skip unlinked users
PNOT only processes events for users who have a linked PNOT account.
If no link: set status = 'skipped'. Do not fail.

### Rule C-5: Idempotent business logic via sourceEventId
All PNOT writes use the Firestore event doc ID as a deduplication key.
Before creating a PNOT note: query `where('sourceEventId', '==', eventDocId)`.
If a record already exists with that key → skip creation, mark done.

### Rule C-6: Never write to source app collections
PNOT must not write to `sessions`, `notifications`, `logbook`, or any QRVEE collection.
Cross-app communication goes through `events_pnot` only.

### PNOT event processing map

| events_qrvee type  | PNOT action                                        |
|--------------------|----------------------------------------------------|
| `session.started`  | Create activity note in PNOT (if user linked)      |
| `session.ended`    | Close activity note, record duration               |
| `qso.logged`       | Convert QSO to PNOT note via qsoToNote()           |
| `broadcast.sent`   | Create informational note in PNOT                  |

---

## 6. FAILURE HANDLING

### Retry policy

| Attempt | Delay before retry |
|---------|--------------------|
| 1       | immediate          |
| 2       | 30 seconds         |
| 3       | 5 minutes          |
| 4 (max) | no more retries    |

After 4 attempts: `event_processing.status = 'failed'` remains.
No mutation of the original event document occurs at any point.

Retry trigger: scheduled function runs every 5 minutes.
Query: `event_processing WHERE status = 'failed' AND attempts < 4 AND lastAttemptAt < (now - delay)`
Re-dispatches eligible records to the appropriate consumer handler.

### Duplicate prevention — two layers

**Layer 1 — event_processing status check (runtime)**
Consumer reads `event_processing/{eventId}_{app}` before acting.
If status is 'done', 'skipped', or 'processing' → abort immediately.
Implemented as a Firestore transaction (atomic read-then-write).

**Layer 2 — sourceEventId deduplication (data)**
PNOT notes store the source Firestore event doc ID:
```
sourceEventId: <events_qrvee/{eventId}>
```
Before creating, query: `where('sourceEventId', '==', eventId)`.
If a record with that key exists → skip, mark event_processing done.

### Dead-letter handling

Failed events (`status = 'failed'` AND `attempts >= 4`) are not moved.
The `event_processing` record is the dead-letter record itself.

A scheduled daily function queries:
```
event_processing WHERE status = 'failed' AND attempts >= 4
```
Outputs counts per app for monitoring.

Manual reprocessing: reset `event_processing.status = 'pending'` and `attempts = 0`.
The retry scheduler picks it up within 5 minutes.

### Offline writes

QRVEE writes events locally first (IndexedDB / OfflineQueue).
On reconnect, events flush to Firestore in order.
`clientTime` preserves original write time.
Consumers order by `serverTime` only (authoritative ordering).

---

## 7. FIRESTORE RULES (outline)

```
// ── Event collections — immutable ──────────────────────────────────────────

match /events_qrvee/{eventId} {
  allow create: if isApproved()
    && request.resource.data.userId      == request.auth.uid
    && request.resource.data.sourceApp   == 'qrvee'
    && request.resource.data.schemaVersion == 1;
  allow update: if false;   // Events are immutable
  allow delete: if false;
  allow read:   if isSignedIn() && resource.data.userId == request.auth.uid;
}

// Same pattern for events_pnot (sourceApp == 'pnot') and events_minwin (sourceApp == 'minwin')

// ── Processing state — Cloud Functions only ─────────────────────────────────

match /event_processing/{recordId} {
  allow read:   if isSignedIn()
    && resource.data.userId == request.auth.uid;
  allow create: if false;   // Cloud Functions (admin SDK) only
  allow update: if false;   // Cloud Functions (admin SDK) only
  allow delete: if false;
}
```

---

## 8. KNOWN CONSTRAINTS AND OPEN QUESTIONS

| # | Constraint / Question                                                             | Decision needed by |
|---|-----------------------------------------------------------------------------------|--------------------|
| 1 | PNOT external API (api.pnot.io) status unknown — V2 assumes Firestore-native PNOT | Before Phase 2    |
| 2 | MINWIN event producers do not exist yet — schema defined speculatively             | Before MINWIN Phase|
| 3 | ~~Retry scheduler: Cloud Tasks vs scheduled poller~~ — **DECIDED (TASK-006):** scheduled poller every 5 minutes. No Cloud Tasks dependency. | CLOSED |
| 4 | Event retention period (90 days) may need adjustment at scale                     | Phase 5            |
| 5 | Cross-user events (e.g. nearby_qrv) — per-userId design; fan-out events need separate pattern | Phase 3 |

---

## 9. MIGRATION FROM V1

V1 (current) and V2 run in parallel during transition.
V1 `sessions` collection is not removed — it continues to power the QRVEE feed.
V2 adds event writes alongside V1 writes (dual-write period).

Migration steps:
1. Add `session.started` write in `createSession()` (alongside existing addDoc)
2. Add `session.ended` write in both `endSession()` and `cleanExpiredSessions()`
3. Add `qso.logged` write in logbook write path
4. Deploy Cloud Function: `onDocumentCreated('events_qrvee/{id}')` → creates `event_processing` records + dispatches handlers
5. Validate V2 flow in staging — confirm `event_processing` records reach 'done'
6. Remove V1 `pnot_notes` writes and `pnot-client.ts` direct calls once V2 is stable

---

## 10. EXECUTION MODEL

### 10.1 Actors

Two actors. No more.

| Actor            | Role                      | Can write events? | Processes own events locally? | Processes cross-app effects? |
|------------------|---------------------------|-------------------|-------------------------------|------------------------------|
| **Client**       | mobile app / web app      | YES               | YES (local state only)        | NO                           |
| **Cloud Worker** | Firebase Cloud Function   | NO                | NO                            | YES                          |

**Client responsibilities:**
- Produces events (writes to `events_*` collections)
- Processes its own events locally for immediate UI updates (see Section 11)
- Queues events locally when offline; flushes on reconnect
- May read `event_processing` to display sync status (read-only)
- Never executes cross-app business logic (PNOT writes, XP, notifications to other users)

**Cloud Worker responsibilities:**
- Sole executor of all cross-app and cross-user effects
- Creates `event_processing` records
- Manages locking, retries, and failure tracking
- Never writes to `events_*` collections (except derived events via sourceEventId)

**Why the split:**
- Client must not wait for server to update its own UI — violates offline-first
- Cross-app logic (PNOT, XP, fan-out notifications) requires server auth and must be auditable
- Local processing is UI-layer only — no Firestore writes beyond the event itself
- No business logic is duplicated: client updates display state, cloud executes side effects

---

### 10.2 Cloud Worker Types

Two Cloud Function types. One reactive, one scheduled.

| CF Type          | Name                        | Trigger                        | Purpose                              |
|------------------|-----------------------------|--------------------------------|--------------------------------------|
| **Router CF**    | `onEventCreated`            | `onDocumentCreated(events_*)` | Detect new events, create processing records, dispatch handlers |
| **Retry CF**     | `retryFailedProcessing`     | `onSchedule('every 5 minutes')` | Re-attempt failed/stuck processing records |

The Router CF is the primary path. The Retry CF is the safety net.

---

### 10.3 Execution Flow

```
[CLIENT — online or offline]
    │
    │  writes event to events_{app}/{id}
    │  (locally queued if offline, flushed on reconnect)
    ▼
[FIRESTORE — events_{app}]
    │
    │  onDocumentCreated fires
    ▼
[ROUTER CF — onEventCreated]
    │
    1. Validate event schema (schemaVersion, required fields)
       → Invalid: log error, stop. Do not create processing records.
    │
    2. For each app in event.targetApps[]:
       → Create event_processing/{eventId}_{app}
          { status: 'pending', attempts: 0, createdAt: now, ... }
    │
    3. Dispatch consumer handlers in parallel (Promise.allSettled)
       → One handler call per targetApp
    │
    ▼ (per consumer handler, running in parallel)
[CONSUMER HANDLER — e.g. processPnot(eventId)]
    │
    4. Read event doc from events_{sourceApp}/{eventId}
    │
    5. LOCK — Firestore transaction on event_processing/{eventId}_{app}:
       a. Read current status
       b. If status = 'done' | 'skipped' | 'processing' → ABORT (idempotency)
       c. If status = 'pending' | 'failed' → write status='processing',
          attempts += 1, lastAttemptAt = now
       Transaction commit fails if another instance already wrote 'processing'
       → concurrent call loses the transaction → exits cleanly
    │
    6. Execute business logic
       (e.g. create PNOT note, update XP, send notification)
    │
    7a. SUCCESS:
        Update event_processing: status='done', completedAt=now, error=null
    │
    7b. FAILURE:
        Update event_processing: status='failed', error=message
        → Retry CF will pick it up within 5 minutes
```

---

### 10.4 Locking Mechanism

**Problem:** Cloud Functions can run multiple concurrent instances. Two instances could both pick up the same `event_processing` record simultaneously.

**Solution:** Firestore transaction as a compare-and-swap lock.

```
Transaction {
  read:  event_processing/{eventId}_{app}
  check: current.status must be 'pending' OR 'failed'
  write: { status: 'processing', attempts: current.attempts + 1, lastAttemptAt: now }
}
```

- If another instance already set status to 'processing' → transaction aborts (Firestore detects write conflict)
- The losing instance receives a transaction failure → exits without running business logic
- No event is processed twice

**Stuck processing guard:**
If a CF instance crashes mid-execution, the record stays `status='processing'` indefinitely.
The Retry CF detects stale 'processing' records:

```
event_processing WHERE status = 'processing'
  AND lastAttemptAt < (now - 10 minutes)
```

Stale records are reset to `status='failed'` for the retry scheduler to pick up.
The 10-minute threshold is larger than any expected CF execution time.

---

### 10.5 Offline Model

**Client-side (QRVEE already implements this):**

```
[User action]
    │
    ├── Online:  write event directly to Firestore → Router CF fires immediately
    │
    └── Offline: write event to local OfflineQueue (IndexedDB)
                 clientTime = now (preserved for ordering)
                    │
                    ▼ (on reconnect)
                 OfflineQueue.flush() → writes events to Firestore in clientTime order
                 → Router CF fires for each event as it arrives
```

**No special offline handling needed server-side.** The Cloud Functions do not know or care whether an event was written online or after an offline flush. Events arrive at Firestore and are processed normally.

**Conflict resolution for offline events:**

| Scenario                                         | Resolution                                      |
|--------------------------------------------------|-------------------------------------------------|
| Same event written twice (double flush bug)      | Layer 2 deduplication (sourceEventId key)       |
| Two offline events from same session, out of order | Consumers order by clientTime within same userId |
| Event arrives after its dependent event          | sourceEventId chain allows consumers to detect ordering; processing is idempotent regardless |
| Offline event for a session that already ended   | Consumer checks session state before acting; skips gracefully |

**What the client must guarantee:**
- Each event written to OfflineQueue has a unique clientTime (ms precision)
- Events are flushed in clientTime order (oldest first)
- Flush is atomic per event (not batched) to preserve trigger ordering

---

### 10.6 Scheduling Model

**Primary path: trigger-based (Router CF)**

```
onDocumentCreated('events_qrvee/{id}')
onDocumentCreated('events_pnot/{id}')
onDocumentCreated('events_minwin/{id}')
```

Fires immediately on every new event. Zero-delay processing when online.
No polling. No overhead for events that never come.

**Fallback path: scheduled poller (Retry CF)**

Runs on `onSchedule('every 5 minutes')`.
Handles three cases:

| Case                          | Query                                                              | Action                    |
|-------------------------------|--------------------------------------------------------------------|---------------------------|
| Failed, retryable             | `status='failed' AND attempts < 4 AND lastAttemptAt < (now-delay)` | Re-dispatch to handler    |
| Stuck in processing           | `status='processing' AND lastAttemptAt < (now - 10min)`           | Reset to 'failed'         |
| Missed (trigger didn't fire)  | `status='pending' AND createdAt < (now - 2min)`                   | Re-dispatch to handler    |

**Why 5 minutes for the scheduler:**
- Matches the existing `cleanExpiredSessions` scheduler interval (already deployed)
- Simple and predictable — no Cloud Tasks dependency
- Worst-case retry latency is acceptable for async cross-app sync

**Retry delay enforcement (per attempt):**

The scheduler enforces minimum delay between attempts via `lastAttemptAt`:

| Attempt | Minimum wait before retry |
|---------|---------------------------|
| 2       | 30 seconds                |
| 3       | 5 minutes                 |
| 4       | 15 minutes                |

Scheduler runs every 5 minutes but only picks up records where `lastAttemptAt < (now - required_delay)`.
Records not yet eligible are skipped in that run.

---

## 11. LOCAL PROCESSING

### 11.1 What Local Processing Is

Local processing is the client applying the **visible result of its own action to local state immediately**, without waiting for the server.

It is **not** re-implementing cloud business logic on the client.
It is **not** writing to Firestore beyond the event itself.
It is **not** computing cross-app effects.

It is: updating in-memory / local store state so the UI reflects what the user just did.

---

### 11.2 Division of Responsibilities

| Effect                                    | Processed by    |
|-------------------------------------------|-----------------|
| Show own session as active in UI          | Client (local)  |
| Show own QSO as logged in logbook UI      | Client (local)  |
| Mark own note as created in PNOT UI       | Client (local)  |
| Notify followers that user went QRV       | Cloud only      |
| Create PNOT note from QRVEE session       | Cloud only      |
| Update XP / gamification                  | Cloud only      |
| Send FCM push to other users              | Cloud only      |
| Fan-out to nearby users                   | Cloud only      |
| Cross-app data sync (QRVEE → PNOT)        | Cloud only      |
| Schema validation and enforcement         | Cloud only      |

**Rule: if the effect is visible only to the acting user → local. If it affects anyone else or another system → cloud.**

---

### 11.3 Local Event Flow

```
[User action — e.g. "Go QRV"]
    │
    ├─► 1. Apply optimistic update to local store (synchronous, immediate)
    │        localStore.session = { active: true, callsign, mode, band, ... }
    │        UI re-renders — no spinner, no wait
    │
    └─► 2. Write event to events_qrvee (online) OR OfflineQueue (offline)
             │
             ├── Online:  Firestore write → Router CF fires → cross-app effects
             │
             └── Offline: event queued locally → flushed on reconnect
                          UI already shows correct state from step 1
```

```
[User action — e.g. "Log QSO"]
    │
    ├─► 1. Append QSO to local logbook list immediately
    │        localStore.logbook.unshift(newQso)
    │
    └─► 2. Write to logbook/{id} AND write event qso.logged to events_qrvee
             Cloud processes qso.logged → creates PNOT note
```

```
[User action — e.g. "End Session"]
    │
    ├─► 1. Clear session from local store immediately
    │        localStore.session = null
    │
    └─► 2. Write session.ended event → Cloud handles cross-app effects
```

---

### 11.4 Reconciliation

The client's optimistic state is a **prediction**. The server result is **authoritative**.

Reconciliation happens via Firestore real-time listeners, which are already active in QRVEE.

```
[Optimistic update applied]
    │
    ├── Server confirms (Firestore listener receives matching doc)
    │     → Local state already correct. No action.
    │
    └── Server rejects or differs (rule violation, CF modifies data, validation fails)
          → Firestore listener fires with server's authoritative state
          → Client replaces local state with server state
          → If server has no doc (write rejected): client rolls back
          → Surface error to user if appropriate
```

**Reconciliation rule: server always replaces local on conflict. No merge. No negotiation.**

The client must implement listeners that overwrite local state completely on server update.
Partial merges are not safe — they risk retaining stale optimistic fields.

---

### 11.5 Conflict Resolution

| Scenario                                             | Resolution                                          |
|------------------------------------------------------|-----------------------------------------------------|
| Server confirms optimistic state                     | No change — states match                           |
| Server rejects write (Firestore rule)                | Roll back local state; surface write error          |
| CF modifies payload before writing to target         | Server listener fires; replace local state          |
| User goes offline mid-action (event queued)          | Optimistic state stands until reconnect + server confirms |
| Server confirms after offline flush                  | Listener fires; if matching, no visible change      |
| Two devices: user acts on both while offline         | Server processes events in `serverTime` order; last server write wins; each device reconciles via listener |
| Event rejected because session already expired       | Consumer sets event_processing status='skipped'; client listener shows session as ended |

---

### 11.6 What is Explicitly Not Local Processing

These effects must **never** be applied client-side optimistically:

- **Other users' state** — never predict what another user's session looks like
- **PNOT note creation** — client does not know if PNOT is linked or what PNOT will do
- **XP or gamification changes** — cloud is authoritative on all scores
- **Cross-user notifications** — client does not know who follows the user
- **Validation outcomes** — client does not replicate Firestore rule logic

If a screen must show a cross-app result (e.g. "your QSO was synced to PNOT"), it reads from `event_processing` once the CF marks it done — it does not predict it.

---
