// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

interface IMockDex {
    
    function getAssets() external returns (address[4] memory assets);
    function swap(uint256 amountIn, uint256 minAmount, address caller) 
        external payable returns (uint256);
}