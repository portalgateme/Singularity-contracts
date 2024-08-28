// SPDX-License-Identifier: MIT

pragma solidity >=0.8.20;

interface IMetaRegistry {
    function get_coins(address pool) external view returns (address[8] memory);

    function get_n_coins(address pool) external view returns (uint256);

    function get_underlying_coins(
        address pool
    ) external view returns (address[8] memory);

    function get_n_underlying_coins(
        address pool
    ) external view returns (uint256);

    function get_lp_token(address pool) external view returns (address);

    function get_base_pool(address pool) external view returns (address);

    function get_decimals(
        address pool
    ) external view returns (uint256[8] memory);
}
