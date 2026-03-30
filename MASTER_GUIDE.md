# TINC MASTER GUIDE (FULL)

## USER CONTEXT
- System built via CLI on Pardus Linux
- Uses Codex CLI, Claude Code, Gemini CLI
- AI agents used as execution layer
- ChatGPT = orchestrator

## SYSTEM VISION
TINC is the core platform.
Apps: QRVEE, PNOT, MINWIN (and future apps)
All apps independent.

## KEY DECISION
Event-based architecture is mandatory.

## CURRENT REALITY
- QRVEE: highly advanced, includes offline sync system
- PNOT: full note/project/task system (Firestore subcollections)
- MINWIN: concept + partially inside QRVEE
- TINC: not implemented yet

## CRITICAL CORRECTION
QRVEE is NOT core.
TINC will be core.

## DATA FLOW
QRVEE → Firebase events → PNOT → notes

## FIREBASE STRUCTURE
- users (central, TINC)
- events_qrvee
- events_pnot
- events_minwin

## EVENT MODEL
Fields:
- type
- userId
- sourceApp
- targetApps
- payload
- clientTime
- serverTime
- processedBy

## OFFLINE RULE
- local-first writes
- Firebase = sync only

## RISKS
- QRVEE becoming core accidentally
- duplicate processing
- multi-device conflicts
- event growth

## SOLUTIONS
- processedBy + sourceEventId
- userId filtering
- separate collections

## DEVELOPMENT MODEL
- task driven
- minimal implementation
- validate → expand

## PHASE PLAN
Phase 1: QRVEE → PNOT working
Phase 2: stability
Phase 3: TINC core
Phase 4: UI
Phase 5: production

## SYSTEM CONTROL
- AI agents execute only
- orchestrator decides
- risky changes require discussion

