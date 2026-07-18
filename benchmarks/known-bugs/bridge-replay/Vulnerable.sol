// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/**
 * @title VulnerableBridge
 * @notice Cross-chain bridge WITHOUT replay protection (no nonces or chain IDs).
 * @dev BENCHMARK CONTRACT — DO NOT USE IN PRODUCTION.
 *
 * Known vulnerability: Cross-chain or same-chain signature replay attack.
 * The signature payload only includes the user, amount, and token.
 * It does not include a nonce (allows replaying the same tx multiple times)
 * or a chain ID (allows replaying a signature meant for another chain).
 *
 * Root cause: Missing replay protection in the signed message hash.
 */
contract VulnerableBridge {
    using ECDSA for bytes32;

    address public signer;
    mapping(address => uint256) public balances;

    constructor(address _signer) {
        signer = _signer;
    }

    // VULNERABLE: No nonce or chainID in the signature payload
    function withdraw(
        address token,
        uint256 amount,
        bytes memory signature
    ) external {
        // Hash the payload (INCOMPLETE: missing nonce and block.chainid)
        bytes32 messageHash = keccak256(
            abi.encodePacked(msg.sender, token, amount)
        );
        
        bytes32 ethSignedMessageHash = messageHash.toEthSignedMessageHash();
        
        require(
            ethSignedMessageHash.recover(signature) == signer,
            "Invalid signature"
        );

        // State update (but attacker can just call this again with the same signature)
        balances[msg.sender] += amount;
        
        // Transfer tokens (simplified)
        // IERC20(token).transfer(msg.sender, amount);
    }
}
