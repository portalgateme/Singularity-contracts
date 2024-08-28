// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;
import {IWETH9} from "../../core/interfaces/IWETH9.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract MockDex{
    using SafeERC20 for IERC20;

    function swap (uint256 amountIn, uint256 minAmount, address caller) payable
        external returns (uint256){
        IWETH9(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2).deposit{value: amountIn}();
        IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2).forceApprove(caller, amountIn);
        IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2).safeTransfer(caller, amountIn);
        return amountIn;
    }

    function getAssets() external returns (address[4] memory assets){
        return [address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE),
                address(0),
                address(0),
                address(0)];
    }

    receive() external payable {}
}
