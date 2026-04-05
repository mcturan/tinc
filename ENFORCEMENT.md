# ENFORCEMENT

Any deviation from spec = REJECT.

---

## REJECTION TRIGGERS

Output is INVALID if:

* **spec deviation** — logic does not match MASTER_SPEC.md or any sub-spec
* **invented fields** — fields not defined in DATA_MODEL.md
* **missing constraints** — any validation gate from VALIDATION_RULES.md is absent
* **ledger imbalance** — SUM(entries) ≠ 0
* **wrong mapping** — transaction entries don't match TRANSACTION_MAPPING.md
* **missing spec** — task executed without full spec context (LAW-010)

---

## ON REJECTION

1. Output is discarded entirely — no partial acceptance
2. Rewrite required from spec
3. No exceptions, no workarounds
