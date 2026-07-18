# Pattern: Configuration / Deployment Decomposition

## Purpose
Analyze how deployment parameters, proxy patterns, and configuration settings
affect security.

## Protocol

### 1. Proxy & Upgrade Analysis
- Proxy type (UUPS, Transparent, Beacon, Diamond)
- Who can upgrade? (admin, governance, timelock)
- Storage gap presence for future upgrades
- Implementation initialization protection

### 2. Constructor / Initializer Parameters
- What addresses are hardcoded at deployment?
- Can critical addresses be changed after deployment?
- Are oracle addresses, fee parameters, or token addresses immutable?

### 3. Feature Flags & Parameters
- Pausing mechanisms
- Fee parameters (who sets them, are they bounded?)
- Whitelists / blacklists
- Rate limits / cooldowns

### 4. Network-Specific Risks
- Different chain IDs, block times, gas limits
- Precompile availability
- Token behavior differences (USDT approval, rebasing tokens)
