# Pattern: State Machine Flow

## Purpose
Verify that multi-step state transitions across contracts complete correctly,
avoiding stuck states or illegal transitions.

## Key Checks

1. **No stuck states**: Every reachable state has at least one outgoing transition
   (or is a valid terminal state)
2. **No illegal skips**: Required intermediate states cannot be bypassed
3. **Atomic transitions**: Multi-step transitions either complete fully or
   revert cleanly
4. **Race safety**: Concurrent users cannot cause conflicting transitions
5. **Emergency exits**: Every non-terminal state has an emergency path
   (governance, timelock) to a safe state
