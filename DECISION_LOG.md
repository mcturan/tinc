# DECISION LOG

> **APPEND-ONLY:** Do not remove or modify existing entries. Only add new entries at the bottom.

---

## LAWS

### LAW-001
All decisions, changes, features must be logged before considered complete.

### LAW-002
All tasks must be executed via TASK.md → RESULT.md pipeline.

---

## ENTRY FORMAT

Each entry must follow:

- **TYPE** — (DECISION / SNAPSHOT / CHANGE / FEATURE)
- **SOURCE** — (TASK-ID or origin)
- **DESCRIPTION** — What was done
- **REASON** — Why it was done
- **IMPACT** — What it affects
- **STATUS** — (PENDING / COMPLETE / CANCELLED)

---

## SNAPSHOT: PHASE-0 — Initial System State

**Date:** 2026-03-29
**Entry:** TASK-001 — Baseline snapshot

| Component | Status          | Notes                          |
|-----------|-----------------|--------------------------------|
| TINC      | Not implemented | Core system missing            |
| QRVEE     | Advanced        | Most developed component       |
| PNOT      | Partial         | Implemented, not complete      |
| MINWIN    | Not started     | Concept only                   |
| Event system | Not production ready | Event-based arch decided, not stable |

**Architecture decisions in effect:**
- Event-based system (no direct API)
- Offline-first design
- QRVEE is not a core dependency of TINC

---

## DECISION: TASK-002 — Standardize Log Format

- **TYPE:** DECISION
- **SOURCE:** TASK-002
- **DESCRIPTION:** Replaced LAW-001 and LAW-002 with correct definitions; added ENTRY FORMAT section; added append-only notice
- **REASON:** Initial laws were informal placeholders, not operational rules
- **IMPACT:** All future log entries must follow the defined format
- **STATUS:** COMPLETE

---

## SNAPSHOT: TASK-003 — Event System Reality Extraction

- **TYPE:** SNAPSHOT
- **SOURCE:** TASK-003
- **DESCRIPTION:** Extracted real event system from QRVEE codebase. Created /tinc/EVENT_SYSTEM_CURRENT.md. No dedicated event bus collection exists — sessions collection is the de facto event source. PNOT integration has two paths: internal pnot_notes (staging, never synced) and external api.pnot.io (mock mode active). 10 problems identified (missing fields, dead-end collection, no session_end event on manual close, fire-and-forget webhooks).
- **REASON:** TINC needs a baseline understanding of existing event infrastructure before designing integration
- **IMPACT:** Blocks TINC architecture decisions until known; provides input for event contract design
- **STATUS:** COMPLETE

---

## DECISION: TASK-004 — Event System V2 Design

- **TYPE:** DECISION
- **SOURCE:** TASK-004
- **DESCRIPTION:** Designed production-grade event system. Created /tinc/EVENT_SYSTEM_V2.md. Defined 3 collections (events_qrvee, events_pnot, events_minwin), strict base schema with schemaVersion/processedBy/sourceEventId, full lifecycle (creation→routing→consumption→completion), 6 producer rules, 6 consumer rules, 4-attempt retry policy, two-layer duplicate prevention, dead-letter pattern, Firestore rules outline, and V1→V2 migration steps.
- **REASON:** Current trigger-based system has no duplicate prevention, no retry, no event ordering, no cross-app contract — not production-ready
- **IMPACT:** All cross-app data flow must use events_* collections going forward; V1 pnot_notes and direct API calls are deprecated pending migration
- **STATUS:** COMPLETE

---

## DECISION: TASK-005 — Separate Event Data from Processing State

