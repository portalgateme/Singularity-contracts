// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

/// @title Staking Operator Interface
/// @notice Interface for managing staking operations including unlock windows and collateral tokens
interface IStakingOperator {
    /// @notice Structure to define the unlock window
    /// @param start The start timestamp of the unlock window
    /// @param duration The duration of the unlock window
    struct UnlockWindow {
        uint256 start;
        uint256 duration;
    }

    /// @notice Event emitted when the unlock window is set
    /// @param start The start timestamp of the unlock window
    /// @param duration The duration of the unlock window
    event UnlockWindowSet(uint256 start, uint256 duration);

    /// @notice Event emitted when a collateral token is set
    /// @param original The address of the original token
    /// @param wrapped The address of the collateral (wrapped) token
    event CollateralTokenSet(address original, address wrapped);

    /// @notice Error thrown when an invalid collateral token is set
    error InvalidCollateralToken();
    /// @notice Error thrown when an invalid original token is already set
    error CollateralTokenAlreadySet();
    /// @notice Error thrown when an invalid unlock window duration is set
    error InvalidUnlockWindowDuration();
    /// @notice Error thrown when an invalid unlock window start is set
    error InvalidUnlockWindowStart();

    /**
     * @notice Gets the collateral token for an original token
     * @param original The address of the original token
     * @return The address of the collateral (wrapped) token
     */
    function getCollateralToken(
        address original
    ) external view returns (address);

    /**
     * @notice Gets the original token for a collateral token
     * @param wrapped The address of the wrapped token
     * @return The address of the original token
     */
    function getOriginalToken(address wrapped) external view returns (address);

    /**
     * @notice Checks if unlock is allowed at the current timestamp
     * @param currentTimestamp The current timestamp to check
     * @return True if unlock is allowed, false otherwise
     */
    function isUnlockAllowed(
        uint256 currentTimestamp
    ) external view returns (bool);

    /**
     * @notice Sets the collateral token for an original token
     * @param original The address of the original token
     * @param wrapped The address of the collateral (wrapped) token
     * @param force Flag to force set the collateral token
     * @dev Reverts if original and wrapped tokens are the same or if either address is zero
     */
    function setCollateralToken(address original, address wrapped, bool force) external;

    /**
     * @notice Sets the unlock window parameters
     * @param unlockWindowStart The start timestamp of the unlock window
     * @param unlockWindowDuration The duration of the unlock window
     */
    function setUnlockWindow(
        uint256 unlockWindowStart,
        uint256 unlockWindowDuration
    ) external;
}
