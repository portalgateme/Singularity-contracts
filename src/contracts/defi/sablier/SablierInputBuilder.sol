// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {BaseInputBuilder} from "../../core/base/BaseInputBuilder.sol";

/**
 * @title SablierInputBuilder
 * @dev SablierInputBuilder contract is used to build inputs for ZK verifiers.
 */
contract SablierInputBuilder is BaseInputBuilder {

    struct CreateStreamRawInputs {
        address sender;
        address assetIn;
        uint128 amountIn;
        uint128 streamSize;
        uint128 streamType;
        bytes32 streamParametersHash;
        address nftOut;
        bytes32[] noteFooters;
    }

    struct ClaimStreamRawInputs {
        bytes32 merkleRoot;
        bytes32 nullifierIn;
        address stream;
        uint256 streamId;
        address assetOut;
        uint128 amountOut;
        bytes32 noteFooter;
        address relayer;
    }

    constructor(uint256 primeField) BaseInputBuilder(primeField) {}

    function _buildCreateStreamInputs(
        CreateStreamRawInputs memory _rawInputs
    ) internal view returns (bytes32[] memory) {
        bytes32[] memory inputs = new bytes32[](12);
        inputs[0] = _bytifyToNoir(_rawInputs.sender);
        inputs[1] = _bytifyToNoir(_rawInputs.assetIn);
        inputs[2] = bytes32(uint256(_rawInputs.amountIn));
        inputs[3] = bytes32(uint256(_rawInputs.streamSize));
        inputs[4] = bytes32(uint256(_rawInputs.streamType));
        inputs[5] = bytes32(uint256(_rawInputs.streamParametersHash) % _primeField);
        inputs[6] = _bytifyToNoir(_rawInputs.nftOut);
        
        for (uint256 i = 0; i < 5; i++) {
            if (i < _rawInputs.noteFooters.length){
                inputs[7 + i] = _rawInputs.noteFooters[i];
            } else {
                inputs[7 + i] = bytes32(0);
            }
        }
        return inputs;
    }

    function _buildClaimStreamInputs(
        ClaimStreamRawInputs memory _rawInputs
    ) internal pure returns (bytes32[] memory) {
        bytes32[] memory inputs = new bytes32[](8);

        inputs[0] = _rawInputs.merkleRoot;
        inputs[1] = _rawInputs.nullifierIn;
        inputs[2] = _bytifyToNoir(_rawInputs.stream);
        inputs[3] = bytes32(_rawInputs.streamId);
        inputs[4] = _bytifyToNoir(_rawInputs.assetOut);
        inputs[5] = bytes32(uint256(_rawInputs.amountOut));
        inputs[6] = _rawInputs.noteFooter;
        inputs[7] = _bytifyToNoir(_rawInputs.relayer);
        return inputs;
    }
}
