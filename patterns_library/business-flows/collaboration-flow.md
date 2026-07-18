# Pattern: Collaboration Flow

## Purpose
Analyze multi-user, multi-transaction operations that require coordination.

## Key Checks

1. **Fair ordering**: Can one user front-run another for profit?
2. **Atomic batches**: If a batch operation fails midway, is state consistent?
3. **Concurrent safety**: Can two users perform the same operation simultaneously
   without conflict?
4. **Recovery**: If a multi-step collaborative flow stalls, can participants
   recover their assets?
5. **Griefing resistance**: Can a malicious participant harm others without
   cost to themselves?

## Examples
- Liquidity provision + removal in AMMs
- Governance proposal + voting + execution
- Auction bidding + settlement
- Multi-sig transaction approval
