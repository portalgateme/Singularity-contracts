// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol"; 
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IAerodromePool} from "./interfaces/IAerodromePool.sol";
import {IAerodromeRouter} from "./interfaces/IAerodromeRouter.sol";

contract AerodromeAssetManagerHelper {
    using SafeERC20 for IERC20;
    address private constant _ETH_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public immutable ROUTER;

    error AmountNotCorrect();
    error ETHtransferFailed();
    error RouteHashNotCorrect();
    error RouteNotCorrect();
    error PoolNotCorrect();
    error ZapHashNotCorrect();

    constructor(address routerAddress) {
        ROUTER = routerAddress;
    }
    function _transferFees(
        address[2] memory assets,
        uint256[2] memory serviceFees,
        uint256[2] memory gasRefund,
        address feeManager,
        address relayer
    ) internal {
        for (uint256 i = 0; i < 2; i++) {
            if (assets[i] == _ETH_ADDRESS) {
                (bool success, ) = payable(feeManager).call{
                    value: serviceFees[i]
                }("");
                if (!success) {
                    revert ETHtransferFailed();
                }
                (success, ) = payable(relayer).call{value: gasRefund[i]}("");
                if (!success) {
                    revert ETHtransferFailed();
                }
            } else {
                if (assets[i] != address(0)) {
                    IERC20(assets[i]).safeTransfer(feeManager, serviceFees[i]);
                    IERC20(assets[i]).safeTransfer(relayer, gasRefund[i]);
                }
            }
        }
    }

    function _validateTokens(address[2] memory assets, address pool) internal view {
        (address poolToken1, address poolToken2) = IAerodromePool(pool).tokens();
        (address sortedAsset1, address sortAsset2) = IAerodromeRouter(ROUTER).sortTokens(assets[0], assets[1]);

        if (poolToken1 != sortedAsset1 || poolToken2 != sortAsset2) {
            revert PoolNotCorrect();
        }
    }
    
    function _poolFor(IAerodromeRouter.Zap memory zap) 
        internal view returns (address) {
        return IAerodromeRouter(ROUTER).poolFor(
            zap.tokenA,
            zap.tokenB,
            zap.stable,
            zap.factory);
    }

    function _validateNoteFooterDuplication(bytes32[3] memory footers) 
            internal pure returns (bool) {
        for (uint i = 0; i < 3; i++) {
            if (footers[i] != bytes32(0)) {
                for (uint j = i + 1; j < 3; j++) {
                    if (footers[i] == footers[j]) {
                        return true;
                    }
                }
            }
        }
        return false;
    }

    function _assertRouteHash(
        bytes32 routeHash, 
        IAerodromeRouter.Route[] memory route) internal pure 
    {
            bytes32[] memory rhes = new bytes32[](route.length); 
            for (uint256 i = 0; i < route.length; i++) {
                bytes32 rh = keccak256(
                    abi.encode(
                        route[i].from,
                        route[i].to,
                        route[i].stable,
                        route[i].factory
                    ));
                rhes[i] = rh;
            }
            
            bytes32 h = keccak256(abi.encode(rhes));

        if (h != routeHash) {
            revert RouteHashNotCorrect();
        }
    }

    function _assertZapHash(bytes32 zapHash, IAerodromeRouter.Zap memory zap) 
        internal pure {
        bytes32 zh = keccak256(
                        abi.encode(
                            zap.amountAMin,
                            zap.amountBMin,
                            zap.amountOutMinA,
                            zap.amountOutMinB,
                            zap.factory,
                            zap.stable,
                            zap.tokenA,
                            zap.tokenB
                        ));
            
        if (zh != zapHash) {
            revert ZapHashNotCorrect();
        }
    }
}