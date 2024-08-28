// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;
import {IMockDex} from "./IMockDex.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract MockDexSingularityBridge {
    using SafeERC20 for IERC20;

    IMockDex private _mockDex;

    constructor(address mockDex) {
        _mockDex = IMockDex(address(mockDex)); // Replace 'address(0)' with the actual address of the mockDex contract.
    }

    function defiCall(
        uint256[] calldata amountsOrNftIds,
        string calldata defiParameters
    )
        external
        payable
        returns (address[] memory assets, uint256[] memory outAmounts)
    {
        (uint256 amountIn, uint256 minAmountOut) = _decodeDefiParameters(
            defiParameters
        );
        uint256 swapOut = _mockDex.swap{value: amountsOrNftIds[0]}(amountsOrNftIds[0], minAmountOut, address(this));
        IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2).forceApprove(msg.sender, swapOut);
        IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2).safeTransfer(msg.sender, swapOut);
        assets = new address[](4);
        assets[0] = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        assets[1] = address(0);
        assets[2] = address(0);
        assets[3] = address(0);
        outAmounts = new uint256[](4);
        outAmounts[0] = swapOut;
        outAmounts[1] = 0;
        outAmounts[2] = 0;
        outAmounts[3] = 0;
    }

    function getAssets(
        string calldata defiParameters
    ) external returns (address[] memory assets) {
        address[4] memory tmpAddress =  _mockDex.getAssets();
        assets = new address[](4);
        assets[0] = tmpAddress[0];
        assets[1] = tmpAddress[1];
        assets[2] = tmpAddress[2];
        assets[3] = tmpAddress[3];
    }

    function _decodeDefiParameters(
        string calldata defiParameters
    ) internal pure returns (uint256 amountIn, uint256 minAmountOut) {
        // Decode the defiParameters string and return the decoded values.
        bytes memory byteData = bytes(defiParameters);
        (amountIn, minAmountOut) = abi.decode(byteData, (uint256, uint256));
    }

    receive() external payable {}
}
