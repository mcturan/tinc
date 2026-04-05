# ROADMAP

---

## CORE SYSTEM (IN PROGRESS)

- [x] Foundation — spec system, LAW system, decision log
- [x] Data model — WorkItem, ledger, event contracts
- [x] Flow engine — buildFlowViewModel, FlowWidget, virtual list
- [x] UI motion layer — framer-motion, system reactions, global pulse
- [ ] Notification engine
- [ ] Full audit pipeline
- [ ] Load testing + production hardening

---

## GAME LAYER (POST-CORE)

The game layer is a phased, non-mandatory engagement system. It is built only after core system stability is confirmed.

### Engagement Layer

- Passive awareness of operator activity (via FlowViewModel)
- XP events triggered only by real operator actions (no spam XP)
- Opt-in activation — game layer is invisible unless enabled

### Mascot System

- Mascot reflects system state: idle / bored / engaged / excited / tired
- State derived from FlowViewModel energy level (useFlowAwarenessStore)
- Non-blocking, non-intrusive overlay
- Reduced-motion safe

### Hook Games

- Short-form games: 10–60 seconds
- Triggered during idle moments (low system energy)
- Examples: antenna alignment, frequency tuning, signal decoding
- No interference with active tasks

### Intelligence Games

- Long-form, simulation-based games
- QRVEE: RF propagation simulation, real call sign data
- PNOT: dependency chain solving, task scheduling puzzles
- Require explicit user initiation

### XP System Integration

- XP earned from: completing WorkItems, chain completions, game events
- XP visible in operator profile
- No XP for passive activity
- XP decay if system idle for extended period

### Phased Rollout

| Phase | Deliverable |
|-------|-------------|
| G-1 | Notification engine |
| G-2 | Mascot engine (idle/engaged/excited states) |
| G-3 | First hook game (signal tuning) |
| G-4 | First intelligence game (RF simulation) |
| G-5 | XP system + operator profile integration |
| G-6 | Game ↔ system feedback loop complete |

---

## CONSTRAINTS

All game layer work is governed by:
- LAW-015: Game system must remain non-intrusive and optional
- GAME_SYSTEM_MASTER.md: Full game architecture spec
- GAME_SYSTEM_INTENT.md: Design philosophy and anti-patterns
