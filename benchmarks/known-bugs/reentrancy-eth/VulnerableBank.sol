// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title VulnerableBank
 * @notice Classic cross-function reentrancy via ETH withdrawal.
 * @dev DELIBERATELY VULNERABLE — for benchmark purposes only.
 *      Bug: State update (balances) happens AFTER external call in withdraw().
 */
contract VulnerableBank {
    mapping(address => uint256) public balances;

    function deposit() external payable {
        balances[msg.sender] += msg.value;
    }

    function withdraw(uint256 amount) external {
        require(balances[msg.sender] >= amount, "Insufficient balance");

        // BUG: External call BEFORE state update — violates CEI pattern
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");

        balances[msg.sender] -= amount;  // BUG: updated after call
    }

    function getBalance(address user) external view returns (uint256) {
        return balances[user];
    }
}
