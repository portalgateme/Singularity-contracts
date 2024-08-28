
// SPDX-License-Identifier: MIT

pragma solidity >=0.8.20;

interface ICoinbaseAttestationIndexer {
    function getAttestationUid(address recipient, bytes32 schemaUid) 
        external view returns (bytes32);
}