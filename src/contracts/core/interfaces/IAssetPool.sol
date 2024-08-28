// SPDX-License-Identifier: MIT

pragma solidity >=0.8.20;

interface IAssetPool {
    function setAssetManager(address assetManager,bool registered) external;

    function release(address tokenOrNft, address to, uint256 amountOrNftId) external;

    function release(address payable to, uint256 amount) external;

    function getAssetManagerRegistration( address assetManager) 
        external view returns(bool);
}