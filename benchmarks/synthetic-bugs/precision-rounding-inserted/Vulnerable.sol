// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title CorrectVault (Original — No Bug)
 * @dev BENCHMARK REFERENCE — clean version.
 */
contract CorrectVault is ERC20 {
    ERC20 public immutable asset;
    uint256 private _storedTotalAssets; // internal accounting

    constructor(address _asset) ERC20("Correct Vault Share", "CVS") {
        asset = ERC20(_asset);
    }

    // SAFE: uses internal accounting, not raw balanceOf
    function totalAssets() public view returns (uint256) {
        return _storedTotalAssets;
    }

    function convertToShares(uint256 assets) public view returns (uint256) {
        uint256 supply = totalSupply();
        if (supply == 0) return assets;
        return (assets * supply) / totalAssets();
    }

    function deposit(uint256 assets, address receiver) public returns (uint256 shares) {
        shares = convertToShares(assets);
        require(shares > 0, "zero shares");
        _storedTotalAssets += assets; // update internal accounting FIRST
        asset.transferFrom(msg.sender, address(this), assets);
        _mint(receiver, shares);
    }

    function redeem(uint256 shares, address receiver, address owner) public returns (uint256 assets) {
        assets = (shares * totalAssets()) / totalSupply();
        _storedTotalAssets -= assets;
        _burn(owner, shares);
        asset.transfer(receiver, assets);
    }
}

/**
 * @title VulnerableVaultBugInserted
 * @notice Same as CorrectVault but with precision rounding bug inserted.
 * @dev BUG INSERTED: withdraw() uses mulDivDown when it should use mulDivUp.
 * This means users can withdraw slightly more than they should,
 * burning fewer shares than required. Over many operations, this drains the vault.
 */
contract VulnerableVaultBugInserted is ERC20 {
    ERC20 public immutable asset;
    uint256 private _storedTotalAssets;

    constructor(address _asset) ERC20("Buggy Vault Share", "BVS") {
        asset = ERC20(_asset);
    }

    function totalAssets() public view returns (uint256) {
        return _storedTotalAssets;
    }

    // SAFE: deposit rounds DOWN (user gets fewer shares) — correct
    function previewDeposit(uint256 assets) public view returns (uint256) {
        uint256 supply = totalSupply();
        if (supply == 0) return assets;
        return (assets * supply) / totalAssets(); // floor — correct
    }

    // BUG INSERTED: withdraw should round UP (burn more shares per asset)
    // but this rounds DOWN (user burns fewer shares → withdraws more than entitled)
    function previewWithdraw(uint256 assets) public view returns (uint256 shares) {
        uint256 supply = totalSupply();
        if (supply == 0) return assets;
        // WRONG: floor division favors user
        shares = (assets * supply) / totalAssets();
        // CORRECT would be: shares = ceil(assets * supply / totalAssets)
        // i.e., (assets * supply + totalAssets - 1) / totalAssets
    }

    function deposit(uint256 assets, address receiver) public returns (uint256 shares) {
        shares = previewDeposit(assets);
        require(shares > 0, "zero shares");
        _storedTotalAssets += assets;
        asset.transferFrom(msg.sender, address(this), assets);
        _mint(receiver, shares);
    }

    function withdraw(uint256 assets, address receiver, address owner) public returns (uint256 shares) {
        shares = previewWithdraw(assets); // BUG: underestimates shares to burn
        _storedTotalAssets -= assets;
        _burn(owner, shares);
        asset.transfer(receiver, assets);
    }
}
