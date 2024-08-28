// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

interface IAerodromeRouter {
    struct Route {
        address from;
        address to;
        bool stable;
        address factory;
    }

    /** @dev Struct containing information necessary to zap in and out of pools
        @param tokenA           .
        @param tokenB           .
        @param stable           Stable or volatile pool
        @param factory          factory of pool
        @param amountOutMinA    Minimum amount expected from swap leg of zap via routesA
        @param amountOutMinB    Minimum amount expected from swap leg of zap via routesB
        @param amountAMin       Minimum amount of tokenA expected from liquidity leg of zap
        @param amountBMin       Minimum amount of tokenB expected from liquidity leg of zap
    */
    struct Zap {
        address tokenA;
        address tokenB;
        bool stable;
        address factory;
        uint256 amountOutMinA;
        uint256 amountOutMinB;
        uint256 amountAMin;
        uint256 amountBMin;
    }

    /** 
        @notice Add liquidity of two tokens to a Pool
        @param tokenA           .
        @param tokenB           .
        @param stable           True if pool is stable, false if volatile
        @param amountADesired   Amount of tokenA desired to deposit
        @param amountBDesired   Amount of tokenB desired to deposit
        @param amountAMin       Minimum amount of tokenA to deposit
        @param amountBMin       Minimum amount of tokenB to deposit
        @param to               Recipient of liquidity token
        @param deadline         Deadline to receive liquidity
        @return amountA         Amount of tokenA to actually deposit
        @return amountB         Amount of tokenB to actually deposit
        @return liquidity       Amount of liquidity token returned from deposit
    */
    function addLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity);

    /**  @notice Add liquidity of a token and WETH (transferred as ETH) to a Pool
        @param token                .
        @param stable               True if pool is stable, false if volatile
        @param amountTokenDesired   Amount of token desired to deposit
        @param amountTokenMin       Minimum amount of token to deposit
        @param amountETHMin         Minimum amount of ETH to deposit
        @param to                   Recipient of liquidity token
        @param deadline             Deadline to add liquidity
        @return amountToken         Amount of token to actually deposit
        @return amountETH           Amount of tokenETH to actually deposit
        @return liquidity           Amount of liquidity token returned from deposit
    */
    function addLiquidityETH(
        address token,
        bool stable,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external payable returns (uint256 amountToken, uint256 amountETH, uint256 liquidity);

    /**
        @notice Remove liquidity of two tokens from a Pool
        @param tokenA       .
        @param tokenB       .
        @param stable       True if pool is stable, false if volatile
        @param liquidity    Amount of liquidity to remove
        @param amountAMin   Minimum amount of tokenA to receive
        @param amountBMin   Minimum amount of tokenB to receive
        @param to           Recipient of tokens received
        @param deadline     Deadline to remove liquidity
        @return amountA     Amount of tokenA received
        @return amountB     Amount of tokenB received
    */
    function removeLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB);

    /**
        @notice Remove liquidity of a token and WETH (returned as ETH) from a Pool
        @param token            .
        @param stable           True if pool is stable, false if volatile
        @param liquidity        Amount of liquidity to remove
        @param amountTokenMin   Minimum amount of token to receive
        @param amountETHMin     Minimum amount of ETH to receive
        @param to               Recipient of liquidity token
        @param deadline         Deadline to receive liquidity
        @return amountToken     Amount of token received
        @return amountETH       Amount of ETH received
    */
    function removeLiquidityETH(
        address token,
        bool stable,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountToken, uint256 amountETH);

    /**
        @notice Swap one token for another
        @param amountIn     Amount of token in
        @param amountOutMin Minimum amount of desired token received
        @param routes       Array of trade routes used in the swap
        @param to           Recipient of the tokens received
        @param deadline     Deadline to receive tokens
        @return amounts     Array of amounts returned per route
    */
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        Route[] calldata routes,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
    /**
        @notice Swap ETH for a token
        @param amountOutMin Minimum amount of desired token received
        @param routes       Array of trade routes used in the swap
        @param to           Recipient of the tokens received
        @param deadline     Deadline to receive tokens
        @return amounts     Array of amounts returned per route
    */
    function swapExactETHForTokens(
        uint256 amountOutMin,
        Route[] calldata routes,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);
    /**
        @notice Swap a token for WETH (returned as ETH)
        @param amountIn     Amount of token in
        @param amountOutMin Minimum amount of desired ETH
        @param routes       Array of trade routes used in the swap
        @param to           Recipient of the tokens received
        @param deadline     Deadline to receive tokens
        @return amounts     Array of amounts returned per route
    */
    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        Route[] calldata routes,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    /**
        @notice Zap a token A into a pool (B, C). (A can be equal to B or C).
                Supports standard ERC20 tokens only (i.e. not fee-on-transfer tokens etc).
                Slippage is required for the initial swap.
                Additional slippage may be required when adding liquidity as the
                price of the token may have changed.
        @param tokenIn      Token you are zapping in from (i.e. input token).
        @param amountInA    Amount of input token you wish to send down routesA
        @param amountInB    Amount of input token you wish to send down routesB
        @param zapInPool    Contains zap struct information. See Zap struct.
        @param routesA      Route used to convert input token to tokenA
        @param routesB      Route used to convert input token to tokenB
        @param to           Address you wish to mint liquidity to.
        @param stake        Auto-stake liquidity in corresponding gauge.
        @return liquidity   Amount of LP tokens created from zapping in.
    */
    function zapIn(
        address tokenIn,
        uint256 amountInA,
        uint256 amountInB,
        Zap calldata zapInPool,
        Route[] calldata routesA,
        Route[] calldata routesB,
        address to,
        bool stake
    ) external payable returns (uint256 liquidity);
    /**
        @notice Zap out a pool (B, C) into A.
                Supports standard ERC20 tokens only (i.e. not fee-on-transfer tokens etc).
                Slippage is required for the removal of liquidity.
                Additional slippage may be required on the swap as the
                price of the token may have changed.
        @param tokenOut     Token you are zapping out to (i.e. output token).
        @param liquidity    Amount of liquidity you wish to remove.
        @param zapOutPool   Contains zap struct information. See Zap struct.
        @param routesA      Route used to convert tokenA into output token.
        @param routesB      Route used to convert tokenB into output token.
    */
    function zapOut(
        address tokenOut,
        uint256 liquidity,
        Zap calldata zapOutPool,
        Route[] calldata routesA,
        Route[] calldata routesB
    ) external;
    
    /** 
        @notice Calculate the address of a pool by its' factory.
                Used by all Router functions containing a `Route[]` or `_factory` argument.
                 Reverts if _factory is not approved by the FactoryRegistry
        @dev Returns a randomly generated address for a nonexistent pool
        @param tokenA   Address of token to query
        @param tokenB   Address of token to query
        @param stable   True if pool is stable, false if volatile
        @param _factory Address of factory which created the pool
    */
    function poolFor(
        address tokenA,
        address tokenB,
        bool stable,
        address _factory
    ) external view returns (address pool);

    /**
        @notice Sort two tokens by which address value is less than the other
        @param tokenA   Address of token to sort
        @param tokenB   Address of token to sort
        @return token0  Lower address value between tokenA and tokenB
        @return token1  Higher address value between tokenA and tokenB
    */
    function sortTokens(address tokenA, address tokenB) 
        external pure returns (address token0, address token1);
}