# Pattern: Data Flow Decomposition

## Purpose
Track how user-controlled data flows from entry points (sources) through
computation to state changes (sinks).

## Protocol

### 1. Identify Sources
- External function parameters
- `msg.sender`, `msg.value`, `block.timestamp`
- Return values from external calls (oracles, tokens)

### 2. Identify Sinks
- State variable updates (`balances[x] = y`)
- External calls with value (`call{value: amount}`)
- Token transfers
- Event emissions with computed values

### 3. Trace Each Source → Sink Path
For each source, follow the data through:
- Arithmetic operations (potential overflow/precision loss)
- Conditional branches (can the attacker control which branch executes?)
- Internal function calls (does data flow to another contract?)
- Storage reads (is the result combined with attacker input?)

### 4. Document Sanitization Points
Where is user input validated?
- `require(amount > 0)` — lower bound
- `require(amount <= balance)` — upper bound
- Slippage checks — price deviation bounds
- Is sanitization sufficient for all sinks it reaches?
