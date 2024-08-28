// SPDX-License-Identifier: MIT
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";


pragma solidity ^0.8.20;

contract MockPriceOracle {
    constructor() {}

    function getRateToEth(
        address srcToken,
        bool
    ) external view returns (uint256 weightedRate) {
        uint8 decimals = ERC20(srcToken).decimals();
        return uint256(1 * (10**(36-decimals)));
    }
}