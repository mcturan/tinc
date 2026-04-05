# RULES

---

## LAW-001 — DOUBLE ENTRY (MANDATORY)
Every transaction must produce balanced ledger entries. SUM(amounts) == 0.

## LAW-002 — IMMUTABILITY
No edits to ledger entries. Corrections use reversing entries only.

## LAW-003 — NO INVENTED FIELDS
Only fields defined in DATA_MODEL.md may be used.

## LAW-004 — NO DIRECT APP CALLS
Apps communicate only through the event system. No direct API calls between apps.

## LAW-005 — OFFLINE FIRST
System must function without network. Firebase = transport only, not source of truth.

## LAW-006 — VALIDATION GATES
All validation rules in VALIDATION_RULES.md must be enforced. No gate may be skipped.

## LAW-007 — CALCULATION SPEC
All fee calculations must follow CALCULATION_RULES.md exactly. No custom formulas.

## LAW-008 — EVENT CONTRACTS
All events must conform to EVENT_CONTRACTS.md structure. No extra fields, no missing fields.

## LAW-009 — ENFORCEMENT
Any rule violation = REJECT. No partial acceptance. Rewrite required.

## LAW-010 — NO TASK WITHOUT FULL SPEC

**NO task may execute without presenting the full spec context.**

Required files for every task:
- MASTER_SPEC.md
- LEDGER_RULES.md
- TRANSACTION_MAPPING.md
- DATA_MODEL.md
- EVENT_CONTRACTS.md
- CALCULATION_RULES.md
- VALIDATION_RULES.md
- ENFORCEMENT.md

**If any file is missing → STOP EXECUTION. No exceptions.**

## LAW-016 — NO DEVIATION FROM DESIGN SPEC

**Codex MUST NOT deviate from a FINAL DesignSpec.**

- Every UI component with a DesignSpec must be implemented to that spec exactly
- Layout, states, tokens, and constraints are binding — not suggestions
- If DesignSpec is ambiguous: flag and stop. Never assume.
- Deviation triggers REJECTION (LAW-009)

Full format: DESIGN_SPEC_FORMAT.md

## LAW-015 — GAME SYSTEM MUST REMAIN NON-INTRUSIVE AND OPTIONAL

The game system must never become mandatory, blocking, or intrusive.
- All game features are opt-in only
- Game components must not affect core system performance or state
- Disabling the game layer must leave the system fully functional
- No XP, mascot, or game event may trigger without user consent
