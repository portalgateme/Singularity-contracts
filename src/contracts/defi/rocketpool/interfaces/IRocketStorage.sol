// SPDX-License-Identifier: MIT

pragma solidity >=0.8.20;

interface IRocketStorage {

    //Keys:
    //keccak256(abi.encodePacked("contract.address", "rocketDepositPool"))
    //keccak256(abi.encodePacked("contract.address", "rocketTokenRETH"))
    function getAddress(bytes32 _key) external view returns (address);
}