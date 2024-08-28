// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {BaseInputBuilder} from "../../core/base/BaseInputBuilder.sol";
import {IMimc254} from "../../core/interfaces/IMimc254.sol";

/**
 * @title CurveInputBuilder
 * @dev CurveInputBuilder contract is used to build inputs for ZK verifiers.
 */
contract DefiInputBuilder is BaseInputBuilder {

    struct DefiRawInputs {
        bytes32 merkleRoot;
        bytes32[] nullifiers;
        IMimc254.NoteDomainSeparator inNoteType;
        address[] assets;
        uint256[] amounts;
        address contractAddress;
        bytes32 defiParametersHash;
        bytes32 [] noteFooters;
        IMimc254.NoteDomainSeparator outNoteType;
        address relayer;
    }

    constructor(uint256 primeField) BaseInputBuilder(primeField) {}

    function _buildLPInputs(
        DefiRawInputs memory _rawInputs
    ) internal view returns (bytes32[] memory) {
        bytes32[] memory inputs = new bytes32[](22);

        inputs[0] = _rawInputs.merkleRoot;
        for (uint256 i = 0; i < _rawInputs.nullifiers.length; i++) {
            inputs[i + 1] = _rawInputs.nullifiers[i];
        }
        
        inputs[5] = bytes32(uint256(_rawInputs.inNoteType));
        
        for (uint256 i = 0; i < _rawInputs.assets.length; i++) {
            inputs[i + 6] = _bytifyToNoir(_rawInputs.assets[i]);
        }
        for (uint256 i = 0; i < _rawInputs.amounts.length; i++) {
            inputs[i + 10] = bytes32(_rawInputs.amounts[i]);
        }

        inputs[14] = _bytifyToNoir(_rawInputs.contractAddress);
        inputs[15] = bytes32(uint256(_rawInputs.defiParametersHash) % _primeField);

        for (uint256 i = 0; i < _rawInputs.noteFooters.length; i++) {
            inputs[i + 16] = _rawInputs.noteFooters[i];
        }
        
        inputs[20] = bytes32(uint256(_rawInputs.outNoteType));
        

        inputs[21] = _bytifyToNoir(_rawInputs.relayer);
        
        return inputs;
    }
}
