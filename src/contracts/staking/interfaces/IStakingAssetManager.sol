// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

/// @title Staking Asset Manager Interface
/// @notice Interface for managing staking assets and related operations
interface IStakingAssetManager {
    struct LockNoteArgs {
        address asset; // The address of the asset to be locked
        address relayer; // The address of the relayer handling the transaction
        bytes32 merkleRoot; // The Merkle root for the note
        bytes32 nullifier; // A unique identifier to prevent double-spending
        uint256 amount; // The amount of the asset to be locked
        uint256 relayerGasFee; // The gas fee to be paid to the relayer
        bytes32 zkNoteFooter; // Footer information for the out zkNote
    }

    struct LockERC20Args {
        address asset; // The address of the asset to be locked
        uint256 amount; // The amount of the asset to be locked
        bytes32 zkNoteCommitment; // The commitment hash for the note
        bytes32 zkNoteFooter; // Footer information for the zkNote
    }

    struct LockETHArgs {
        bytes32 zkNoteCommitment; // The commitment hash for the note
        bytes32 zkNoteFooter; // Footer information for the zkNote
    }

    struct UnlockNoteArgs {
        address relayer;
        uint256 relayerGasFee;
        bytes32 merkleRoot;
        bytes32 zkNoteNullifier;
        address zkNoteAsset;
        uint256 zkNoteAmount;
        bytes32 outNoteFooter;
    }

    /// @notice Error thrown when the collateral token is missing
    error CollateralTokenMissing();

    /// @notice Error thrown when compliance validation fails
    error InvalidCompliance();

    /// @notice Error thrown when there is insufficient ZK token balance
    error InsufficientZKTokenBalance();

    /// @notice Error thrown when unlock is not allowed
    error UnlockNotAllowed();

    /**
     * @notice Event emitted when assets are locked
     * @param locker The address of the wallet locking the assets
     * @param assetIn The address of the asset being locked (collateral)
     * @param assetOut The address of the asset being locked (zkAsset)
     * @param amountOut The amount of asset locked
     * @param noteNullifierIn The nullifier of the note being locked
     * @param noteFooter The footer of the note being locked
     * @param noteCommitmentOut The commitment of the note being locked
     */
    event Locked(
        address locker,
        address assetIn,
        address assetOut,
        uint256 amountOut,
        bytes32 noteNullifierIn,
        bytes32 noteFooter,
        bytes32 noteCommitmentOut
    );

    /**
     * @notice Event emitted when assets are unlocked
     * @param assetIn The address of the asset being unlocked
     * @param assetOut The address of the asset being unlocked
     * @param amountOut The amount of asset unlocked
     * @param noteNullifierIn The nullifier of the note being unlocked
     * @param noteFooter The footer of the note being unlocked
     * @param noteCommitmentOut The commitment of the note being unlocked
     */
    event Unlocked(
        address assetIn,
        address assetOut,
        uint256 amountOut,
        bytes32 noteNullifierIn,
        bytes32 noteFooter,
        bytes32 noteCommitmentOut
    );
}
