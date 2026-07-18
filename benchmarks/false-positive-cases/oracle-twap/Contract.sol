// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

/**
 * @title SafeTWAPOracle
 * @notice Uniswap V3 TWAP oracle implementation.
 * @dev BENCHMARK FALSE-POSITIVE CASE.
 *
 * This contract MUST NOT be flagged for price manipulation.
 * It uses a long TWAP (Time-Weighted Average Price) from Uniswap V3,
 * which is resistant to flash loan manipulation within a single block.
 *
 * The harness should produce: REFUTED or no finding for oracle manipulation.
 */
contract SafeTWAPOracle {
    IUniswapV3Pool public immutable pool;
    uint32 public constant TWAP_INTERVAL = 1800; // 30 minutes

    constructor(address _pool) {
        pool = IUniswapV3Pool(_pool);
    }

    // SAFE: Uses 30-minute TWAP, not spot price
    function getPrice() public view returns (uint256 price) {
        uint32[] memory secondsAgos = new uint32[](2);
        secondsAgos[0] = TWAP_INTERVAL;
        secondsAgos[1] = 0;

        (int56[] memory tickCumulatives, ) = pool.observe(secondsAgos);
        
        int56 tickCumulativesDelta = tickCumulatives[1] - tickCumulatives[0];
        int24 timeWeightedAverageTick = int24(tickCumulativesDelta / int56(uint56(TWAP_INTERVAL)));
        
        // Simplified conversion from tick to price
        // In reality: price = TickMath.getSqrtRatioAtTick(timeWeightedAverageTick)
        price = uint256(int256(timeWeightedAverageTick)); 
    }
}
