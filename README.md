# TINC — The Integration & Notification Core

**Status:** Active — Phase 3
**Role:** Core architecture, event bus, and decision log for the QRV ecosystem

---

## What is TINC?

TINC is the top-level system owner of the QRV ecosystem. It is not an app — it is the architecture and event infrastructure layer that connects all apps:

- **QRVEE** — Amateur radio activity platform (event producer)
- **PNOT** — Project notebook and notification service (event consumer)
- **MINWIN** — Reverse-auction marketplace (future consumer)

TINC defines the event contract, processing rules, retry policies, and cross-app data flow. All apps produce or consume events through the TINC event bus (Firestore-based, Cloud Functions-driven).

---

## Event System V2

The canonical event system design lives in this repository:

- `EVENT_SYSTEM_V2.md` — Full specification (v2.3)
- `EVENT_SYSTEM_CURRENT.md` — Baseline audit (TASK-003)
- `EVENT_FLOW_REPORT.md` — Live validation report (TASK-016/017)
- `DECISION_LOG.md` — Append-only record of all architectural decisions (TASK-001 → present)
- `RUN_LOG/` — Execution trace for every task in the pipeline

---

## Repository Structure

```
tinc/
├── DECISION_LOG.md          ← Append-only architecture decisions
├── EVENT_SYSTEM_V2.md       ← Event system specification
├── EVENT_SYSTEM_CURRENT.md  ← V1 audit baseline
├── EVENT_FLOW_REPORT.md     ← Live validation
├── AUDIT_REPORT_TASK-014.md ← Phase 2 architectural audit
├── ARCHITECTURE.md          ← System architecture overview
├── MASTER_GUIDE.md          ← Full developer guide
├── ROADMAP.md               ← Planned phases and milestones
├── RULES.md                 ← Development laws and constraints
├── ROLES.md                 ← AI/team role definitions
├── RUN_LOG/                 ← Per-task execution logs (TASK-009+)
└── TINC_SUPER_GUIDE.pdf     ← Comprehensive reference document
```

---

## Relation to Other Repos

| Repo | Relation |
|------|----------|
| [qrvee](https://github.com/mcturan/qrvee) | Primary event producer; implements writeQrveeEvent(), hosts Cloud Functions |
| [pnot](https://github.com/mcturan/pnot) | Event consumer; receives session/QSO events, creates pnot_notes |
| [minwin](https://github.com/mcturan/minwin) | Future event consumer; marketplace integration planned |

---

## Current Phase

**Phase 3** — Production hardening
- Event system live and validated end-to-end (TASK-017)
- Firestore security rules hardened (TASK-018)
- Package naming standardized (TASK-019)
- GitHub repos synced (TASK-020)
