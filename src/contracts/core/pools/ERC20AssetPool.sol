// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {BaseAssetPool} from "../base/BaseAssetPool.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";


contract ERC20AssetPool is BaseAssetPool,ReentrancyGuard {
    using SafeERC20 for IERC20;

    constructor(address initialOwner) BaseAssetPool(initialOwner) {}

    function release(
        address token,
        address to,
        uint256 amount
    ) external onlyAssetManager transferNotLocked nonReentrant{
        require(amount > 0, "ERC20AssetPool: amount must be greater than 0");

        require(
            IERC20(token).balanceOf(address(this)) >= amount,
            "ERC20AssetPool: Insufficient balance"
        );

        IERC20(token).safeTransfer(to, amount);
    }

    function approve(
        address token,
        address to,
        uint256 amount
    ) external onlyAssetManager transferNotLocked {
        require(amount > 0, "ERC20AssetPool: amount must be greater than 0");

        require(
            IERC20(token).balanceOf(address(this)) >= amount,
            "ERC20AssetPool: Insufficient balance"
        );

        IERC20(token).forceApprove(to, amount);
    }
}
