// SPDX-License-Identifier: MIT

pragma solidity >=0.8.20;

interface IFeeManager {
    function calculateFee(
        uint256 amount,
        uint256 relayerRefund
    ) external view returns (uint256, uint256, uint256);

    function calculateFeeForceServiceFee(
        uint256 amount,
        uint256 relayerRefund,
        uint256 serviceFeePercent
    ) external pure returns (uint256, uint256, uint256);

    function calculateFee(
        uint256[4] calldata amount,
        uint256[4] calldata relayerRefund
    )
        external
        view
        returns (uint256[4] memory, uint256[4] memory, uint256[4] memory);

    function calculateFeeForFSN(
        uint256[4] calldata amount,
        uint256[4] calldata relayerRefund
    )
        external
        view
        returns (uint256[] memory, uint256[4] memory, uint256[4] memory);
}
