// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title SafeAdminWithdraw
 * @notice Contract with an admin-only rug pull / sweep function.
 * @dev BENCHMARK FALSE-POSITIVE CASE.
 *
 * This contract MUST NOT be flagged as a high/critical vulnerability for the
 * admin's ability to withdraw funds, IF the attacker model explicitly excludes
 * malicious admins (which is standard unless specified).
 *
 * The harness should produce: REFUTED or informational finding.
 */
contract SafeAdminWithdraw is Ownable {
    mapping(address => uint256) public balances;

    function deposit() external payable {
        balances[msg.sender] += msg.value;
    }

    // "VULNERABLE" by design, but protected by onlyOwner.
    // If the attacker model assumes the owner is trusted (G6: No Trusted Role),
    // this must NOT be flagged as a valid attack path.
    function sweep(address payable to) external onlyOwner {
        to.transfer(address(this).balance);
    }
}
