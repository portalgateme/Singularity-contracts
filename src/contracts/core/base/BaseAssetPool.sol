// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {IAssetPool} from "../interfaces/IAssetPool.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title BaseAssetPool
 * @dev Base contract for asset pools.
 */
abstract contract BaseAssetPool is Ownable {
    mapping(address assetManager => bool registered)
        internal _assetManagerRegistered;
    bool private _transferLock;

    modifier onlyAssetManager() {
        require(
            _assetManagerRegistered[msg.sender],
            "BaseAssetPool: Only asset manager can call this function"
        );
        _;
    }
    /**
     * @dev Modifier to check if transfers are locked.
     *      Used for any emergency situation.
     */
    modifier transferNotLocked() {
        require(!_transferLock, "Transfers are locked.");
        _;
    }

    constructor(address initialOwner) Ownable(initialOwner) {
        _transferLock = false;
    }

    function setAssetManager(
        address assetManager,
        bool registered
    ) external onlyOwner {
        _assetManagerRegistered[assetManager] = registered;
    }

    function setTransferLock(bool lock) external onlyOwner {
        _transferLock = lock;
    }

    function getAssetManagerRegistration(
        address assetManager
    ) external view returns (bool) {
        return _assetManagerRegistered[assetManager];
    }

    function getTransferLock() external view returns (bool) {
        return _transferLock;
    }
}
