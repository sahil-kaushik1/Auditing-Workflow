// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title VulnerablePool
 * @notice An AMM-like pool with a read-only reentrancy vulnerability.
 * @dev BENCHMARK CONTRACT — DO NOT USE IN PRODUCTION.
 *
 * Known vulnerability: Read-only reentrancy.
 * The `removeLiquidity` function sends ETH before updating `totalSupply`.
 * While `removeLiquidity` is protected by `nonReentrant` (so cross-function
 * state-mutating reentrancy is prevented), the state is temporarily inconsistent.
 * A separate contract can read the inflated `price()` during the fallback
 * to perform a malicious action.
 */
contract VulnerablePool {
    uint256 public totalEth;
    uint256 public totalSupply;
    mapping(address => uint256) public balances;
    
    bool private locked;
    
    modifier nonReentrant() {
        require(!locked, "ReentrancyGuard: reentrant call");
        locked = true;
        _;
        locked = false;
    }

    // A getter that depends on totalSupply
    function price() public view returns (uint256) {
        if (totalSupply == 0) return 0;
        return (totalEth * 1e18) / totalSupply;
    }

    function addLiquidity() external payable {
        uint256 shares = msg.value; // simplified
        totalEth += msg.value;
        totalSupply += shares;
        balances[msg.sender] += shares;
    }

    // VULNERABLE: State updated after external call.
    // Guard protects against direct reentrancy, but NOT read-only reentrancy.
    function removeLiquidity(uint256 shares) external nonReentrant {
        require(balances[msg.sender] >= shares, "Insufficient shares");
        
        uint256 ethAmount = (shares * totalEth) / totalSupply;
        
        balances[msg.sender] -= shares;
        totalEth -= ethAmount;
        
        // INTERACTION
        (bool success, ) = msg.sender.call{value: ethAmount}("");
        require(success, "Transfer failed");

        // EFFECT after interaction: totalSupply is still artificially high during the call
        totalSupply -= shares;
    }
}
