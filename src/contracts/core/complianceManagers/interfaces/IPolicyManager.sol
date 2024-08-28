// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

interface IPolicyManager {
    function policyWalletChecks(
        uint32 policyId
    ) external returns (address[] memory);
}
