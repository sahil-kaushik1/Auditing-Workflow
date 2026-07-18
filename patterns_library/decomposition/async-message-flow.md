# Pattern: Async / Message Flow Decomposition

## Purpose
Analyze asynchronous and callback-based interactions that introduce timing,
ordering, and re-entry risks.

## Protocol

### 1. Identify Async Patterns
- Flash loan callbacks (`onFlashLoan`, `executeOperation`)
- ERC-777 token hooks (`tokensReceived`, `tokensToSend`)
- Cross-chain messages (bridges, LayerZero, CCIP)
- Timelock delayed execution (`queueTransaction`, `executeTransaction`)
- Multicall patterns

### 2. For Each Async Interaction
- What state is the contract in when the callback fires?
- Can the callback re-enter the calling contract?
- What happens if the callback reverts?
- What happens if the callback consumes all remaining gas?
- Is there retry/idempotency logic?

### 3. Risks
- Reentrancy through callbacks
- State inconsistency during cross-chain message delays
- Failed callback leaving protocol in partially-updated state
- Gas griefing through callback gas consumption
