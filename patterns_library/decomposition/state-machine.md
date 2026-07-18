# Pattern: State Machine Decomposition

## Purpose
Map legal and illegal state transitions. Identify stuck states and
impossible states.

## Protocol

### 1. Identify State Variables
Enums, booleans (paused/active), phase counters, status fields.

### 2. Build Transition Table

| From | To | Trigger | Guard | Who |
|------|----|---------|-------|-----|
| Active | Paused | `pause()` | onlyOwner | Admin |
| Paused | Active | `unpause()` | onlyOwner | Admin |
| Open | Closed | `close()` | block.timestamp > deadline | Anyone |

### 3. Check for Risks
- **Stuck state**: Is there a state with no outgoing transition?
- **Skip state**: Can an attacker skip required intermediate states?
- **Conflicting transitions**: Can two users trigger incompatible transitions?
