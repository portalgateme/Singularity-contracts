// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {BaseInputBuilder} from "./base/BaseInputBuilder.sol";

contract NftInputBuilder is BaseInputBuilder {

    struct NftWithdrawRawInputs {
        address recipient;
        bytes32 merkleRoot;
        address asset;
        uint256 nftID;
        bytes32 nullifier;
    }

    struct NftTransferRawInputs {
        bytes32 merkleRoot;
        address asset;
        uint256 nftID;
        bytes32 nullifierIn;
        bytes32 noteOut;
        bytes32 noteFooter;
    }


    constructor(uint256 primeField) BaseInputBuilder(primeField) {}


    function _buildNftWithdrawInputs(
        NftWithdrawRawInputs memory _rawInputs
    ) internal pure returns (bytes32[] memory) {
        bytes32[] memory inputs = new bytes32[](5);
        inputs[0] = _bytifyToNoir(_rawInputs.recipient);
        inputs[1] = _rawInputs.merkleRoot;
        inputs[2] = _bytifyToNoir(_rawInputs.asset);
        inputs[3] = bytes32(_rawInputs.nftID);
        inputs[4] = _rawInputs.nullifier;

        return inputs;
    }

    function _buildNftTransferInputs(
        NftTransferRawInputs memory _rawInputs
    ) internal pure returns (bytes32[] memory) {
        bytes32[] memory inputs = new bytes32[](6);
        inputs[0] = _rawInputs.merkleRoot;
        inputs[1] = _bytifyToNoir(_rawInputs.asset);
        inputs[2] = bytes32(_rawInputs.nftID);
        inputs[3] = _rawInputs.nullifierIn;
        inputs[4] = _rawInputs.noteOut;
        inputs[5] = _rawInputs.noteFooter;

        return inputs;
    }
}
