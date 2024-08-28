// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {BaseInputBuilder} from "../../core/base/BaseInputBuilder.sol";

/**
 * @title AerodromeInputBuilder
 * @dev AerodromeInputBuilder contract is used to build inputs for ZK verifiers.
 */
contract AerodromeInputBuilder is BaseInputBuilder {
    struct SwapRawInputs {
        bytes32 merkleRoot;
        bytes32 nullifier;
        address assetIn;
        uint256 amountIn;
        bytes32 routeHash;
        uint256 minAmountOut;
        uint256 deadline;
        bytes32 noteFooter;
        address relayer;
    }

    struct LPRawInputs {
        bytes32 merkleRoot;
        bytes32[2] nullifiers;
        address[2] assets;
        uint256[2] amounts;
        bool stable;
        uint256[2] minDepositedAmounts;
        address pool;
        uint256 deadline;
        bytes32[3] noteFooter;
        address relayer;
    }

    struct ZapInRawInputs {
        bytes32 merkleRoot;
        bytes32 nullifier;
        address asset;
        uint256 amountInA;
        uint256 amountInB;
        bytes32 zapHash;
        bytes32 routesAHash;
        bytes32 routesBHash;
        bool stake;
        bytes32 noteFooter;
        address relayer;
    }

    struct RemoveLiquidityRawInputs {
        bytes32 merkleRoot;
        bytes32 nullifier;
        address pool;
        uint256 amount;
        uint256 amountBurn;
        bool stable;
        address[2] assetsOut;
        uint256[2] amountsOutMin;
        uint256 deadline;
        bytes32[3] noteFooters;
        address relayer;
    }

    struct ZapOutRawInputs {
        bytes32 merkleRoot;
        bytes32 nullifier;
        address asset;
        address assetOut;
        uint256 amount;
        uint256 amountBurn;
        bytes32 zapHash;
        bytes32 routesAHash;
        bytes32 routesBHash;
        bytes32[2] noteFooters;
        address relayer;
    }

    constructor(uint256 primeField) BaseInputBuilder(primeField) {}

    function _buildSwapInputs(
        SwapRawInputs memory _rawInputs
    ) internal view returns (bytes32[] memory) {
        bytes32[] memory inputs = new bytes32[](9);

        inputs[0] = _rawInputs.merkleRoot;
        inputs[1] = _rawInputs.nullifier;
        inputs[2] = _bytifyToNoir(_rawInputs.assetIn);
        inputs[3] = bytes32(_rawInputs.amountIn);
        inputs[4] = bytes32(uint256(_rawInputs.routeHash) % _primeField);
        inputs[5] = bytes32(_rawInputs.minAmountOut);
        inputs[6] = bytes32(_rawInputs.deadline);
        inputs[7] = _rawInputs.noteFooter;
        inputs[8] = _bytifyToNoir(_rawInputs.relayer);

        return inputs;
    }

    function _buildZapInInputs(
        ZapInRawInputs memory _rawInputs
    ) internal view returns (bytes32[] memory) {
        bytes32[] memory inputs = new bytes32[](11);

        inputs[0] = _rawInputs.merkleRoot;
        inputs[1] = _rawInputs.nullifier;
        inputs[2] = _bytifyToNoir(_rawInputs.asset);
        inputs[3] = bytes32(_rawInputs.amountInA);
        inputs[4] = bytes32(_rawInputs.amountInB);
        inputs[5] = bytes32(uint256(_rawInputs.zapHash) % _primeField);
        inputs[6] = bytes32(uint256(_rawInputs.routesAHash) % _primeField);
        inputs[7] = bytes32(uint256(_rawInputs.routesBHash) % _primeField);
        inputs[8] = bytes32(uint256(_rawInputs.stake ? 1: 0));
        inputs[9] = _rawInputs.noteFooter;
        inputs[10] = _bytifyToNoir(_rawInputs.relayer);

        return inputs;
    }

    function _buildZapOutInputs(
        ZapOutRawInputs memory _rawInputs
    ) internal view returns (bytes32[] memory) {
        bytes32[] memory inputs = new bytes32[](12);

        inputs[0] = _rawInputs.merkleRoot;
        inputs[1] = _rawInputs.nullifier;
        inputs[2] = _bytifyToNoir(_rawInputs.asset);
        inputs[3] = _bytifyToNoir(_rawInputs.assetOut);
        inputs[4] = bytes32(_rawInputs.amount);
        inputs[5] = bytes32(_rawInputs.amountBurn);
        inputs[6] = bytes32(uint256(_rawInputs.zapHash) % _primeField);
        inputs[7] = bytes32(uint256(_rawInputs.routesAHash) % _primeField);
        inputs[8] = bytes32(uint256(_rawInputs.routesBHash) % _primeField);
        inputs[9] = _rawInputs.noteFooters[0];
        inputs[10] = _rawInputs.noteFooters[1];
        inputs[11] = _bytifyToNoir(_rawInputs.relayer);

        return inputs;
    }

    function _buildLPInputs(
        LPRawInputs memory _rawInputs
    ) internal pure returns (bytes32[] memory) {
        bytes32[] memory inputs = new bytes32[](16);

        inputs[0] = _rawInputs.merkleRoot;
        inputs[1] = _rawInputs.nullifiers[0];
        inputs[2] = _rawInputs.nullifiers[1];
        inputs[3] = _bytifyToNoir(_rawInputs.assets[0]);
        inputs[4] = _bytifyToNoir(_rawInputs.assets[1]);
        inputs[5] = bytes32(_rawInputs.amounts[0]);
        inputs[6] = bytes32(_rawInputs.amounts[1]);
        inputs[7] = bytes32(uint256(_rawInputs.stable ? 1: 0));
        inputs[8] = bytes32(_rawInputs.minDepositedAmounts[0]);
        inputs[9] = bytes32(_rawInputs.minDepositedAmounts[1]);
        inputs[10] = _bytifyToNoir(_rawInputs.pool);
        inputs[11] = bytes32(_rawInputs.deadline);
        inputs[12] = _rawInputs.noteFooter[0];
        inputs[13] = _rawInputs.noteFooter[1];
        inputs[14] = _rawInputs.noteFooter[2];
        inputs[15] = _bytifyToNoir(_rawInputs.relayer);

        return inputs;
    }


    function _buildRemoveLiquidityInputs(
        RemoveLiquidityRawInputs memory _rawInputs
    ) internal pure returns (bytes32[] memory) {
        bytes32[] memory inputs = new bytes32[](15);

        inputs[0] = _rawInputs.merkleRoot;
        inputs[1] = _rawInputs.nullifier;
        inputs[2] = _bytifyToNoir(_rawInputs.pool);
        inputs[3] = bytes32(_rawInputs.amount);
        inputs[4] = bytes32(_rawInputs.amountBurn);
        inputs[5] = bytes32(uint256(_rawInputs.stable ? 1: 0));
        inputs[6] = _bytifyToNoir(_rawInputs.assetsOut[0]);
        inputs[7] = _bytifyToNoir(_rawInputs.assetsOut[1]);
        inputs[8] = bytes32(_rawInputs.amountsOutMin[0]);
        inputs[9] = bytes32(_rawInputs.amountsOutMin[1]);
        inputs[10] = bytes32(_rawInputs.deadline);
        inputs[11] = _rawInputs.noteFooters[0];
        inputs[12] = _rawInputs.noteFooters[1];
        inputs[13] = _rawInputs.noteFooters[2];
        inputs[14] = _bytifyToNoir(_rawInputs.relayer);

        return inputs;
    }
}
