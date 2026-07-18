# Pattern: Differential Testing

## Purpose
Compare two implementations of the same logic to find behavioral discrepancies.

## When to Use
- Comparing V1 vs V2 of an upgraded contract
- Comparing Solidity implementation vs specification
- Comparing different branches or forks

## Protocol

```solidity
function testDiff_compareImplementations(uint256 input) public {
    input = bound(input, 1, 1e24);

    uint256 resultV1 = contractV1.calculate(input);
    uint256 resultV2 = contractV2.calculate(input);

    assertEq(resultV1, resultV2, "Behavioral difference detected");
}
```

## When Differences Are Found
A difference is not automatically a bug. Evaluate:
- Is the V2 behavior intentionally different?
- Does the difference affect security-critical properties?
- Can the difference be exploited (e.g., by exploiting the transition period)?
