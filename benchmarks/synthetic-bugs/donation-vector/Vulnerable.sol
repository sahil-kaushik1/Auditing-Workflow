// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title CorrectVault (Original — No Bug)
 * @dev BENCHMARK REFERENCE — clean version.
 */
contract CorrectVault is ERC20 {
    ERC20 public immutable asset;

    constructor(address _asset) ERC20("Correct Vault Share", "CVS") {
        asset = ERC20(_asset);
    }

    function totalAssets() public view returns (uint256) {
        return asset.balanceOf(address(this));
    }

    // SAFE: Offset prevents inflation
    function convertToShares(uint256 assets) public view returns (uint256) {
        uint256 supply = totalSupply() + 10**3;
        uint256 assetsTotal = totalAssets() + 1;
        return (assets * supply) / assetsTotal;
    }

    function deposit(uint256 assets, address receiver) public returns (uint256 shares) {
        shares = convertToShares(assets);
        require(shares > 0, "zero shares");
        asset.transferFrom(msg.sender, address(this), assets);
        _mint(receiver, shares);
    }
}

/**
 * @title VulnerableVaultBugInserted
 * @notice Same as CorrectVault but with a subtle donation vector bug inserted.
 * @dev BUG INSERTED: _mint is called BEFORE the asset transfer.
 * While this looks like a simple CEI violation, in an ERC4626 context without 
 * internal accounting, calling _mint first increases totalSupply. If the 
 * asset.transferFrom has a hook or allows reentrancy (e.g. ERC777), the attacker 
 * can read an inflated totalSupply while the asset hasn't arrived yet.
 * Also, if the transferFrom relies on a tax or exact amount, it can cause issues.
 * For this synthetic bug, we assume the token is an ERC777 and the attacker
 * re-enters during transferFrom.
 */
contract VulnerableVaultBugInserted is ERC20 {
    ERC20 public immutable asset;

    constructor(address _asset) ERC20("Buggy Vault Share", "BVS") {
        asset = ERC20(_asset);
    }

    function totalAssets() public view returns (uint256) {
        return asset.balanceOf(address(this));
    }

    function convertToShares(uint256 assets) public view returns (uint256) {
        uint256 supply = totalSupply() + 10**3;
        uint256 assetsTotal = totalAssets() + 1;
        return (assets * supply) / assetsTotal;
    }

    function deposit(uint256 assets, address receiver) public returns (uint256 shares) {
        shares = convertToShares(assets);
        require(shares > 0, "zero shares");
        
        // BUG INSERTED: Minting before transferring assets
        _mint(receiver, shares);
        
        // If asset is ERC777, sender can re-enter here. They have shares, 
        // and totalSupply is increased, but totalAssets is NOT yet increased.
        asset.transferFrom(msg.sender, address(this), assets);
    }
}
