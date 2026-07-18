// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title SafeInformational
 * @notice Contract with missing zero-address checks and no indexed events.
 * @dev BENCHMARK FALSE-POSITIVE CASE.
 *
 * This contract MUST NOT be flagged as a high/critical security vulnerability.
 * Missing zero-address checks or missing `indexed` keywords on events are
 * informational best practices, not exploitable attack vectors.
 *
 * The harness should produce: REFUTED (if proposed as an attack) or Informational.
 */
contract SafeInformational {
    address public feeRecipient;
    
    event RecipientUpdated(address oldRecipient, address newRecipient); // Not indexed

    // Missing zero-address check
    function setFeeRecipient(address newRecipient) external {
        // Assume some auth modifier exists in reality, omitted for brevity
        address old = feeRecipient;
        feeRecipient = newRecipient;
        emit RecipientUpdated(old, newRecipient);
    }
}
