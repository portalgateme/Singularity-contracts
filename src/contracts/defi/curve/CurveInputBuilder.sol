// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {BaseInputBuilder} from "../../core/base/BaseInputBuilder.sol";

/**
 * @title CurveInputBuilder
 * @dev CurveInputBuilder contract is used to build inputs for ZK verifiers.
 */
contract CurveInputBuilder is BaseInputBuilder {
    struct ExchangeRawInputs {
        bytes32 merkleRoot;
        bytes32 nullifier;
        address assetIn;
        uint256 amountIn;
        address pool;
        address assetOut;
        uint256 minAmountOut;
        bytes32 noteFooter;
        address relayer;
    }

    struct MulitExchangeRawInputs {
        bytes32 merkleRoot;
        bytes32 nullifier;
        address assetIn;
        uint256 amountIn;
        bytes32 routeHash;
        address assetOut;
        uint256 minAmountOut;
        bytes32 noteFooter;
        address relayer;
    }

    struct LPRawInputs {
        bytes32 merkleRoot;
        bytes32[4] nullifiers;
        address[4] assets;
        uint256[4] amounts;
        address pool;
        uint256 poolFlag;
        bool booleanFlag;
        uint256 minMintAmount;
        bytes32 noteFooter;
        address relayer;
    }

    struct RemoveLiquidityRawInputs {
        bytes32 merkleRoot;
        bytes32 nullifier;
        address asset;
        uint256 amount;
        uint256 amountBurn;
        address pool;
        address[4] assetsOut;
        uint256 poolFlag;
        bool booleanFlag;
        uint256[4] minAmountsOut;
        bytes32[5] noteFooters;
        address relayer;
    }

    constructor(uint256 primeField) BaseInputBuilder(primeField) {}
    
    function _buildMultiExchangeInputs(
        MulitExchangeRawInputs memory _rawInputs
    ) internal view returns (bytes32[] memory) {
        bytes32[] memory inputs = new bytes32[](9);

        inputs[0] = _rawInputs.merkleRoot;
        inputs[1] = _rawInputs.nullifier;
        inputs[2] = _bytifyToNoir(_rawInputs.assetIn);
        inputs[3] = bytes32(_rawInputs.amountIn);
        inputs[4] = bytes32(uint256(_rawInputs.routeHash) % _primeField);
        inputs[5] = _bytifyToNoir(_rawInputs.assetOut);
        inputs[6] = bytes32(_rawInputs.minAmountOut);
        inputs[7] = _rawInputs.noteFooter;
        inputs[8] = _bytifyToNoir(_rawInputs.relayer);

        return inputs;
    }

    function _buildExchangeInputs(
        ExchangeRawInputs memory _rawInputs
    ) internal pure returns (bytes32[] memory) {
        bytes32[] memory inputs = new bytes32[](9);

        inputs[0] = _rawInputs.merkleRoot;
        inputs[1] = _rawInputs.nullifier;
        inputs[2] = _bytifyToNoir(_rawInputs.assetIn);
        inputs[3] = bytes32(_rawInputs.amountIn);
        inputs[4] = _bytifyToNoir(_rawInputs.pool);
        inputs[5] = _bytifyToNoir(_rawInputs.assetOut);
        inputs[6] = bytes32(_rawInputs.minAmountOut);
        inputs[7] = _rawInputs.noteFooter;
        inputs[8] = _bytifyToNoir(_rawInputs.relayer);

        return inputs;
    }

    function _buildLPInputs(
        LPRawInputs memory _rawInputs
    ) internal pure returns (bytes32[] memory) {
        bytes32[] memory inputs = new bytes32[](19);

        inputs[0] = _rawInputs.merkleRoot;
        for (uint256 i = 0; i < 4; i++) {
            inputs[i + 1] = _rawInputs.nullifiers[i];
        }
        for (uint256 i = 0; i < 4; i++) {
            inputs[i + 5] = _bytifyToNoir(_rawInputs.assets[i]);
        }
        for (uint256 i = 0; i < 4; i++) {
            inputs[i + 9] = bytes32(_rawInputs.amounts[i]);
        }

        inputs[13] = _bytifyToNoir(_rawInputs.pool);
        inputs[14] = bytes32(_rawInputs.poolFlag);
        inputs[15] = bytes32(uint256(_rawInputs.booleanFlag? 1 : 0));
        inputs[16] = bytes32(_rawInputs.minMintAmount);
        inputs[17] = _rawInputs.noteFooter;
        inputs[18] = _bytifyToNoir(_rawInputs.relayer);

        return inputs;
    }

    function _buildRemoveLiquidityInputs(
        RemoveLiquidityRawInputs memory _rawInputs
    ) internal pure returns (bytes32[] memory) {
        bytes32[] memory inputs = new bytes32[](22);

        inputs[0] = _rawInputs.merkleRoot;
        inputs[1] = _rawInputs.nullifier;
        inputs[2] = _bytifyToNoir(_rawInputs.asset);
        inputs[3] = bytes32(_rawInputs.amount);
        inputs[4] = bytes32(_rawInputs.amountBurn);
        inputs[5] = _bytifyToNoir(_rawInputs.pool);
        for (uint256 i = 0; i < 4; i++) {
            inputs[i + 6] = _bytifyToNoir(_rawInputs.assetsOut[i]);
        }
        
        inputs[10] = bytes32(_rawInputs.poolFlag);
        inputs[11] = bytes32(uint256(_rawInputs.booleanFlag? 1 : 0));

        for (uint256 i = 0; i < 4; i++) {
            inputs[i + 12] = bytes32(_rawInputs.minAmountsOut[i]);
        }

        for (uint256 i = 0; i < 5; i++) {
            inputs[i + 16] = _rawInputs.noteFooters[i];
        }
        inputs[21] = _bytifyToNoir(_rawInputs.relayer);
        return inputs;
    }
}
