// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

contract MockIZKMEVerifyUpgradeable {
    mapping(address => bool) public verifiedAddresses;
    address private constant ALICE_ADDRESS =
        0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address private constant BOB_ADDRESS =
        0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    address private constant CHARLIE_ADDRESS =
        0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;

    constructor() {
        verifiedAddresses[ALICE_ADDRESS] = true;
        verifiedAddresses[BOB_ADDRESS] = true;
        verifiedAddresses[CHARLIE_ADDRESS] = true;
    }

    function verify(
        address cooperator,
        address user
    ) external view returns (bool) {
        return verifiedAddresses[user];
    }

    function hasApproved(
        address cooperator,
        address user
    ) external view returns (bool) {
        return verifiedAddresses[user];
    }
}
