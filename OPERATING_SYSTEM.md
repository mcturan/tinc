# OPERATING SYSTEM

---

## EXECUTION MODEL (MANDATORY)

All tasks require full spec context.

TASK-only execution is invalid.

```
SPEC + RULES + TASK → RESULT
```

Required spec files must exist before any task begins.

If any spec file is missing → STOP EXECUTION.

---

## SPEC HIERARCHY

```
MASTER_SPEC.md          ← entry point
  ├── LEDGER_RULES.md
  ├── TRANSACTION_MAPPING.md
  ├── DATA_MODEL.md
  ├── EVENT_CONTRACTS.md
  ├── CALCULATION_RULES.md
  ├── VALIDATION_RULES.md
  └── ENFORCEMENT.md
```

---

## TASK PIPELINE

```
TASK.md + SPEC → EXECUTION → RESULT.md + RUN_LOG + DECISION_LOG
```

No step may be skipped.
