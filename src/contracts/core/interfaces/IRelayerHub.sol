// SPDX-License-Identifier: MIT

pragma solidity >=0.8.20;

interface IRelayerHub {
    function isRelayerRegistered(address _relayer) external view returns (bool);
}
