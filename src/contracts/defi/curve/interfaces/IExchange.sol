// SPDX-License-Identifier: MIT

pragma solidity >=0.8.20;

interface IExchange {
    // could deal with eth as well
    function exchange(
        address pool,
        address from,
        address to,
        uint256 amount,
        uint256 expected
    ) external payable returns (uint256);
    function get_best_rate(
        address from,
        address to,
        uint256 amount
    ) external view returns (address, uint256);
    function get_exchange_amount(
        address pool,
        address from,
        address to,
        uint256 amount
    ) external view returns (uint256);
    function get_input_amount(
        address pool,
        address from,
        address to,
        uint256 amount
    ) external view returns (uint256);
}
