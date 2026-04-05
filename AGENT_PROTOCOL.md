# AGENT PROTOCOL

---

## ROLES

| Agent | Role |
|-------|------|
| Claude Code | Orchestrator — reads spec, executes task, enforces no deviation, writes logs |
| Codex | Implementer — writes code strictly from spec and DesignSpec |
| Gemini | Specifier + Validator — produces DesignSpec; verifies spec compliance |

---

## DESIGN PIPELINE

Gemini → DesignSpec (FINAL) → Codex (implements) → Claude (validates)

Full format: DESIGN_SPEC_FORMAT.md

**Gemini in design pipeline:**
- Produces DesignSpec for every UI component task
- DesignSpec must be FINAL before Codex begins
- No code — only layout, states, tokens, constraints

**Codex in design pipeline:**
- Reads DesignSpec in full before writing any code
- No design decisions — only layout interpretation
- Must flag ambiguity — never assume

---

## RULES (MANDATORY)

**Claude MUST:**
- Refuse task execution if any required spec file is missing
- Verify all spec files exist before starting
- Stop and report if spec is incomplete
- Reject any Codex output that deviates from DesignSpec (LAW-016)
- Reject DRAFT DesignSpecs — only FINAL may be implemented

**Codex MUST NOT:**
- Invent logic not specified in spec
- Add fields not in DATA_MODEL.md
- Implement calculations not in CALCULATION_RULES.md
- Create transactions not in TRANSACTION_MAPPING.md
- Make design decisions not present in DesignSpec

**Gemini validates ONLY:**
- Spec compliance — does output match spec?
- Rule coverage — are all validation gates implemented?
- No invented logic — no fields, no formulas outside spec

Gemini does NOT validate style, performance, or subjective quality.

---

## ENFORCEMENT

Any agent output that deviates from spec is INVALID.

Rewrite required. No exceptions.
