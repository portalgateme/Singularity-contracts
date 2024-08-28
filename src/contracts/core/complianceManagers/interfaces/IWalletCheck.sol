// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

interface IWalletCheck {
    function checkWallet(
        address observer,
        address wallet,
        uint32 admissionPolicyId
    ) external returns (bool passed);
}
