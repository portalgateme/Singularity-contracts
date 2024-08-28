// SPDX-License-Identifier: MIT

pragma solidity >=0.8.20;

interface IPools {
    function get_dy(
        int128 i,
        int128 j,
        uint256 dx
    ) external view returns (uint256);

    function exchange(
        int128 i,
        int128 j,
        uint256 dx,
        uint256 minDy
    ) external returns (uint256);

    function calc_token_amount(
        uint256[2] calldata amounts,
        bool deposit
    ) external view returns (uint256);

    function calc_token_amount(
        uint256[3] calldata amounts,
        bool deposit
    ) external view returns (uint256);

    function calc_token_amount(
        uint256[4] calldata amounts,
        bool deposit
    ) external view returns (uint256);

    function calc_token_amount(
        address pool,
        uint256[3] calldata amounts,
        bool deposit
    ) external view returns (uint256);

    function calc_token_amount(
        address pool,
        uint256[4] calldata amounts,
        bool deposit
    ) external view returns (uint256);


    function calc_token_amount(
        uint256[2] calldata amounts
    ) external view returns (uint256);

    function calc_token_amount(
        uint256[3] calldata amounts
    ) external view returns (uint256);

    function calc_token_amount(
        uint256[4] calldata amounts
    ) external view returns (uint256);

    function calc_token_amount(
        address pool,
        uint256[3] calldata amounts
    ) external view returns (uint256);

    function calc_token_amount(
        address pool,
        uint256[4] calldata amounts
    ) external view returns (uint256);

    function calc_token_amount(
        uint256[] calldata amounts,
        bool deposit
    ) external view returns (uint256);

    function add_liquidity(
        uint256[2] calldata amounts,
        uint256 minMintAmount
    ) external payable returns (uint256);

    function add_liquidity(
        uint256[3] calldata amounts,
        uint256 minMintAmount
    ) external payable returns (uint256);

    function add_liquidity(
        uint256[4] calldata amounts,
        uint256 minMintAmount
    ) external payable returns (uint256);

    function add_liquidity(
        address pool,
        uint256[3] calldata amounts,
        uint256 minMintAmount
    ) external  returns (uint256);

    function add_liquidity(
        address pool,
        uint256[4] calldata amounts,
        uint256 minMintAmount
    ) external  returns (uint256);


    function add_liquidity(
        uint256[] calldata amounts,
        uint256 minMintAmount
    ) external payable returns (uint256);

    function remove_liquidity(
        uint256 amount,
        uint256[2] calldata minAmounts
    ) external returns (uint256[2] memory);

    function remove_liquidity(
        uint256 amount,
        uint256[3] calldata minAmounts
    ) external returns (uint256[3] memory);

    function remove_liquidity(
        uint256 amount,
        uint256[4] calldata minAmounts
    ) external returns (uint256[4] memory);

    function remove_liquidity(
        address pool,
        uint256 amount,
        uint256[3] calldata minAmounts
    ) external returns (uint256[3] memory);

    function remove_liquidity(
        address pool,
        uint256 amount,
        uint256[4] calldata minAmounts
    ) external returns (uint256[4] memory);


    function remove_liquidity(
        uint256 amount,
        uint256[] calldata minAmounts
    ) external returns (uint256[] memory);


    function remove_liquidity_one_coin(
        uint256 lpAmount,
        int128 i,
        uint256 minAmount
    ) external returns (uint256);

    function remove_liquidity_one_coin(
        uint256 lpAmount,
        uint256 i,
        uint256 minAmount
    ) external returns (uint256);

    function remove_liquidity_one_coin(
        address pool,
        uint256 lpAmount,
        int128 i,
        uint256 minAmount
    ) external returns (uint256);

    function remove_liquidity_one_coin(
        address pool,
        uint256 lpAmount,
        uint256 i,
        uint256 minAmount
    ) external returns (uint256);

    // lending pool & crypto pool, reuse boolean indicator for useUnderlying or isETH
    function add_liquidity(
        uint256[2] calldata amounts,
        uint256 minMintAmount,
        bool boolIndicator
    ) external payable returns (uint256);

    function add_liquidity(
        uint256[3] calldata amounts,
        uint256 minMintAmount,
        bool boolIndicator
    ) external payable returns (uint256);

    function add_liquidity(
        uint256[4] calldata amounts,
        uint256 minMintAmount,
        bool boolIndicator
    ) external payable returns (uint256);

    function remove_liquidity(
        uint256 amount,
        uint256[2] calldata minAmounts,
        bool boolIndicator
    ) external returns (uint256[2] memory);

    function remove_liquidity(
        uint256 amount,
        uint256[3] calldata minAmounts,
        bool boolIndicator
    ) external returns (uint256[3] memory);

    function remove_liquidity(
        uint256 amount,
        uint256[4] calldata minAmounts,
        bool boolIndicator
    ) external returns (uint256[4] memory);

    function remove_liquidity_one_coin(
        uint256 lpAmount,
        int128 i,
        uint256 minAmount,
        bool boolIndicator
    ) external returns (uint256);

    function remove_liquidity_one_coin(
        uint256 lpAmount,
        uint256 i,
        uint256 minAmount,
        bool boolIndicator
    ) external returns (uint256);

    //cryto pool

    function calc_withdraw_one_coin(
        uint256 amount,
        int128 i
    ) external returns (uint256);

    function calc_withdraw_one_coin(
        uint256 amount,
        uint256 i
    ) external returns (uint256);

    function calc_withdraw_one_coin(
        address pool,
        uint256 amount,
        int128 i
    ) external returns (uint256);

    function calc_withdraw_one_coin(
        address pool,
        uint256 amount,
        uint256 i
    ) external returns (uint256);


    function balances(uint256 i) external view returns (uint256);
    
    function balances(int128 i) external view returns (uint256);
}
