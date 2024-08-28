// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {BaseInputBuilder} from "./base/BaseInputBuilder.sol";

contract OTCSwapInputBuilder is BaseInputBuilder {

    struct SwapRawInputs {
        bytes32 merkleRoot;
        bytes32 aliceNullifier;
        bytes32 aliceOut;
        bytes32 aliceNoteFooter;
        bytes32 bobNullifier;
        bytes32 bobOut;
        bytes32 bobNoteFooter;
    }

    constructor(uint256 primeField) BaseInputBuilder(primeField) {}

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
