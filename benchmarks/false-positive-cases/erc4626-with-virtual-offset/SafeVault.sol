// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title SafeVault
 * @notice ERC4626-style vault with virtual shares offset. Safe against share inflation.
 * @dev This contract is SAFE — used as a false-positive benchmark case.
 *      The virtual offset (1e3) makes inflation attacks economically infeasible.
 */
contract SafeVault is ERC20 {
    using SafeERC20 for IERC20;
    using Math for uint256;

    IERC20 public immutable asset;

    // Virtual shares offset — the key protection against first-depositor attacks
    uint256 private constant VIRTUAL_SHARES = 1e3;
    uint256 private constant VIRTUAL_ASSETS = 1e3;

    constructor(address _asset) ERC20("Safe Vault Shares", "svSHARE") {
        asset = IERC20(_asset);
    }

    function totalAssets() public view returns (uint256) {
        return asset.balanceOf(address(this));
    }

    function convertToShares(uint256 assets) public view returns (uint256) {
        // SAFE: virtual offset prevents first-depositor manipulation
        return assets.mulDiv(
            totalSupply() + VIRTUAL_SHARES,
            totalAssets() + VIRTUAL_ASSETS,
            Math.Rounding.Floor
        );
    }

    function convertToAssets(uint256 shares) public view returns (uint256) {
        // SAFE: virtual offset consistent with convertToShares
        return shares.mulDiv(
            totalAssets() + VIRTUAL_ASSETS,
            totalSupply() + VIRTUAL_SHARES,
            Math.Rounding.Floor
        );
    }

    function deposit(uint256 assets, address receiver) external returns (uint256 shares) {
        shares = convertToShares(assets);
        require(shares > 0, "zero shares");
        asset.safeTransferFrom(msg.sender, address(this), assets);
        _mint(receiver, shares);
    }

    function redeem(uint256 shares, address receiver) external returns (uint256 assets) {
        assets = convertToAssets(shares);
        require(assets > 0, "zero assets");
        _burn(msg.sender, shares);
        asset.safeTransfer(receiver, assets);
    }
}
