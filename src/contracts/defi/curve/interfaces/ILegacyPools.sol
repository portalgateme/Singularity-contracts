// SPDX-License-Identifier: MIT

pragma solidity >=0.8.20;

interface ILegacyPools {
    
    function add_liquidity(
        uint256[2] calldata amounts,
        uint256 minMintAmount
    ) external payable;

    function add_liquidity(
        uint256[3] calldata amounts,
        uint256 minMintAmount
    ) external payable;

    function add_liquidity(
        uint256[4] calldata amounts,
        uint256 minMintAmount
    ) external payable;

    function remove_liquidity(
        uint256 amount,
        uint256[2] calldata minAmounts
    ) external;

    function remove_liquidity(
        uint256 amount,
        uint256[3] calldata minAmounts
    ) external;

    function remove_liquidity(
        uint256 amount,
        uint256[4] calldata minAmounts
    ) external;

    function remove_liquidity(
        uint256 amount,
        uint256[2] calldata minAmounts,
        bool boolIndicator
    ) external;

    function remove_liquidity(
        uint256 amount,
        uint256[3] calldata minAmounts,
        bool boolIndicator
    ) external;

    function remove_liquidity(
        uint256 amount,
        uint256[4] calldata minAmounts,
        bool boolIndicator
    ) external;


    function remove_liquidity_one_coin(
        uint256 lpAmount,
        int128 i,
        uint256 minAmount
    ) external;

    function remove_liquidity_one_coin(
        uint256 lpAmount,
        uint256 i,
        uint256 minAmount
    ) external;
}