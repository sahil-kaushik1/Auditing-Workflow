// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface AggregatorV3Interface {
    function latestRoundData() external view returns (
        uint80 roundId, int256 answer, uint256 startedAt,
        uint256 updatedAt, uint80 answeredInRound
    );
}

/**
 * @title VulnerableLending
 * @notice Lending protocol using Chainlink oracle WITHOUT staleness check.
 * @dev BENCHMARK CONTRACT — DO NOT USE IN PRODUCTION.
 *
 * Known vulnerability: Stale oracle price used for collateral valuation.
 * If the Chainlink feed stops updating (sequencer down, oracle malfunction),
 * the protocol continues to accept collateral at the last known price,
 * allowing users to borrow against stale/incorrect valuations.
 *
 * Root cause: latestRoundData() result is used without checking updatedAt.
 */
contract VulnerableLending {
    AggregatorV3Interface public immutable priceFeed;
    uint256 public constant COLLATERAL_RATIO = 150; // 150% collateralization
    uint256 public constant DECIMALS = 1e18;

    mapping(address => uint256) public collateral; // in ETH wei
    mapping(address => uint256) public debt;       // in USD * 1e8

    constructor(address _priceFeed) {
        priceFeed = AggregatorV3Interface(_priceFeed);
    }

    // VULNERABLE: no staleness check on oracle result
    function getEthPrice() public view returns (uint256) {
        (, int256 price, , , ) = priceFeed.latestRoundData();
        // Missing: require(updatedAt >= block.timestamp - MAX_STALENESS, "stale");
        // Missing: require(answeredInRound >= roundId, "stale round");
        require(price > 0, "invalid price");
        return uint256(price); // 8 decimals
    }

    function depositCollateral() external payable {
        collateral[msg.sender] += msg.value;
    }

    // VULNERABLE: borrows against potentially stale collateral value
    function borrow(uint256 usdAmount) external {
        uint256 ethPrice = getEthPrice(); // may be stale
        uint256 collateralValueUsd = (collateral[msg.sender] * ethPrice) / DECIMALS;
        uint256 maxBorrow = (collateralValueUsd * 100) / COLLATERAL_RATIO;
        require(debt[msg.sender] + usdAmount <= maxBorrow, "undercollateralized");
        debt[msg.sender] += usdAmount;
        // transfer USD stablecoin to borrower (simplified)
    }

    function healthFactor(address user) public view returns (uint256) {
        if (debt[user] == 0) return type(uint256).max;
        uint256 ethPrice = getEthPrice();
        uint256 collateralValue = (collateral[user] * ethPrice) / DECIMALS;
        return (collateralValue * 100) / debt[user];
    }
}
