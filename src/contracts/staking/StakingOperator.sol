// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IStakingOperator} from "./interfaces/IStakingOperator.sol";

/// @title Staking Operator Contract
/// @notice Manages the staking operations including setting unlock windows and collateral tokens
contract StakingOperator is Ownable, IStakingOperator {
    /// @notice Represents the unlock window
    UnlockWindow public unlockWindow;

    /// @notice Flag to indicate if the unlock window is active
    bool public isUnlockWindowActive;

    /// @notice Maps original tokens to their wrapped counterparts
    mapping(address original => address wrapped) public collateralTokens;

    /// @notice Maps wrapped tokens to their original counterparts
    mapping(address wrapped => address original) public originalTokens;

    /**
     * @notice Constructor to initialize the contract with unlock window parameters and owner
     * @param unlockWindowStart The start timestamp of the unlock window
     * @param unlockWindowDuration The duration of the unlock window
     * @param owner The address of the contract owner
     */
    constructor(
        uint256 unlockWindowStart,
        uint256 unlockWindowDuration,
        bool isUnlockWindowActive_,
        address owner
    ) Ownable(owner) {
        if (isUnlockWindowActive_) {
            _setUnlockWindow(unlockWindowStart, unlockWindowDuration);
            isUnlockWindowActive = true;
        }
    }

    /**
     * @notice Gets the original token for a collateral token
     * @param wrapped The address of the wrapped token
     * @return The address of the original token
     */
    function getOriginalToken(address wrapped) external view returns (address) {
        return originalTokens[wrapped];
    }

    /**
     * @notice Gets the collateral token for an original token
     * @param original The address of the original token
     * @return The address of the collateral (wrapped) token
     */
    function getCollateralToken(
        address original
    ) external view returns (address) {
        return collateralTokens[original];
    }

    /**
     * @notice Checks if unlock is allowed at the current timestamp
     * @param currentTimestamp The current timestamp to check
     * @return True if unlock is allowed, false otherwise
     */
    function isUnlockAllowed(
        uint256 currentTimestamp
    ) external view returns (bool) {
        if (!isUnlockWindowActive) {
            return true;
        }

        return
            currentTimestamp >= unlockWindow.start &&
            currentTimestamp <= unlockWindow.start + unlockWindow.duration;
    }

    /**
     * @notice Sets the unlock allowed flag
     * @param isUnlockWindowActive_ Flag to indicate if the unlock window is active
     * @dev Can only be called by the contract owner
     */
    function setIsUnlockWindowActive(
        bool isUnlockWindowActive_
    ) external onlyOwner {
        isUnlockWindowActive = isUnlockWindowActive_;
    }

    /**
     * @notice Sets the unlock window parameters and checks
     * @param unlockWindowStart The start timestamp of the unlock window
     * @param unlockWindowDuration The duration of the unlock window
     * @dev Can only be called by the contract owner
     */
    function setUnlockWindow(
        uint256 unlockWindowStart,
        uint256 unlockWindowDuration
    ) external onlyOwner {
        _setUnlockWindow(unlockWindowStart, unlockWindowDuration);
    }

    /**
     * @notice Sets the collateral token for an original token
     * @param original The address of the original token
     * @param wrapped The address of the collateral (wrapped) token
     * @param force Flag to force set the collateral token
     * @dev Can only be called by the contract owner
     * @dev Reverts if original and wrapped tokens are the same or if either address is zero
     * @dev Reverts if the original token is already set
     */
    function setCollateralToken(
        address original,
        address wrapped,
        bool force
    ) external onlyOwner {
        if (collateralTokens[original] != address(0) && !force) {
            revert CollateralTokenAlreadySet();
        }

        if (
            (original == wrapped) ||
            (original == address(0)) ||
            (wrapped == address(0))
        ) {
            revert InvalidCollateralToken();
        }

        collateralTokens[original] = wrapped;
        originalTokens[wrapped] = original;

        emit CollateralTokenSet(original, wrapped);
    }

    /**
     * @notice Sets the unlock window parameters
     * @param unlockWindowStart The start timestamp of the unlock window
     * @param unlockWindowDuration The duration of the unlock window
     */
    function _setUnlockWindow(
        uint256 unlockWindowStart,
        uint256 unlockWindowDuration
    ) internal {
        if (unlockWindowStart == 0) {
            revert InvalidUnlockWindowStart();
        }

        if (unlockWindowDuration == 0) {
            revert InvalidUnlockWindowDuration();
        }

        unlockWindow = UnlockWindow(unlockWindowStart, unlockWindowDuration);
        emit UnlockWindowSet(unlockWindowStart, unlockWindowDuration);
    }
}
