// SPDX-License-Identifier: MIT

pragma solidity >=0.8.20;

interface IAddressProvider {
    function get_registry() external view returns (address);

    //get_address(1) pool info contract address
    //get_address(2) exchange contract address
    //get_address(3) meta pool factory address
    function get_address(uint256 id) external view returns (address);
}
