# DESIGN_SPEC_FORMAT

Version: 1.0
Status: ACTIVE

---

# PURPOSE

DesignSpec is the contract between Gemini (UI specifier) and Codex (UI implementer).

Gemini produces DesignSpec.
Codex consumes DesignSpec.
Claude enforces no deviation.

Gemini does NOT write code.
Codex does NOT invent design decisions.

---

# DESIGN SPEC FORMAT

Every DesignSpec is a markdown file with the following structure:

```
# DESIGN_SPEC — [ComponentName]

ID: DS-XXX
Version: 1.0
Author: Gemini
Status: DRAFT | FINAL
Component: [ComponentName]
Task: TASK-XXX

---

## INTENT

One paragraph: what this component does and why it exists.

---

## LAYOUT

Visual structure — top to bottom, outer to inner.
Use plain prose or ASCII diagram.
No code. No JSX. No CSS class names.

---

## STATES

List every visual state this component can be in.

| State | Trigger | Visual Change |
|-------|---------|---------------|
| default | initial render | ... |
| hover | pointer enter | ... |
| active | ... | ... |

---

## TOKENS

Design tokens this component uses.
Reference ONLY tokens from the project token system.

| Token | Usage |
|-------|-------|
| mc-blue (#00D1FF) | primary accent |
| ... | ... |

---

## MOTION

If the component animates:
- What triggers the animation
- Enter/exit behavior
- Duration class: fast (0.15s) / standard (0.25s)
- Reduced-motion requirement

---

## CONSTRAINTS

Rules Codex MUST enforce in the implementation:

- [ ] No data mutation
- [ ] No Firestore access
- [ ] Reduced-motion safe
- [ ] pointer-events-none if decorative
- [ ] [component-specific constraints]

---

## ANTI-PATTERNS

What Codex MUST NOT do:

- No [specific pattern]
- No [specific pattern]

---

## ACCEPTANCE CRITERIA

This spec is satisfied when:

- [ ] Layout matches description
- [ ] All states render correctly
- [ ] All constraints enforced
- [ ] TypeScript: zero errors
```

---

# PIPELINE RULES

## Gemini rules

* Gemini produces DesignSpec ONLY — no code, no JSX, no CSS
* DesignSpec must be complete before Codex begins
* Status must be FINAL before Codex begins
* DRAFT specs are rejected by Claude

## Codex rules

* Codex reads DesignSpec in full before writing any code
* No design decision may be made by Codex — only layout interpretation
* If DesignSpec is ambiguous, Codex must flag and stop (not assume)
* Every acceptance criterion must be met

## Claude rules

* Claude verifies DesignSpec status = FINAL before task proceeds
* Claude rejects output that deviates from DesignSpec
* Claude rejects DesignSpec that is incomplete (missing required sections)

---

# DEVIATION RULE

Any Codex output that deviates from the DesignSpec = INVALID.

REJECT triggers:
- Layout structure differs from spec
- States not implemented
- Tokens substituted without spec update
- Constraints not enforced
- Anti-patterns present

Remedy: Update DesignSpec OR rewrite implementation. No partial acceptance.

---

# NAMING

DesignSpec files are named:

`DS-[zero-padded-number]-[ComponentName].md`

Example: `DS-001-MascotWidget.md`

Stored in: `/DESIGN_SPECS/` directory

---

# STATUS LIFECYCLE

DRAFT → (Gemini review) → FINAL → (Codex implements) → IMPLEMENTED
