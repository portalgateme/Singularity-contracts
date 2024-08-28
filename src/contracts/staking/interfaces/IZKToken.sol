// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title ZKToken Interface
/// @notice Interface for ZKToken, an ERC20 token with minting and burning capabilities
interface IZKToken is IERC20 {
    /**
     * @notice Mints new tokens
     * @param account The address to receive the minted tokens
     * @param amount The amount of tokens to mint
     */
    function mint(address account, uint256 amount) external;

    /**
     * @notice Burns tokens from a specified address
     * @param account The address from which to burn tokens
     * @param amount The amount of tokens to burn
     */
    function burn(address account, uint256 amount) external;
}
