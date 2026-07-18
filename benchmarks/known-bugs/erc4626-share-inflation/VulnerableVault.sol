// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title VulnerableVault
 * @notice ERC4626-style vault with a classic first-depositor share inflation vulnerability.
 * @dev DELIBERATELY VULNERABLE — for benchmark purposes only.
 *      Bug: No virtual shares offset. First depositor can inflate share price.
 */
contract VulnerableVault is ERC20 {
    using SafeERC20 for IERC20;

    IERC20 public immutable asset;

    constructor(address _asset) ERC20("Vault Shares", "vSHARE") {
        asset = IERC20(_asset);
    }

    function totalAssets() public view returns (uint256) {
        return asset.balanceOf(address(this));  // BUG: reads spot balance, vulnerable to donation
    }

    function convertToShares(uint256 assets) public view returns (uint256) {
        uint256 supply = totalSupply();
        if (supply == 0) return assets;
        return (assets * supply) / totalAssets();  // BUG: no virtual offset
    }

    function convertToAssets(uint256 shares) public view returns (uint256) {
        uint256 supply = totalSupply();
        if (supply == 0) return shares;
        return (shares * totalAssets()) / supply;
    }

    function deposit(uint256 assets, address receiver) external returns (uint256 shares) {
        shares = convertToShares(assets);
        require(shares > 0, "zero shares");
        asset.safeTransferFrom(msg.sender, address(this), assets);
        _mint(receiver, shares);
    }

    function redeem(uint256 shares, address receiver) external returns (uint256 assets) {
        assets = convertToAssets(shares);
        _burn(msg.sender, shares);
        asset.safeTransfer(receiver, assets);
    }
}