- **TYPE:** DECISION
- **SOURCE:** TASK-005
- **DESCRIPTION:** Removed processedBy map and status field from event schema. Events are now fully immutable (allow update: if false; allow delete: if false). Introduced event_processing collection with schema {eventId, sourceApp, app, userId, status, attempts, lastAttemptAt, completedAt, error, createdAt}. Document ID pattern: {eventId}_{app}. Processing flow now: CF creates event_processing records on detection → consumer uses atomic transaction on event_processing (not event doc) for idempotency → retry scheduler queries event_processing. Dead-letter is the event_processing record itself (no separate collection needed). Updated EVENT_SYSTEM_V2.md to v2.1.
- **REASON:** Mutating event documents couples producer and consumer concerns. Immutable events enable audit trail, multi-consumer fan-out, and replay without side effects.
- **IMPACT:** event_processing is now the single source of truth for processing state; event documents are permanent facts; Firestore rules enforce immutability on all events_* collections
- **STATUS:** COMPLETE

---

## DECISION: TASK-006 — Execution Model

- **TYPE:** DECISION
- **SOURCE:** TASK-006
- **DESCRIPTION:** Defined two actors: Client (produces events only) and Cloud Worker (processes events only). Defined two CF types: Router CF (onDocumentCreated — immediate dispatch, creates event_processing records, parallel handlers) and Retry CF (onSchedule every 5 min — handles failed/stuck/missed records). Defined Firestore transaction as the locking mechanism (compare-and-swap on event_processing status). Defined 10-minute stuck-processing detection threshold. Defined offline model: client queues locally, flushes on reconnect in clientTime order, server-side is unaware of offline state. Closed open question #3: scheduled poller chosen over Cloud Tasks (simpler, no new dependency, 5-min granularity sufficient). Updated EVENT_SYSTEM_V2.md to v2.2.
- **REASON:** Without a defined execution model, implementation teams cannot build the system — who triggers what, when, and how concurrent safety is guaranteed must be explicit
- **IMPACT:** Two CF functions to implement (onEventCreated + retryFailedProcessing); client code must never run consumer logic; OfflineQueue flush must be ordered and per-event
- **STATUS:** COMPLETE

---

## DECISION: TASK-007 — Local Processing Layer

