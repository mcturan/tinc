# GAME_SYSTEM_MASTER.md

STATUS: IN_PROGRESS
PRIORITY: POST-CORE (after TASK-052+ stabilization)

---

# PURPOSE

Define full Game & Engagement System for TINC ecosystem.

This system is NOT entertainment-only.

It is:

* retention engine
* emotional layer
* cognitive engagement system

---

# CORE PRINCIPLE

Game system MUST:

* never interrupt critical workflow
* never degrade professional experience
* always remain optional
* always feel natural

---

# SYSTEM LAYERS

## 1. CORE SYSTEM (EXISTING)

* Flow Engine
* Dashboard
* WorkItem system

---

## 2. ENGAGEMENT LAYER

* Mascot system
* XP system
* Behavioral triggers

---

## 3. GAME LAYER

* Hook games (fast)
* Intelligence games (deep)

---

# GLOBAL RULES

* NO forced interaction
* NO spam notifications
* NO addictive dark patterns
* NO meaningless rewards

Violation = SYSTEM FAILURE

---

# NOTIFICATION ENGINE

## MODES

* OFF
* MINIMAL (default)
* NORMAL

---

## RULES

* no popup on active work
* no sound by default
* context-aware only

---

## CONTEXT DETECTION

System must detect:

* active usage → silent
* idle → suggest
* long idle → gentle nudge

---

## USER CONTROL

User can configure:

* time window
* intensity
* mute

---

# MASCOT ENGINE

## DEFINITION

Mascot = Stateful behavioral entity

---

## STATES

* idle
* bored
* engaged
* excited
* tired

---

## TRANSITIONS

* inactivity → bored
* productivity → happy
* repeated failure → reacts
* long idle → suggests activity

---

## BEHAVIOR RULES

* speaks rarely
* speaks briefly
* speaks contextually

---

# XP SYSTEM

## PURPOSE

* reinforce meaningful behavior
* show progression

---

## RULES

* no spam XP
* no passive farming
* must require action

---

## SOURCES

* task completion
* game completion
* problem solving

---

# GAME TYPES

## TYPE A — HOOK GAMES

Characteristics:

* 10–60 seconds
* instant start
* low complexity

Examples:

* runner
* reflex match
* micro puzzles

---

## TYPE B — INTELLIGENCE GAMES

Characteristics:

* problem solving
* learning-based
* deeper engagement

Examples:

* RF simulation (QRVEE)
* dependency solver (PNOT)
* decision optimization

---

# GAME ENGINE RULES

* NO direct database access
* NO core data mutation
* ONLY ViewModel usage
* communication via events only

---

# FLOW INTEGRATION

Game system may:

* read system state
* adapt difficulty

Game system must NOT:

* modify system state directly

---

# INTERACTION FLOW

Example:

1. user idle
2. mascot detects boredom
3. suggests game (non-intrusive)
4. user accepts
5. game runs instantly
6. reward applied
7. mascot state updated

---

# LIBRARY SYSTEM (PNOT)

Environment-based micro game system

---

## MODULES

### Book Hunt

* find correct book quickly

### Misplaced Books

* fix wrong placements

### Memory Shelf

* recall arrangement

### Whisper Search

* hint-based discovery

### Knowledge Match

* topic matching

---

# RF SIMULATION (QRVEE)

## OBJECTIVE

Reach target location via signal

---

## PARAMETERS

* frequency
* power
* antenna type
* environment
* time

---

## OUTPUT

* success / failure
* signal strength
* feedback

---

## RULE

Playable realism, not scientific overload

---

# UI PRINCIPLES

* instant start (no loading perception)
* smooth transitions
* minimal interface
* high-quality motion

---

# ANTI-CRINGE RULES

* no excessive animation
* no childish tone
* no forced humor
* no visual clutter

---

# PERFORMANCE RULES

* must not affect dashboard performance
* must be lazy-loaded
* must support low-end devices

---

# SUCCESS METRICS

* return rate
* voluntary engagement
* session revisit

NOT:

* time spent blindly

---

# ROADMAP

[ ] notification engine
[ ] mascot state engine
[ ] first hook game
[ ] first intelligence game
[ ] xp system integration
[ ] system ↔ game feedback loop

---

# FINAL RULE

Game system must feel like:

"it belongs here"

NOT:

"this was added later"

