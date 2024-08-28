// SPDX-License-Identifier: MIT

pragma solidity >=0.8.20;

interface IZKMEVerifyUpgradeable {
    function verify(
        address cooperator,
        address user
    ) external view returns (bool);

    function hasApproved(
        address cooperator, 
        address user
    ) external view returns (bool);
}
