// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {BaseInputBuilder} from "./base/BaseInputBuilder.sol";

contract DarkpoolInputBuilder is BaseInputBuilder {
    struct DepositRawInputs {
        address owner;
        bytes32 noteCommitment;
        address asset;
        uint256 amount;
        bytes32 noteFooter;
    }

    struct WithdrawRawInputs {
        address recipient;
        bytes32 merkleRoot;
        address asset;
        uint256 amount;
        bytes32 nullifier;
        address relayer;
    }

    struct TransferRawInputs {
        bytes32 merkleRoot;
        address asset;
        uint256 amount;
        bytes32 nullifierIn;
        bytes32 noteOut;
        bytes32 noteFooter;
    }

    struct SplitRawInputs {
        bytes32 merkleRoot;
        bytes32 nullifierIn1;
        bytes32 noteOut1;
        bytes32 noteOut2;
        bytes32 noteFooter1;
        bytes32 noteFooter2;
    }

    struct JoinSplitRawInputs {
        bytes32 merkleRoot;
        bytes32 nullifierIn1;
        bytes32 nullifierIn2;
        bytes32 noteOut1;
        bytes32 noteOut2;
        bytes32 noteFooter1;
        bytes32 noteFooter2;
    }

    struct JoinRawInputs {
        bytes32 merkleRoot;
        bytes32 nullifierIn1;
        bytes32 nullifierIn2;
        bytes32 noteOut1;
        bytes32 noteFooter1;
    }

    struct SwapRawInputs {
        bytes32 merkleRoot;
        bytes32 aliceNullifier;
        bytes32 aliceOut;
        bytes32 bobNullifier;
        bytes32 bobOut;
        bytes32 aliceNoteFooter;
        bytes32 bobNoteFooter;
    }

    constructor(uint256 primeField) BaseInputBuilder(primeField) {}

    function _buildDepositInputs(
        DepositRawInputs memory _rawInputs
    ) internal pure returns (bytes32[] memory) {
        bytes32[] memory inputs = new bytes32[](5);
        inputs[0] = _bytifyToNoir(_rawInputs.owner);
        inputs[1] = bytes32(_rawInputs.noteCommitment);
        inputs[2] = _bytifyToNoir(_rawInputs.asset);
        inputs[3] = bytes32(_rawInputs.amount);
        inputs[4] = _rawInputs.noteFooter;

        return inputs;
    }

    function _buildWithdrawInputs(
        WithdrawRawInputs memory _rawInputs
    ) internal pure returns (bytes32[] memory) {
        bytes32[] memory inputs = new bytes32[](6);
        inputs[0] = _bytifyToNoir(_rawInputs.recipient);
        inputs[1] = _rawInputs.merkleRoot;
        inputs[2] = _bytifyToNoir(_rawInputs.asset);
        inputs[3] = bytes32(_rawInputs.amount);
        inputs[4] = _rawInputs.nullifier;
        inputs[5] = _bytifyToNoir(_rawInputs.relayer);

        return inputs;
    }

    function _buildTransferInputs(
        TransferRawInputs memory _rawInputs
    ) internal pure returns (bytes32[] memory) {
        bytes32[] memory inputs = new bytes32[](6);
        inputs[0] = _rawInputs.merkleRoot;
        inputs[1] = _bytifyToNoir(_rawInputs.asset);
        inputs[2] = bytes32(_rawInputs.amount);
        inputs[3] = _rawInputs.nullifierIn;
        inputs[4] = _rawInputs.noteOut;
        inputs[5] = _rawInputs.noteFooter;

        return inputs;
    }

    function _buildSplitInputs(
        SplitRawInputs memory _rawInputs
    ) internal pure returns (bytes32[] memory) {
        bytes32[] memory inputs = new bytes32[](6);
        inputs[0] = _rawInputs.merkleRoot;
        inputs[1] = _rawInputs.nullifierIn1;
        inputs[2] = _rawInputs.noteOut1;
        inputs[3] = _rawInputs.noteOut2;
        inputs[4] = _rawInputs.noteFooter1;
        inputs[5] = _rawInputs.noteFooter2;

        return inputs;
    }

    function _buildJoinSplitInputs(
        JoinSplitRawInputs memory _rawInputs
    ) internal pure returns (bytes32[] memory) {
        bytes32[] memory inputs = new bytes32[](7);
        inputs[0] = _rawInputs.merkleRoot;
        inputs[1] = _rawInputs.nullifierIn1;
        inputs[2] = _rawInputs.nullifierIn2;
        inputs[3] = _rawInputs.noteOut1;
        inputs[4] = _rawInputs.noteOut2;
        inputs[5] = _rawInputs.noteFooter1;
        inputs[6] = _rawInputs.noteFooter2;

        return inputs;
    }

    function _buildJoinInputs(
        JoinRawInputs memory _rawInputs
    ) internal pure returns (bytes32[] memory) {
        bytes32[] memory inputs = new bytes32[](5);
        inputs[0] = _rawInputs.merkleRoot;
        inputs[1] = _rawInputs.nullifierIn1;
        inputs[2] = _rawInputs.nullifierIn2;
        inputs[3] = _rawInputs.noteOut1;
        inputs[4] = _rawInputs.noteFooter1;

        return inputs;
    }

    function _buildSwapInputs(
        SwapRawInputs memory _rawInputs
    ) internal pure returns (bytes32[] memory) {
        bytes32[] memory inputs = new bytes32[](7);
        inputs[0] = _rawInputs.merkleRoot;
        inputs[1] = _rawInputs.aliceNullifier;
        inputs[2] = _rawInputs.aliceOut;
        inputs[3] = _rawInputs.aliceNoteFooter;
        inputs[4] = _rawInputs.bobNullifier;
        inputs[5] = _rawInputs.bobOut;
        inputs[6] = _rawInputs.bobNoteFooter;

        return inputs;
    }
}
