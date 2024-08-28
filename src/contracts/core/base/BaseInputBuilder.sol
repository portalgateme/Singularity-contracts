// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

/**
 * @title BaseInputBuilder
 * @dev Base contract for ZK verify input builders.
 */
contract BaseInputBuilder {
    uint256 internal _primeField;

    constructor(uint256 primeField) {
        _primeField = primeField;
    }

    function _bytifyToNoir(address value) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(ripemd160(abi.encode(value)))));
    }
}
