// SPDX-License-Identifier: MIT

pragma solidity >=0.8.20;

interface IRocketTokenRETH {    
    function burn(uint256 _rethAmount) external;
    function getEthValue(uint256 _rethAmount) external view returns (uint256);
    function getRethValue(uint256 _ethAmount) external view returns (uint256);
    function getExchangeRate() external view returns (uint256);
}