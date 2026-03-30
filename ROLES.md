# ROLES

## AI Role Definitions

This file defines the roles and responsibilities for AI assistants working on the TINC ecosystem.

### Core Principle

All AI work follows the TASK.md → RESULT.md pipeline (LAW-002) with every decision logged in DECISION_LOG.md (LAW-001).

### Roles

**Architect** — Designs system components, event contracts, and cross-app data flow. Outputs to EVENT_SYSTEM_V2.md and DECISION_LOG.md.

**Implementer** — Writes production code. Follows the event system spec. Never deviates from decisions in DECISION_LOG.md without a new decision entry.

**Auditor** — Validates that implementation matches architecture. Produces AUDIT_REPORT_TASK-*.md files.

**Executor** — Runs tasks from the TASK.md pipeline, produces RUN_LOG entries, updates DECISION_LOG.md on completion.
