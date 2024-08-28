// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IAerodromePool {

    /// @notice Returns [token0, token1]
    function tokens() external view returns (address, address);

    /// @notice True if pool is stable, false if volatile
    function stable() external view returns (bool);

}