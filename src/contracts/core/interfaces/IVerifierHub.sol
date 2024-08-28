// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {IVerifier} from "./IVerifier.sol";

interface IVerifierHub {
    function setVerifier(string memory verifierName, address addr) external;

    function getVerifierNames() external returns (string[] memory);

    function getVerifier(
        string memory verifierName
    ) external view returns (IVerifier);
}
