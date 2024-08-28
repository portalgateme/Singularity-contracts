// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {BaseInputBuilder} from "../../core/base/BaseInputBuilder.sol";

contract UniswapInputBuilder is BaseInputBuilder {
    struct UniswapSimpleSwapInputs {
        bytes32 merkleRoot;
        address assetIn;
        uint256 amountIn;
        bytes32 nullifierIn;
        address assetOut;
        bytes32 noteFooter;
        uint24 poolFee;
        uint256 amountOutMin;
        address relayer;
    }

    struct UniswapCollectFeesInputs {
        bytes32 merkleRoot;
        address positionAddress;
        uint256 tokenId;
        bytes32 fee1NoteFooter;
        bytes32 fee2NoteFooter;
        address relayer;
    }

    struct UniswapLiquidityProvisionInputs {
        bytes32 merkleRoot;
        address asset1Address;
        address asset2Address;
        uint256 amount1;
        uint256 amount2;
        bytes32 nullifier1;
        bytes32 nullifier2;
        int24 tickMin;
        int24 tickMax;
        bytes32 noteFooter;
        bytes32 changeNoteFooter1;
        bytes32 changeNoteFooter2;
        address relayer;
        uint256 amount1Min;
        uint256 amount2Min;
        uint256 deadline;
        uint24 poolFee;
    }

    struct UniswapRemoveLiquidityInputs {
        bytes32 merkleRoot;
        address positionAddress;
        bytes32 positionNullifier;
        uint256 tokenId;
        bytes32 out1NoteFooter;
        bytes32 out2NoteFooter;
        address relayer;
        uint256 amount1Min;
        uint256 amount2Min;
        uint256 deadline;
    }

    constructor(uint256 primeField) BaseInputBuilder(primeField) {}

    function _buildUniswapSimpleSwapInputs(
        UniswapSimpleSwapInputs memory _rawInputs
    ) internal view returns (bytes32[] memory) {
        bytes32[] memory inputs = new bytes32[](9);

        inputs[0] = _rawInputs.merkleRoot;
        inputs[1] = _bytifyToNoir(_rawInputs.assetIn);
        inputs[2] = bytes32(_rawInputs.amountIn);
        inputs[3] = _rawInputs.nullifierIn;
        inputs[4] = _bytifyToNoir(_rawInputs.assetOut);
        inputs[5] = _rawInputs.noteFooter;
        inputs[6] = bytes32(uint256(_rawInputs.poolFee));
        inputs[7] = bytes32(_rawInputs.amountOutMin);
        inputs[8] = _bytifyToNoir(_rawInputs.relayer);

        return inputs;
    }

    function _buildUniswapCollectFeesInputs(
        UniswapCollectFeesInputs memory _rawInputs
    ) internal pure returns (bytes32[] memory) {
        bytes32[] memory inputs = new bytes32[](6);

        inputs[0] = _rawInputs.merkleRoot;
        inputs[1] = _bytifyToNoir(_rawInputs.positionAddress);
        inputs[2] = bytes32(_rawInputs.tokenId);
        inputs[3] = _rawInputs.fee1NoteFooter;
        inputs[4] = _rawInputs.fee2NoteFooter;
        inputs[5] = _bytifyToNoir(_rawInputs.relayer);

        return inputs;
    }

    function _buildUniswapRemoveLiquidityInputs(
        UniswapRemoveLiquidityInputs memory _rawInputs
    ) internal pure returns (bytes32[] memory) {
        bytes32[] memory inputs = new bytes32[](10);

        inputs[0] = _rawInputs.merkleRoot;
        inputs[1] = _bytifyToNoir(_rawInputs.positionAddress);
        inputs[2] = bytes32(_rawInputs.tokenId);
        inputs[3] = _rawInputs.positionNullifier;
        inputs[4] = _rawInputs.out1NoteFooter;
        inputs[5] = _rawInputs.out2NoteFooter;
        inputs[6] = bytes32(_rawInputs.deadline);
        inputs[7] = _bytifyToNoir(_rawInputs.relayer);
        inputs[8] = bytes32(_rawInputs.amount1Min);
        inputs[9] = bytes32(_rawInputs.amount2Min);

        return inputs;
    }

    function _buildUniswapLiquidityProvisionInputs(
        UniswapLiquidityProvisionInputs memory _rawInputs
    ) internal pure returns (bytes32[] memory) {
        bytes32[] memory inputs = new bytes32[](19);

        inputs[0] = _rawInputs.merkleRoot;
        inputs[1] = _bytifyToNoir(_rawInputs.asset1Address);
        inputs[2] = _bytifyToNoir(_rawInputs.asset2Address);
        inputs[3] = bytes32(_rawInputs.amount1);
        inputs[4] = bytes32(_rawInputs.amount2);
        inputs[5] = _int24ToBytes32(_abs(_rawInputs.tickMin));
        inputs[6] = _int24ToBytes32(_abs(_rawInputs.tickMax));
        inputs[7] = _boolToBytes32(_rawInputs.tickMin >= 0);
        inputs[8] = _boolToBytes32(_rawInputs.tickMax >= 0);
        inputs[9] = _rawInputs.nullifier1;
        inputs[10] = _rawInputs.nullifier2;
        inputs[11] = _rawInputs.noteFooter;
        inputs[12] = _rawInputs.changeNoteFooter1;
        inputs[13] = _rawInputs.changeNoteFooter2;
        inputs[14] = _bytifyToNoir(_rawInputs.relayer);
        inputs[15] = bytes32(_rawInputs.amount1Min);
        inputs[16] = bytes32(_rawInputs.amount2Min);
        inputs[17] = bytes32(_rawInputs.deadline);
        inputs[18] = bytes32(uint256(_rawInputs.poolFee));

        return inputs;
    }

    function _int24ToBytes32(
        int24 value
    ) internal pure returns (bytes32 result) {
        assembly {
            result := value
        }
    }

    function _boolToBytes32(bool value) public pure returns (bytes32) {
        return value ? bytes32(uint256(1)) : bytes32(uint256(0));
    }

    function _abs(int24 value) internal pure returns (int24) {
        return value < 0 ? -value : value;
    }
}
