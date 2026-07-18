// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title VulnerableToken
 * @notice Token contract with a classic cross-function reentrancy vulnerability.
 * @dev BENCHMARK CONTRACT — DO NOT USE IN PRODUCTION.
 *
 * Known vulnerability: Cross-function reentrancy between withdraw() and transfer().
 * State (balance) is updated AFTER the external ETH transfer in withdraw(),
 * allowing the attacker to re-enter via transfer() and double-count their balance.
 *
 * Root cause: Violates Checks-Effects-Interactions (CEI) pattern.
 */
contract VulnerableBank {
    mapping(address => uint256) public balances;

    event Deposit(address indexed user, uint256 amount);
    event Withdrawal(address indexed user, uint256 amount);

    function deposit() external payable {
        balances[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    // VULNERABLE: external ETH send before state update
    function withdraw(uint256 amount) external {
        require(balances[msg.sender] >= amount, "insufficient balance");

        // INTERACTION before EFFECT — violates CEI
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "transfer failed");

        // State updated AFTER external call — too late
        balances[msg.sender] -= amount;
        emit Withdrawal(msg.sender, amount);
    }

    // Re-entry point: attacker calls this from receive() during withdraw()
    function transfer(address to, uint256 amount) external {
        require(balances[msg.sender] >= amount, "insufficient balance");
        // At this point, balances[attacker] is still the pre-withdrawal value
        // because withdraw() hasn't updated it yet
        balances[msg.sender] -= amount;
        balances[to] += amount;
    }

    receive() external payable {}
}
