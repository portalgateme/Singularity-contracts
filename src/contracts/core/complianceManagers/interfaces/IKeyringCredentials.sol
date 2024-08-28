// SPDX-License-Identifier: MIT

pragma solidity >=0.8.20;

interface IKeyringCredentials {
    function checkCredential(
        uint256 policyId,
        address subject
    ) external view returns (bool);
}
