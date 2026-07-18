// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title SafeBankWithCEI
 * @notice Bank contract using CEI pattern AND ReentrancyGuard.
 * @dev BENCHMARK FALSE-POSITIVE CASE.
 *
 * This contract MUST NOT be flagged for reentrancy.
 * The state is updated BEFORE the external call (CEI), AND
 * the function has a nonReentrant modifier (defense in depth).
 *
 * A harness that flags this as "reentrancy vulnerability" has a high FP rate.
 */
contract SafeBankWithCEI is ReentrancyGuard {
    mapping(address => uint256) public balances;

    function deposit() external payable {
        balances[msg.sender] += msg.value;
    }

    // SAFE: CEI pattern + nonReentrant guard
    function withdraw(uint256 amount) external nonReentrant {
        require(balances[msg.sender] >= amount, "insufficient");

        // EFFECT before INTERACTION — CEI followed correctly
        balances[msg.sender] -= amount;

        // INTERACTION last — even if attacker re-enters, balance is already 0
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "transfer failed");
    }
}
