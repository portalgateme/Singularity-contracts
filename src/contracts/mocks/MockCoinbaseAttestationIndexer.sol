
// SPDX-License-Identifier: MIT

pragma solidity >=0.8.20;

contract MockCoinbaseAttestationIndexer {
    function getAttestationUid(address recipient, bytes32 schemaUid) 
        external view returns (bytes32){
        return bytes32(uint256(1));
    }
}