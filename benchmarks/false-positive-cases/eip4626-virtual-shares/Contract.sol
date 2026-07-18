// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title SafeVaultWithVirtualShares
 * @notice ERC4626 vault WITH virtual shares — protected against share inflation.
 * @dev BENCHMARK FALSE-POSITIVE CASE.
 *
 * This contract MUST NOT be flagged for share inflation.
 * The _decimalsOffset() = 3 means 1000 virtual shares always exist,
 * making the first-depositor attack economically infeasible.
 *
 * The harness should produce: REFUTED or no finding for share inflation.
 */
contract SafeVaultWithVirtualShares is ERC20 {
    ERC20 public immutable asset;
    uint256 private constant VIRTUAL_OFFSET = 10 ** 3; // 1000 virtual shares

    constructor(address _asset) ERC20("Safe Vault Share", "SVS") {
        asset = ERC20(_asset);
    }

    // Protected: donation doesn't significantly affect share price
    // because the denominator always has VIRTUAL_OFFSET added
    function totalAssets() public view returns (uint256) {
        return asset.balanceOf(address(this)) + 1; // +1 virtual asset
    }

    function totalSupply() public view override returns (uint256) {
        return super.totalSupply() + VIRTUAL_OFFSET; // virtual shares
    }

    function convertToShares(uint256 assets) public view returns (uint256) {
        // Uses virtualised totalSupply and totalAssets
        return (assets * totalSupply()) / totalAssets();
    }

    function convertToAssets(uint256 shares) public view returns (uint256) {
        return (shares * totalAssets()) / totalSupply();
    }

    function deposit(uint256 assets, address receiver) public returns (uint256 shares) {
        shares = convertToShares(assets);
        asset.transferFrom(msg.sender, address(this), assets);
        _mint(receiver, shares);
    }

    function redeem(uint256 shares, address receiver, address owner) public returns (uint256 assets) {
        assets = convertToAssets(shares);
        _burn(owner, shares);
        asset.transfer(receiver, assets);
    }
}
