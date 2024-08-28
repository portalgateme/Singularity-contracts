// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

contract MockKeyringWalletCheck {
    address private _mockWalletCheck;
    mapping(bytes32 => uint256) public subjectUpdates;


    function checkWallet(
        address observer,
        address trader,
        uint32 admissionPolicyId
    ) external returns (bool) {
        return true;
    }
}
