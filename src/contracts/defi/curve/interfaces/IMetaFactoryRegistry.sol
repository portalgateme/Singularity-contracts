// SPDX-License-Identifier: MIT

pragma solidity >=0.8.20;

interface IMetaFactoryRegistry {
    function get_coins(address pool) external view returns (address[] memory);

    function get_n_coins(address pool) external view returns (uint256);
}
