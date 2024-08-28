// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {BaseInputBuilder} from "../../core/base/BaseInputBuilder.sol";

contract RocketPoolStakeInputBuilder is BaseInputBuilder {

    struct RocketPoolStakeRawInputs {
        bytes32 merkleRoot;
        address asset;
        uint256 amount;
        bytes32 nullifier;
        bytes32 noteFooter;
        address relayer;
    }

    constructor(uint256 primeField) BaseInputBuilder(primeField) {}


    function _buildRocketPoolStakeInputs(
        RocketPoolStakeRawInputs memory _rawInputs
    ) internal pure returns (bytes32[] memory) {
        bytes32[] memory inputs = new bytes32[](6);
        inputs[0] = _rawInputs.merkleRoot;
        inputs[1] = _bytifyToNoir(_rawInputs.asset);
        inputs[2] = bytes32(_rawInputs.amount);
        inputs[3] = _rawInputs.nullifier;
        inputs[4] = _rawInputs.noteFooter;
        inputs[5] = _bytifyToNoir(_rawInputs.relayer);

        return inputs;
    }
}
