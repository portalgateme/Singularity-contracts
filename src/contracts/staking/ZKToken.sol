// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title ZKToken Contract
/// @notice ERC20 token with minting and burning capabilities restricted to the staking asset manager
contract ZKToken is ERC20 {
    /// @notice The address of the underlying token
    address public immutable underlyingToken;

    /// @notice The address of the staking asset manager
    address public immutable stakingAssetManager;

    /// @notice The number of decimals for the token
    uint8 private _decimals;

    /// @notice Error thrown when the caller is not the staking asset manager
    error NotStakingAssetManager();

    /// @notice Modifier to restrict functions to only the staking asset manager
    modifier onlyStakingAssetManager() {
        if (msg.sender != stakingAssetManager) {
            revert NotStakingAssetManager();
        }
        _;
    }

    /**
     * @notice Constructor to initialize the ZKToken contract
     * @param name The name of the token
     * @param symbol The symbol of the token
     * @param underlyingDecimals The number of decimals for the token
     * @param underlyingToken_ The address of the underlying token
     * @param stakingAssetManager_ The address of the staking asset manager
     */
    constructor(
        string memory name,
        string memory symbol,
        uint8 underlyingDecimals,
        address underlyingToken_,
        address stakingAssetManager_
    ) ERC20(name, symbol) {
        _decimals = underlyingDecimals;
        underlyingToken = underlyingToken_;
        stakingAssetManager = stakingAssetManager_;
    }

    /**
     * @notice Mints new tokens
     * @param to The address to receive the minted tokens
     * @param amount The amount of tokens to mint
     * @dev Can only be called by the staking asset manager
     */
    function mint(address to, uint256 amount) external onlyStakingAssetManager {
        _mint(to, amount);
    }

    /**
     * @notice Burns tokens from a specified address
     * @param from The address from which to burn tokens
     * @param amount The amount of tokens to burn
     * @dev Can only be called by the staking asset manager
     */
    function burn(
        address from,
        uint256 amount
    ) external onlyStakingAssetManager {
        _burn(from, amount);
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }
}
