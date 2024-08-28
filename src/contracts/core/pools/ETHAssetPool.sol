// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {BaseAssetPool} from "../base/BaseAssetPool.sol";

contract ETHAssetPool is BaseAssetPool, ReentrancyGuard {
    constructor(address initialOwner) BaseAssetPool(initialOwner) {}

    receive() external onlyAssetManager payable {}

    function release(
        address payable to,
        uint256 amount
    ) external onlyAssetManager nonReentrant transferNotLocked {
        require(amount > 0, "ETHAssetPool: amount must be greater than 0");

        require(
            address(this).balance >= amount,
            "ETHAssetPool: Insufficient balance"
        );

        (bool success, ) = to.call{value: amount}("");
        require(success, "ETHAssetPool: Failed to send Ether");
    }
}
