// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IRelayerHub} from "./interfaces/IRelayerHub.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title FeeManager
 * @dev Contract to manage service and relayer fees in a darkpool.
 */
contract FeeManager is Ownable {
    using SafeERC20 for IERC20;

    uint256 private _serviceFeePercent;
    address private _relayerHub;

    uint256 private constant _PRECISION = 1000000;

    event ServiceFeePercentSet(uint256 feePercent);

    /**
     * @dev Constructor sets the initial owner and the Relayer Hub address.
     * @param initialOwner Address of the initial owner.
     * @param relayerHub Address of the Relayer Hub contract.
     */
    constructor(
        address initialOwner,
        address relayerHub
    ) Ownable(initialOwner) {
        _relayerHub = relayerHub;
        _serviceFeePercent = 300; // 0.03%
    }

    /**
     * @dev Allows the contract to receive Ether.
     */
    receive() external payable {}

    /**
     * @dev Fallback function to receive Ether.
     */
    fallback() external payable {}

    /**
     * @dev Sets the service fee.
     * @param feePercent New service fee percent (default 300 as 0.03%).
     */
    function setServiceFeePercent(uint256 feePercent) external onlyOwner {
        require(
            feePercent <= _PRECISION,
            "FeeManager: fee percent must be less than or equal to 100%"
        );

        _serviceFeePercent = feePercent;
        emit ServiceFeePercentSet(feePercent);
    }

    /**
     * @dev Sets the Relayer Hub address.
     * @param relayerHub New Relayer Hub address.
     */
    function setRelayerHub(address relayerHub) external onlyOwner {
        _relayerHub = relayerHub;
    }

    /**
     * @dev Releases the specified asset to a recipient. Supports both ERC20 tokens and Ether.
     * Can only be called by the owner.
     * @param asset The asset's contract address, or zero address for Ether.
     * @param to Recipient address.
     * @param amount Amount of asset to release.
     */
    function release(
        address asset,
        address to,
        uint256 amount
    ) external onlyOwner {
        require(amount > 0, "FeeManager: amount must be greater than 0");

        if (
            asset == address(0) ||
            asset == address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)
        ) {
            _releaseETH(payable(to), amount);
        } else {
            _releaseERC20(asset, to, amount);
        }
    }

    /**
     * @dev Calculates the final amount after deducting service and relayer fees.
     * @param amount Initial amount before fees.
     * @param relayerRefund Relayer refund amount.
     * @return Tuple containing the final amount, service charge, and relayer fee.
     */
    function calculateFee(
        uint256 amount,
        uint256 relayerRefund
    ) external view returns (uint256, uint256, uint256) {
        return _calculateFee(amount, relayerRefund, _serviceFeePercent);
    }

    /**
     * @dev Calculates the final amount after deducting service and relayer fees.
     * @param amount Initial amount before fees.
     * @param relayerRefund Relayer refund amount.
     * @param serviceFeePercent Service fee percent.
     * @return Tuple containing the final amount, service charge, and relayer fee.
     */
    function calculateFeeForceServiceFee(
        uint256 amount,
        uint256 relayerRefund,
        uint256 serviceFeePercent
    ) external pure returns (uint256, uint256, uint256) {
        return _calculateFee(amount, relayerRefund, serviceFeePercent);
    }

    function calculateFee(
        uint256[4] calldata amount,
        uint256[4] calldata relayerRefund
    )
        external
        view
        returns (uint256[4] memory, uint256[4] memory, uint256[4] memory)
    {
        uint256 serviceFeePercent = _serviceFeePercent;
        uint256[4] memory serviceCharge;
        uint256[4] memory actualAmount;
        for (uint256 i = 0; i < 4; i++) {
            //if (amount[i] != 0) {
            serviceCharge[i] = (amount[i] * serviceFeePercent) / _PRECISION;
            require(
                amount[i] >= serviceCharge[i] + relayerRefund[i],
                "FeeManager: amount must be greater than fees"
            );
            actualAmount[i] = amount[i] - serviceCharge[i] - relayerRefund[i];
            //}
        }

        return (actualAmount, serviceCharge, relayerRefund);
    }

    function calculateFeeForFSN(
        uint256[4] calldata amount,
        uint256[4] calldata relayerRefund
    )
        external
        view
        returns (uint256[] memory, uint256[4] memory, uint256[4] memory)
    {
        uint256 serviceFeePercent = _serviceFeePercent;
        uint256[4] memory serviceCharge;
        uint256[] memory actualAmount = new uint256[](4);
        for (uint256 i = 0; i < 4; i++) {
            //if (amount[i] != 0) {
            serviceCharge[i] = (amount[i] * serviceFeePercent) / _PRECISION;
            require(
                amount[i] >= serviceCharge[i] + relayerRefund[i],
                "FeeManager: amount must be greater than fees"
            );
            actualAmount[i] = amount[i] - serviceCharge[i] - relayerRefund[i];
            //}
        }

        return (actualAmount, serviceCharge, relayerRefund);
    }

    /**
     * @dev Returns the current service fee.
     */
    function getServiceFeePercent() external view returns (uint256) {
        return _serviceFeePercent;
    }

    /**
     * @dev Returns the current Relayer Hub address.
     */
    function getRelayerHub() external view returns (address) {
        return _relayerHub;
    }

    /**
     * @dev Internal function to calculate the final amount after deducting service and relayer fees.
     * @param amount Initial amount before fees.
     * @param relayerRefund Relayer refund amount.
     * @param serviceFeePercent Service fee percent.
     * @return tuple containing the final amount, service charge, and relayer fee.
     */
    function _calculateFee(
        uint256 amount,
        uint256 relayerRefund,
        uint256 serviceFeePercent
    ) internal pure returns (uint256, uint256, uint256) {
        uint256 serviceCharge = (amount * serviceFeePercent) / _PRECISION;

        require(
            amount >= serviceCharge + relayerRefund,
            "FeeManager: amount must be greater or equals to fees"
        );

        return (
            amount - serviceCharge - relayerRefund,
            serviceCharge,
            relayerRefund
        );
    }

    /**
     * @dev Internal function to release Ether to a recipient.
     * @param to Recipient address.
     * @param amount Amount of Ether to release.
     */
    function _releaseETH(address payable to, uint256 amount) internal {
        require(
            address(this).balance >= amount,
            "FeeManager: Insufficient ETH balance"
        );

        (bool success, ) = to.call{value: amount}("");
        require(success, "FeeManager: release to recipient failed");
    }

    /**
     * @dev Internal function to release ERC20 tokens to a recipient.
     * @param token Token contract address.
     * @param to Recipient address.
     * @param amount Amount of tokens to release.
     */
    function _releaseERC20(address token, address to, uint256 amount) internal {
        require(
            IERC20(token).balanceOf(address(this)) >= amount,
            "FeeManager: Insufficient ERC20 balance"
        );

        IERC20(token).safeTransfer(to, amount);
    }
}
