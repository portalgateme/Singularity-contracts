// SPDX-License-Identifier: MIT

pragma solidity >=0.8.20;

interface IMultiExchange {
    function exchange(
        address[11] calldata route,
        uint256[5][5] calldata swapParams,
        uint256 amount,
        uint256 minAmount,
        address[5] calldata pools
    ) external payable returns (uint256);

    function get_dx(
        address[11] calldata route,
        uint256[5][5] calldata swapParams,
        uint256 amountOut,
        address[5] calldata pools,
        address[5] calldata basePools,
        address[5] calldata baseTokens
    ) external view returns (uint256);

    function get_dy(
        address[11] calldata route,
        uint256[5][5] calldata swapParams,
        uint256 amountIn,
        address[5] calldata pools
    ) external view returns (uint256);
}
