// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title VulnerableVault
 * @notice ERC4626-style vault WITHOUT virtual shares protection.
 * @dev BENCHMARK CONTRACT — DO NOT USE IN PRODUCTION.
 *
 * Known vulnerability: First-depositor share inflation attack.
 * The attacker can manipulate the share price by donating tokens
 * directly to the vault, causing subsequent depositors to receive
 * zero shares, while the attacker extracts their deposit.
 *
 * Root cause: totalAssets() reads balanceOf(address(this)) directly,
 * and there is no virtual share offset (_decimalsOffset = 0).
 */
contract VulnerableVault is ERC20 {
    ERC20 public immutable asset;

    constructor(address _asset) ERC20("Vulnerable Vault Share", "vVS") {
        asset = ERC20(_asset);
    }

    // VULNERABLE: reads raw balanceOf — donation directly changes share price
    function totalAssets() public view returns (uint256) {
        return asset.balanceOf(address(this));
    }

    function convertToShares(uint256 assets) public view returns (uint256) {
        uint256 supply = totalSupply();
        if (supply == 0) return assets;
        // VULNERABLE: no virtual offset — denominator can be manipulated
        return (assets * supply) / totalAssets();
    }

    function convertToAssets(uint256 shares) public view returns (uint256) {
        uint256 supply = totalSupply();
        if (supply == 0) return shares;
        return (shares * totalAssets()) / supply;
    }

    function deposit(uint256 assets, address receiver) public returns (uint256 shares) {
        shares = convertToShares(assets);
        require(shares > 0, "zero shares");
        asset.transferFrom(msg.sender, address(this), assets);
        _mint(receiver, shares);
    }

    function redeem(uint256 shares, address receiver, address owner) public returns (uint256 assets) {
        assets = convertToAssets(shares);
        require(assets > 0, "zero assets");
        _burn(owner, shares);
        asset.transfer(receiver, assets);
    }
}