- **TYPE:** DECISION
- **SOURCE:** TASK-007
- **DESCRIPTION:** Refined actor model: Client now processes its own events locally for UI state (optimistic updates). Cloud still owns all cross-app and cross-user effects. Defined division rule: "if effect is visible only to acting user → local; if it affects anyone else or another system → cloud." Defined local event flow: user action → apply optimistic update to local store (sync, immediate) → write event to Firestore/OfflineQueue. Defined reconciliation: Firestore real-time listeners are the reconciliation mechanism; server always replaces local on conflict (no merge). Defined 6 conflict scenarios and resolutions. Defined explicit list of effects that must never be applied locally (other users' state, PNOT note creation, XP, cross-user notifications). Added Section 11 to EVENT_SYSTEM_V2.md. Updated to v2.3.
- **REASON:** Without local processing, UI waits for server on every action — violates offline-first. Without a clear scope boundary, business logic gets duplicated on client, creating consistency risk.
- **IMPACT:** Client must maintain a local store (Zustand/IndexedDB) that is updated optimistically and reconciled via Firestore listeners; cross-app status (e.g. "synced to PNOT") must be read from event_processing, never predicted
- **STATUS:** COMPLETE

---

## CHANGE: TASK-008 — Event System V2 Infrastructure Implementation

- **TYPE:** CHANGE
- **SOURCE:** TASK-008
- **DESCRIPTION:** Implemented core event system infrastructure in code. Created 3 new TypeScript source files: schema.ts (types + validateEvent()), router.ts (onQrveeEventCreated / onPnotEventCreated / onMinwinEventCreated CF triggers + dispatchHandler + acquireLock + PNOT/placeholder handlers), retry.ts (retryFailedProcessing scheduled CF with stuck detection / retry backoff / missed-event recovery / dead-letter reporting). Updated index.ts to export 4 new CF functions. Updated firestore.rules to add immutable rules for events_qrvee / events_pnot / events_minwin and CF-only rules for event_processing. TypeScript build: zero errors.
- **REASON:** Event system design (TASK-004 through TASK-007) was complete; Phase 2 requires working code, not just documents
- **IMPACT:** 4 new Cloud Functions are deployable: onQrveeEventCreated, onPnotEventCreated, onMinwinEventCreated, retryFailedProcessing. PNOT handler operational for session.started and qso.logged. QRVEE/TINC/MINWIN handlers are stubs awaiting future tasks. Firestore rules enforce event immutability.
- **STATUS:** COMPLETE

---

## CHANGE: TASK-009 — Handler Separation + Run Log System

- **TYPE:** CHANGE
- **SOURCE:** TASK-009
- **DESCRIPTION:** Refactored event system code (no behavior change). Extracted all consumer handler logic from router.ts into events/handlers/ directory: lock.ts (acquireLock/markDone/markFailed shared utilities), pnot.ts, qrv.ts, tinc.ts, minwin.ts. Router.ts now contains only: schema validation, event_processing batch creation, dispatchHandler switch. Established /tinc/RUN_LOG/ as canonical execution trace directory. Created RUN_LOG/TASK-009.md. Git commit created: 7a06015.
- **REASON:** Router was mixing routing concerns with business logic. Separation makes each handler independently modifiable and the dispatch path easy to audit.
- **IMPACT:** Adding a new consumer now requires only: (1) create handlers/{app}.ts, (2) add one case to dispatchHandler. No other files change. TypeScript build: zero errors.
- **STATUS:** COMPLETE

---

## CHANGE: TASK-010 — Post-Task Visibility Protocol

- **TYPE:** CHANGE
- **SOURCE:** TASK-010
- **DESCRIPTION:** Established standard post-task output format: commit hash, branch, changed files, RUN_LOG path, and push instruction. Verified RUN_LOG directory exists with at least one file. Committed all pending tinc repo files (DECISION_LOG.md, EVENT_SYSTEM_CURRENT.md, EVENT_SYSTEM_V2.md, RUN_LOG/). No event system or architecture changes.
- **REASON:** Developers need consistent feedback after each task — what was committed, where the log is, how to push.
- **IMPACT:** All future tasks must output the standard visibility block after committing. RUN_LOG is the canonical trace for every executed task.
- **STATUS:** COMPLETE

---

## CHANGE: TASK-011 — Unify tinc Repo into qrv-project

- **TYPE:** CHANGE
- **SOURCE:** TASK-011
- **DESCRIPTION:** Moved entire /home/turan/tinc/ directory into /home/turan/qrv-project/tinc/. Removed nested .git from the copied directory. Staged and committed all 16 tinc files to qrv-project main branch (commit 69a82b3). RUN_LOG canonical path updated: /home/turan/qrv-project/tinc/RUN_LOG/. Original /home/turan/tinc/ repo is now superseded.
- **REASON:** Two separate repos required double commits after every task and created risk of log/code drift. Single repo ensures code changes and their decision records are always in the same commit.
- **IMPACT:** All future task logs go to qrv-project/tinc/RUN_LOG/. DECISION_LOG.md is now at qrv-project/tinc/DECISION_LOG.md. No nested git repos in qrv-project.
- **STATUS:** COMPLETE

---

## CHANGE: TASK-012 — Rename Project Directory to qrvee

- **TYPE:** CHANGE
- **SOURCE:** TASK-012
- **DESCRIPTION:** Renamed local project directory from /home/turan/qrv-project to /home/turan/qrvee. No files or internal paths changed. Git remote confirmed pointing to https://github.com/mcturan/qrvee.git. TypeScript build: zero errors post-rename. RUN_LOG canonical path updated: /home/turan/qrvee/tinc/RUN_LOG/.
- **REASON:** Local directory name did not match GitHub repo name, creating unnecessary confusion.
- **IMPACT:** All future references to the project root use /home/turan/qrvee/. All internal paths, imports, and configs are unchanged.
- **STATUS:** COMPLETE

---

## CHANGE: TASK-013 — Workspace Restructure, TINC Extracted as Core

- **TYPE:** CHANGE
- **SOURCE:** TASK-013
- **DESCRIPTION:** Created /home/turan/workspace/. Moved qrvee into workspace/qrvee. Extracted tinc/ out of qrvee into workspace/tinc. Added workspace/tinc/LOCATION.md reference note. No files modified — directory moves only. TypeScript build: zero errors post-restructure.
- **REASON:** TINC is a core system that will be consumed by multiple apps (qrvee, pnot, minwin). Keeping it inside qrvee was incorrect — it is not an app artifact.
- **IMPACT:** TINC is now structurally independent from any app repo. RUN_LOG canonical path: /home/turan/workspace/tinc/RUN_LOG/. qrvee git repo intact at /home/turan/workspace/qrvee/. workspace root has no .git by design.
- **STATUS:** COMPLETE

---

## SNAPSHOT: TASK-014 — Full Architectural Audit

- **TYPE:** SNAPSHOT
- **SOURCE:** TASK-014
- **DESCRIPTION:** Full audit of workspace structure, event system, logging, code structure, and drift analysis. Created AUDIT_REPORT_TASK-014.md. All sections PASS. Two risks and two missing items identified: RISK-001 (pnot-client.ts direct API usage, mock-only but must be removed before production), RISK-002 (workspace/tinc untracked by git after TASK-013), MISSING-001 (QRVEE client not writing to events_qrvee — highest priority gap), MISSING-002 (local processing layer not started).
- **REASON:** Phase 2 requires validation that implementation matches designed architecture before proceeding with further development.
- **IMPACT:** MISSING-001 is highest priority: event system deployed but receives no real data. Recommendations: TASK-015 dual-write client, TASK-016 remove pnot-client, TASK-017 git strategy for tinc.
- **STATUS:** COMPLETE

---

## CHANGE: TASK-015 — QRVEE Client Event Integration (Phase 3)

- **TYPE:** CHANGE
- **SOURCE:** TASK-015
- **DESCRIPTION:** Activated Event System V2 by integrating QRVEE as event producer. Created writeQrveeEvent() utilities for web (firebase/firestore) and mobile (@react-native-firebase). Modified sessions.ts, logbook/page.tsx, broadcast.tsx, logbook.tsx to dual-write events alongside existing V1 writes. Events activated: session.started, session.ended, session.renewed, qso.logged — all targeting ['pnot', 'tinc']. TypeScript: zero errors on CF build and web tsc. Git commit: cbdb577.
- **REASON:** AUDIT TASK-014 identified MISSING-001: event system was deployed but received no real events. All Router CFs were unreachable from real user actions.
- **IMPACT:** Event system is now live end-to-end. Every session start/end/renew and QSO log from any QRVEE client triggers: Router CF → creates event_processing record → dispatches PNOT handler (operational) and TINC handler (stub). MISSING-001 from TASK-014 audit is RESOLVED.
- **STATUS:** COMPLETE

---

## SNAPSHOT: TASK-016 — Event Lifecycle Validation

- **TYPE:** SNAPSHOT
- **SOURCE:** TASK-016
- **DESCRIPTION:** Validated full event lifecycle (client write → Router CF → handlers → event_processing state) via static code-level analysis. All 10 code-path steps PASS. Firebase emulator was unavailable (JAR download required), so live Firestore testing was not performed. Created EVENT_FLOW_REPORT.md with full trace and live validation checklist. Three minor issues noted (all non-blocking).
- **REASON:** Phase 3 requires confirming the event system functions correctly end-to-end before proceeding with further consumer development.
- **IMPACT:** All event lifecycle code paths verified correct. Live confirmation pending deploy + manual checklist execution. Developer must run live checklist in EVENT_FLOW_REPORT.md before marking Phase 3 complete.
- **STATUS:** COMPLETE (static), PENDING (live) → RESOLVED by TASK-017

---

## CHANGE: TASK-017 — Live Deploy + Event System Validation

- **TYPE:** CHANGE
- **SOURCE:** TASK-017
- **DESCRIPTION:** Fixed deploy pipeline bug where Cloud Build failed to resolve @qrv/shared (local workspace package not on npm). Fix: compiled packages/shared → lib, vendored into firebase/functions/vendor/shared-lib, changed package.json reference to file:./vendor/shared-lib, added tsconfig paths override to prevent rootDir expansion from workspace symlinks, fixed oracle.ts direct relative import. All functions deployed successfully. Live test: 2 events written to events_qrvee (session.started, qso.logged), 4 event_processing records created (status=done, attempts=1, error=null), 2 pnot_notes created with correct titles and sourceEventIds. Git commit: d6c493e.
- **REASON:** TASK-016 static validation could not confirm live execution. Deploy was also broken — @qrv/shared not resolvable by Cloud Build.
- **IMPACT:** All 4 event Cloud Functions are now live (onQrveeEventCreated, onPnotEventCreated, onMinwinEventCreated, retryFailedProcessing). Event system is confirmed working end-to-end in production. TASK-016 PENDING status resolved. Deploy pipeline fixed for all future deployments.
- **STATUS:** COMPLETE

---

## CHANGE: TASK-018 — Firestore Security Rules Hardening

- **TYPE:** CHANGE
- **SOURCE:** TASK-018
- **DESCRIPTION:** Added `isValidEventBase(app)` helper function to firestore.rules validating all required BaseEvent fields on create: schemaVersion, sourceApp, userId, type (non-empty string), clientTime (non-empty string), targetApps (non-empty list), payload (map), sourceEventId (null or string). Updated events_qrvee / events_pnot / events_minwin create rules to use the new validator. Confirmed pre-existing immutability rules (allow update/delete: if false) and event_processing CF-only restriction (all writes: if false) are correct and unchanged. Deployed rules — zero errors. Rate limiting assessed: not possible at Firestore rules layer; field constraints are the correct rules-layer protection.
- **REASON:** Previous create rules only validated userId, sourceApp, and schemaVersion — a malformed event missing type/clientTime/targetApps/payload could be written by an authenticated client and trigger the Router CF with incomplete data.
- **IMPACT:** Any client write to events_* missing required BaseEvent fields is now rejected at the security layer before reaching Cloud Functions. Event flow for well-formed events (produced by writeQrveeEvent()) is unchanged.
- **STATUS:** COMPLETE

---

## CHANGE: TASK-019 — Standardize Naming @qrv/ → @qrvee/

- **TYPE:** CHANGE
- **SOURCE:** TASK-019
- **DESCRIPTION:** Renamed all package identifiers from `@qrv/` namespace to `@qrvee/`. Updated: root package.json ("qrv"→"qrvee"), functions package.json ("qrv-functions"→"qrvee-functions"), web/mobile package names and @qrv/shared dependencies, packages/shared/package.json, vendor/shared-lib/package.json, all three tsconfig.json path mappings, next.config.mjs transpilePackages, and 56 TypeScript source files with import statements. Also fixed a pre-existing bug in broadcast.tsx (wrong relative import path '../../../' instead of '../../'). Intentionally NOT renamed: Tailwind qrv-* color tokens (450+ usages, design-layer concern), i18n "QRV" text (ham radio Q-code), app.qrv.ee bundle identifiers (domain/store migration required). All builds: zero errors.
- **REASON:** Root package.json name "qrv" and @qrv/ namespace were inconsistent with the project brand "qrvee" and the GitHub repo name "qrvee".
- **IMPACT:** All internal imports now use @qrvee/shared. vendor/shared-lib updated — Cloud Build deploy pipeline unaffected. No deployed CF names or Firestore collection names changed.
- **STATUS:** COMPLETE

---

## CHANGE: TASK-020 — GitHub Repo Sync + README Standardization

- **TYPE:** CHANGE
- **SOURCE:** TASK-020
- **DESCRIPTION:** Audited and synced all 4 GitHub repos. qrvee: merged remote diverged commit (qrvee_landing.md) and pushed 8 local commits (TASK-009 through TASK-019). tinc: initialized git in workspace/tinc, updated README from stub to full architecture description, expanded ROLES.md, committed all 29 files (including RUN_LOG TASK-009 through TASK-019, DECISION_LOG, EVENT_SYSTEM_V2, AUDIT_REPORT, EVENT_FLOW_REPORT), force-pushed to GitHub. pnot: cloned, added README with TINC event consumer relation and status table. minwin: updated README from one-line stub to full vision, TINC relation, and status table.
- **REASON:** workspace/tinc had no git — 11 tasks of architecture decisions, RUN_LOGs, and event system docs existed only locally. qrvee was 8 commits behind GitHub. pnot had no README; minwin had a stub README.
- **IMPACT:** All 4 repos are now synced and documented. workspace/tinc is now a tracked git repo. No local data was lost.
- **STATUS:** COMPLETE

---

## DECISION: TASK-021 — UI Platform Architecture

- **TYPE:** DECISION
- **SOURCE:** TASK-021
- **DESCRIPTION:** Designed the modular UI platform for all QRV ecosystem apps. Created UI_PLATFORM.md defining: Dashboard/Widget/Layout/DataSource core concepts; WidgetDefinition (static registry) + WidgetInstance (per-user config) separation; WidgetContract interface (initialize/onData/render/onInteraction/destroy); WidgetContext injection model; 3-layer state architecture (Firestore → Zustand → React); event-driven update flow via TINC event system; 7 modularity rules (one-definition-many-instances, no cross-widget imports, declarative data source, platform isolation, config schema required, declarative Pro gating, central catalog). Catalogued 17 existing QRVEE widget types. Defined cross-app extension points for PNOT and MINWIN using same DashboardConfig types from @qrvee/shared.
- **REASON:** Phase 4 requires a shared UI system. Without a formal widget contract, each new tile adds bespoke logic to a 499-line monolith (dashboard.tsx) and mobile has no parity model.
- **IMPACT:** All future widget development follows the WidgetDefinition + WidgetContract model. PNOT and MINWIN can scaffold dashboards using the same @qrvee/shared types and Firestore path pattern. Implementation phases: 4B (refactor web dashboard), 4C (extract hooks), 4D (PNOT scaffold), 4E (mobile parity).
- **STATUS:** COMPLETE

---

## DECISION: TASK-022 — UI Runtime Engine Design

- **TYPE:** DECISION
- **SOURCE:** TASK-022
- **DESCRIPTION:** Designed the UI runtime engine. Created UI_ENGINE.md defining: engine's 3 responsibilities (lifecycle management, data distribution, render orchestration); 5 execution flow scenarios (app load, widget show/hide, real-time update, interaction→shell); WidgetRegistry as immutable Map with unknown-type safety and platform/Pro filtering; render loop with 16ms batching, priority tiers, skeleton→content transitions, per-widget error boundaries; 4-level isolation model (data/state/error/events); full UIEngine TypeScript interface; reference-counted SubscriptionPool for deduplication. Gap analysis against current dashboard.tsx: no registry Map, no dedup, no error boundaries, no typed events, lifecycle scattered in 499-line monolith.
- **REASON:** UI_PLATFORM.md (TASK-021) defined the platform contracts. TASK-022 defines the runtime that executes those contracts — required before Phase 4B implementation can begin.
- **IMPACT:** Phase 4B (dashboard.tsx refactor) has a clear spec. Engine API is the implementation target. Subscription dedup eliminates N duplicate Firestore listeners. Error boundaries prevent widget crashes from killing the full dashboard.
- **STATUS:** COMPLETE

---

## CHANGE: TASK-023 — UI Engine Core Implementation

- **TYPE:** CHANGE
- **SOURCE:** TASK-023
- **DESCRIPTION:** Implemented minimal UI Engine core in apps/web/src/ui-engine/. Created registry.ts (WidgetRegistry singleton, all type definitions, UNKNOWN_WIDGET fallback, forPlatform filter), subscriptionPool.ts (SubscriptionPool singleton, reference-counted acquire/release, lastData cache for late-joining widgets, destroyAll), engine.ts (UIEngine singleton, configure/registerSourceOpener/mount/unmount/unmountAll/getState/getContext/debugSummary). Created dev-only /engine-test page exercising full lifecycle: 3 widget definitions registered, mock ticker source firing every 2s, deduplication confirmed (test_ticker_0 + test_shared_0 share one interval via pool), emit/unmount buttons, debug panels. TypeScript: zero errors. Existing dashboard untouched.
- **REASON:** Phase 4B requires a working engine before dashboard.tsx can be refactored. This commit establishes the engine in isolation so it can be validated before any migration.
- **IMPACT:** UIEngine, WidgetRegistry, SubscriptionPool are importable from @/ui-engine/*. Deduplication and lifecycle management are proven working. Next step: register real QRVEE widget definitions and migrate dashboard.tsx to use the engine.
- **STATUS:** COMPLETE

---

## CHANGE: TASK-024 — UI Engine Hardening

- **TYPE:** CHANGE
- **SOURCE:** TASK-024
- **DESCRIPTION:** Added LifecycleState ('MOUNT'|'ACTIVE'|'HIDDEN'|'ERROR'|'UNMOUNT') to WidgetState. Rewrote engine.ts with full state machine: hide() releases pool subscriptions (ACTIVE→HIDDEN), show() re-acquires them (HIDDEN→ACTIVE), setError() transitions to ERROR and releases subscriptions, recover() re-opens subscriptions (ERROR→MOUNT). Created WidgetErrorBoundary.tsx (React class component, calls UIEngine.setError on componentDidCatch, Retry calls UIEngine.recover). Created useWidgetState.ts (per-widget hook filtering engine state changes) and useAllWidgetStates() (full map for shell/debug). Extended engine-test page with crash simulation, hide/show buttons, rapid event test, lifecycle badge column, full debug table. TypeScript: zero errors.
- **REASON:** TASK-023 engine had no lifecycle states, no visibility control, no error isolation, and no React integration layer — not production-ready.
- **IMPACT:** Engine is now production-ready for Phase 4B dashboard migration. Error boundaries prevent widget crashes from cascading. Visibility control enables resource savings when widgets are hidden. useWidgetState hook is the React integration point for all future widget components.
- **STATUS:** COMPLETE

---

---

## DECISION: CHATGPT-MERGE-001 — Domain Kararı

- **TYPE:** DECISION
- **SOURCE:** ChatGPT konuşma extraction
- **DESCRIPTION:** Ekosistem ana domain'i olarak tinc.ee kararlaştırılmış.
- **STATUS:** CONFIRMED — implementasyon FAZ 8'de

---

## DECISION: FAZ-01-KEŞIF — Mevcut Servisler Tespit Edildi

- **TYPE:** SNAPSHOT
- **DATE:** 2026-04-06
- **DESCRIPTION:** Yeni PC'de mevcut çalışan servisler tespit edildi:
  n8n (5678), Memos (5230), Immich (2283).
  Memos = self-hosted not uygulaması. PNOT için FAZ 4'te değerlendirilecek:
  sıfırdan yazmak yerine Memos'u TINC event sistemine bağlama seçeneği.
  Immich = fotoğraf yönetimi. Cloudinary alternatifi olarak FAZ 5+'da değerlendirilir.
- **STATUS:** NOTED

---

## SNAPSHOT: FAZ-02 — QRVEE İç Yapı Denetimi

- **TYPE:** SNAPSHOT
- **DATE:** 2026-04-06
- **DESCRIPTION:** QRVEE reposunun tam iç denetimi yapıldı. Kritik bulgular:
  1. UIEngine (WidgetRegistry, SubscriptionPool, LifecycleState): TINC ZIP'teki 
     DECISION_LOG'da TASK-023/024 tamamlandı denmesine rağmen QRVEE repo'sunda 
     KOD YOK. Büyük ihtimalle eski PC'de local kalmış, push edilmemiş.
  2. Game System (FlowWidget, RF oyunları, XP/Level/Badge/Quest/Ghost/Challenge): 
     Aynı durum. Spec var, kod yok. NOT: useGameStore XP/Level/Mood/Streak sistemi
     TAM implement edilmiş ve çalışıyor.
  3. pnot-client.ts: Direkt API çağrısı yapıyor. LAW-005 ihlali. FAZ-03'te 
     devre dışı bırakıldı.
  4. Spec dışı başlangıçlar: modem/afsk.ts (tam APRS encoder), modem/ax25.ts, 
     rig/yaesu897.ts (ESP32 CAT bridge), SDRWaterfall.tsx — Müteahhit kararı bekliyor.
  5. YLRL sayfası ve kiosk modu: Spec'te yok.
  6. Event system, auth, offline stack: SAĞLIKLI.
  7. Dashboard: 499 satır (1200+ değil) — tile'lar inline ama yönetilebilir.
- **IMPACT:** UIEngine ve flow engine sıfırdan implement edilecek. 
  Spec dosyaları (TINC ZIP) mevcut — kodlar ondan yazılacak.
  useGameStore zaten hazır — üzerine inşa edilecek.
- **STATUS:** COMPLETE


---

## DECISION: FAZ-04-001 — PNOT Standalone Geçiş Başlatıldı

- **TYPE:** CHANGE
- **DATE:** 2026-04-06
- **DESCRIPTION:** PNOT'un kendi Firebase Functions altyapısı oluşturuldu.
  pnot repo içinde firebase/functions/src/ yapısı kuruldu.
  Types, handler (qrveeEvents.ts), index.ts yazıldı.
  NOT: PNOT'un mevcut index.ts zaten tam dolu (invite, XP, classroom, trial, webhook CF'ları).
  Yeni TINC event consumer handler'ları ayrı dosyaya (events/handlers/qrveeEvents.ts) eklendi.
  handlePnot hala qrvee'de — tam geçiş FAZ-05'te tamamlanacak.
- **STATUS:** COMPLETE (geçiş devam ediyor)

---

## DECISION: FAZ-04-002 — RigConnect Resmi Özellik

- **TYPE:** DECISION
- **DATE:** 2026-04-06
- **DESCRIPTION:** lib/modem/afsk.ts, ax25.ts, lib/rig/protocol.ts, yaesu897.ts,
  components/sdr/SDRWaterfall.tsx — spec dışı başlamış dosyalar onaylandı.
  MASTER_SPEC'e RigConnect bölümü eklendi. RF NETWORK FAZ 9+ ile entegre edilecek.
- **STATUS:** COMPLETE

---

## DECISION: FAZ-04-003 — UIEngine Ertelendi

- **TYPE:** DECISION
- **DATE:** 2026-04-06
- **DESCRIPTION:** Tam UIEngine refaktoru ertelendi. Dashboard 499 satır,
  temiz yapıda, çalışıyor. WidgetErrorBoundary eklenerek minimum güvenlik sağlandı.
  Tam UIEngine: PNOT/OPS cross-app widget ihtiyacı doğduğunda yapılacak.
- **STATUS:** COMPLETE


---

## CHANGE: FAZ-05 — Game System Rebuild Phase 1

- **TYPE:** CHANGE
- **DATE:** 2026-04-06
- **DESCRIPTION:** Game system sıfırdan yeniden implement edildi.
  Kaynak: TINC ZIP DECISION_LOG spec (TASK-057, 059, 061).
  Oluşturulan: LevelSystem.ts, GameXPEngine.ts, useGameXPStore.ts,
  useGameScoreStore.ts, useGhostStore.ts, useChallengeStore.ts,
  RfSignalTuneGame.tsx, GameRegistry.ts, useGameLauncherStore.ts,
  GameLauncher.tsx, XPToast.tsx, LevelUpOverlay.tsx.
  RF Propagation ve RF World: placeholder — FAZ-06'da implement edilecek.
  TypeScript: sıfır hata.
- **STATUS:** COMPLETE (Phase 1)
