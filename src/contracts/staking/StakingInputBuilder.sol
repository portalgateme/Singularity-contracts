// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {BaseInputBuilder} from "../core/base/BaseInputBuilder.sol";

/// @title Staking Input Builder Contract
/// @notice Provides functionality to build inputs for staking operations
contract StakingInputBuilder is BaseInputBuilder {
    /// @notice Structure to hold raw inputs for lock operation
    /// @param merkleRoot The merkle root of the note
    /// @param inAsset The address of the asset being locked
    /// @param inAmount The amount of the asset being locked
    /// @param inNullifier The nullifier of the note
    /// @param relayer The address of the relayer
    /// @param outZkNoteFooter The footer of the note being created
    /// @param outZkAsset The address of the asset being created
    struct LockNoteRawInputs {
        bytes32 merkleRoot;
        address inAsset;
        uint256 inAmount;
        bytes32 inNullifier;
        address relayer;
        bytes32 outZkNoteFooter;
        address outZkAsset;
    }

    /// @notice Structure to hold raw inputs for lock asset operation
    /// @param owner The address of the asset owner
    /// @param asset The address of the asset being locked
    /// @param amount The amount of the asset being locked
    /// @param outZkNote The note being created
    /// @param outZkNoteFooter The footer of the note being created
    /// @param outZkAsset The address of the asset being created
    struct LockAssetRawInputs {
        address owner;
        address asset;
        uint256 amount;
        bytes32 outZkNote;
        bytes32 outZkNoteFooter;
        address outZkAsset;
    }

    /// @notice Structure to hold raw inputs for unlock operation
    /// @param merkleRoot The merkle root of the note
    /// @param inZkAsset The address of the asset being unlocked
    /// @param inZkAmount The amount of the asset being unlocked
    /// @param inZkNullifier The nullifier of the note
    /// @param relayer The address of the relayer
    /// @param outNoteFooter The footer of the note being created
    /// @param outAsset The address of the asset being created
    struct UnlockNoteRawInputs {
        bytes32 merkleRoot;
        address inZkAsset;
        uint256 inZkAmount;
        bytes32 inZkNullifier;
        address relayer;
        bytes32 outNoteFooter;
        address outAsset;
    }

    /**
     * @notice Constructor to initialize the contract with prime field parameter
     * @param primeField The prime field used for input building
     */
    constructor(uint256 primeField) BaseInputBuilder(primeField) {}

    /**
     * @notice Builds the inputs for the lock operation
     * @param _rawInputs The raw inputs for the lock operation
     * @return inputs An array of bytes32 representing the built inputs
     */
    function _buildLockNoteInputs(
        LockNoteRawInputs memory _rawInputs
    ) internal pure returns (bytes32[] memory) {
        bytes32[] memory inputs = new bytes32[](7);

        inputs[0] = (_rawInputs.merkleRoot);
        inputs[1] = _bytifyToNoir(_rawInputs.inAsset);
        inputs[2] = bytes32(_rawInputs.inAmount);
        inputs[3] = _rawInputs.inNullifier;
        inputs[4] = _bytifyToNoir(_rawInputs.relayer);
        inputs[5] = _rawInputs.outZkNoteFooter;
        inputs[6] = _bytifyToNoir(_rawInputs.outZkAsset);

        return inputs;
    }

    /**
     * @notice Builds the inputs for the lock asset operation
     * @param _rawInputs The raw inputs for the lock asset operation
     * @return inputs An array of bytes32 representing the built inputs
     */
    function _buildLockAssetInputs(
        LockAssetRawInputs memory _rawInputs
    ) internal pure returns (bytes32[] memory) {
        bytes32[] memory inputs = new bytes32[](6);

        inputs[0] = _bytifyToNoir(_rawInputs.owner);
        inputs[1] = _bytifyToNoir(_rawInputs.asset);
        inputs[2] = bytes32(_rawInputs.amount);
        inputs[3] = _rawInputs.outZkNote;
        inputs[4] = _rawInputs.outZkNoteFooter;
        inputs[5] = _bytifyToNoir(_rawInputs.outZkAsset);

        return inputs;
    }

    /**
     * @notice Builds the inputs for the unlock operation
     * @param _rawInputs The raw inputs for the unlock operation
     * @return inputs An array of bytes32 representing the built inputs
     */
    function _buildUnlockNoteInputs(
        UnlockNoteRawInputs memory _rawInputs
    ) internal pure returns (bytes32[] memory) {
        bytes32[] memory inputs = new bytes32[](7);

        inputs[0] = (_rawInputs.merkleRoot);
        inputs[1] = _bytifyToNoir(_rawInputs.inZkAsset);
        inputs[2] = bytes32(_rawInputs.inZkAmount);
        inputs[3] = _rawInputs.inZkNullifier;
        inputs[4] = _bytifyToNoir(_rawInputs.relayer);
        inputs[5] = _rawInputs.outNoteFooter;
        inputs[6] = _bytifyToNoir(_rawInputs.outAsset);

        return inputs;
    }
}
