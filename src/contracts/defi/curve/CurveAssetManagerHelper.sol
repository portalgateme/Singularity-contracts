// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {IMetaRegistry} from "./interfaces/IMetaRegistry.sol";
import {IMetaFactoryRegistry} from "./interfaces/IMetaFactoryRegistry.sol";
import {ILPToken} from "./interfaces/ILPToken.sol";
import {IPools} from "./interfaces/IPools.sol";
import {IWETH9} from "../../core/interfaces/IWETH9.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title CurveAssetManagerHelper
 * @dev Helper contract for CurveAssetManager.
 */
contract CurveAssetManagerHelper {
    using SafeERC20 for IERC20;

    address internal constant _META_REGISTRY =
        0xF98B45FA17DE75FB1aD0e7aFD971b0ca00e379fC;
    address internal constant _META_FACTORY_REGISTRY =
        0x6A8cbed756804B16E05E741eDaBd5cB544AE21bf;
    address internal constant _3POOL_ZAP = 
        0xA79828DF1850E8a3A3064576f380D90aECDD3359;
    address internal constant _FRAXUSDC_ZAP = 
        0x08780fb7E580e492c1935bEe4fA5920b94AA95Da;
    address internal constant _WETH_ADDRESS =
        0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address private constant _ETH_ADDRESS =
        0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public constant ADDRESS_PROVIDER =
        0x0000000022D53366457F9d5E68Ec105046FC4383;
    address public constant ROUTER_PROVIDER =
        0xF0d4c12A5768D806021F80a262B4d39d26C58b8D;

    event CurveExchange(
        bytes32 nullifiers,
        address assetOut,
        uint256 amountOut,
        bytes32 noteOut,
        bytes32 noteFooter
    );

    event CurveAddLiquidity(
        bytes32[4] nullifiers,
        address asset,
        uint256 amountOut,
        bytes32 noteOut,
        bytes32 noteFooter
    );

    event CurveRemoveLiquidity(
        bytes32 nullifier,
        address[5] assets,
        uint256[5] amountsOut,
        bytes32[5] notesOut,
        bytes32[5] noteFooters
    );

    error AmountNotCorrect();
    error PoolNotSupported();
    error LpTokenNotCorrect();
    error AssetNotInPool();
    error FunctionNotSupported();
    error ETHtransferFailed();
    error RouteHashNotCorrect();
    error RouteNotCorrect();
    //error NoteFooterDuplicated();

    /**
     * @dev Function to transfer services fees and gas refunds to the fee manager and relayer.
     * @param assets Array of asset addresses. One to one mapping with curve pool coins.
     * @param serviceFees Array of service fees to be transferred to the fee manager.
     * @param gasRefund Array of gas refunds to be transferred to the relayer.
     * @param feeManager Address of the fee manager.
     * @param relayer Address of the relayer.
     */
    function _transferFees(
        address[4] memory assets,
        uint256[4] memory serviceFees,
        uint256[4] memory gasRefund,
        address feeManager,
        address relayer
    ) internal {
        for (uint256 i = 0; i < 4; i++) {
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

    function _wrapEth(
        address[4] memory assets,
        uint256[4] memory amounts
    ) internal {
        for (uint256 i = 0; i < 4; i++) {
            if (assets[i] == _ETH_ADDRESS && amounts[i] > 0) {
                _wrapEth(amounts[i]);
                break;
            }
        }
    }

    function _wrapEth(uint256 amount) internal {
        if (amount > 0) {
            IWETH9(_WETH_ADDRESS).deposit{value: amount}();
        }
    }

    function _unWrapEth(
        address[4] memory assets,
        uint256[4] memory amounts
    ) internal {
        for (uint256 i = 0; i < 4; i++) {
            if (assets[i] == _ETH_ADDRESS && amounts[i] > 0) {
                IWETH9(_WETH_ADDRESS).withdraw(amounts[i]);
                break;
            }
        }
    }

    function _getCoinNum(address pool) 
        internal view returns (uint256) {
        return IMetaRegistry(_META_REGISTRY).get_n_coins(pool);
    }

    function _getUnderlyingCoinNum( address pool)
        internal view returns (uint256) {
        return IMetaRegistry(_META_REGISTRY).get_n_underlying_coins(pool);
    }

    function _getMetaFactoryCoinNum(
        address pool
    ) internal view returns (uint256) {
        return IMetaFactoryRegistry(_META_FACTORY_REGISTRY).get_n_coins(pool);
    }

    function _getCoins(
        address pool
    ) internal view returns (address[8] memory) {
        return IMetaRegistry(_META_REGISTRY).get_coins(pool);
    }

    function _getMetaFactoryCoins(
        address pool
    ) internal view returns (address[] memory) {
        return IMetaFactoryRegistry(_META_FACTORY_REGISTRY).get_coins(pool);
    }

    function _getLPToken(
        address pool
    ) internal view returns (address) {
        return IMetaRegistry(_META_REGISTRY).get_lp_token(pool);
    }

    function _getUnderlyingCoins(
        address pool
    ) internal view returns (address[8] memory) {
        return IMetaRegistry(_META_REGISTRY).get_underlying_coins(pool);
    }

    function _getBasePool(
        address pool
    ) internal view returns (address) {
        return IMetaRegistry(_META_REGISTRY).get_base_pool(pool);
    }

    /**
     * @dev Function to calculate the expected amounts of coins to be received after removing liquidity.
     * @param coinNum Number of coins in the curve pool.
     * @param pool Address of the curve pool.
     * @param lpToken Address of the LP token.
     * @param lpAmount Amount of LP tokens to be burned
     * @return expectedAmounts Array of expected amounts of coins to be received.
     
    function _caculateExpectedAmounts(
        uint256 coinNum,
        address pool,
        address lpToken,
        uint256 lpAmount
    ) internal view returns (uint256[4] memory) {
        uint256[4] memory expectedAmounts;
        uint256 totalSupply = ILPToken(lpToken).totalSupply();
        // very strange situations that some of the curve pool take int128 instead of uint256, 
        // might due to the vyper version
        for (uint128 i = 0; i < coinNum; i++) {
            try IPools(pool).balances(uint256(i)) returns (uint256 result) {
                expectedAmounts[i] =
                    (((result * lpAmount) / totalSupply) / 100) * 95;
            } catch {
                expectedAmounts[i] = 
                    (((IPools(pool).balances(int128(i)) * lpAmount) / totalSupply) 
                    / 100) * 95;
            }
        }
        return expectedAmounts;
    }*/

    /**
     * @dev Function to calculate the expected amounts of underlying coins to be received 
     *      after removing liquidity from metapool.
     * @param coinNum Number of coins in the meta pool.
     * @param pool Address of the curve pool.
     * @param lpToken Address of the LP token.
     * @param lpAmount Amount of LP tokens to be burned
     * @return expectedAmounts Array of expected amounts of coins to be received.
     
    function _caculateExpectedAmountsForMeta(
        uint256 coinNum,
        address pool,
        address lpToken,
        uint256 lpAmount
    ) internal view returns (uint256[4] memory) {
        uint256[4] memory expectedAmounts;
        uint256[4] memory baseExpectedAmounts;

        expectedAmounts =  _caculateExpectAmounts(coinNum, pool, lpToken, lpAmount);
       
        address basePool = _getBasePool(pool);
        uint256 basePoolCoinNum = _getCoinNum(basePool);
        address basePoolLPToken = _getLPToken(basePool); 

        baseExpectedAmounts = 
            _caculateExpectAmounts(basePoolCoinNum, basePool, basePoolLPToken, expectedAmounts[1]);
        
        for (uint256 i = coinNum - 1; i < 4; i++) {
            expectedAmounts[i] = baseExpectedAmounts[i-1];
        }

        return expectedAmounts;
    }*/



    /**
     * @dev Function to validate whether given assets are in the curve pool.
     * @param coins Array of curve pool coin addresses.
     * @param assets Array of asset addresses.
     * @return Boolean indicating the validation status.
     */
    function _validateAssets(
        address[8] memory coins,
        address[4] memory assets
    ) internal pure returns (bool) {
        for (uint256 i = 0; i < 4; i++) {
            //if (coins[i] == address(0)) {
            //    continue;
            //}
            if (assets[i] != address(0)) {
                if (assets[i] != coins[i]) {
                    if (
                        assets[i] == _ETH_ADDRESS && coins[i] == _WETH_ADDRESS
                    ) {
                        continue;
                    }
                    return false;
                }
            }
        }
        return true;
    }

    function _validateAssets(
        address[] memory coins,
        address[4] memory assets
    ) internal pure returns (bool) {
        for (uint256 i = 0; i < (coins.length > 4 ? 4 : coins.length); i++) {
            //if (coins[i] == address(0)) {
            //    continue;
            //}
            if (assets[i] != address(0)) {
                if (assets[i] != coins[i]) {
                    if (
                        assets[i] == _ETH_ADDRESS && coins[i] == _WETH_ADDRESS
                    ) {
                        continue;
                    }
                    return false;
                }
            }
        }
        return true;
    }

    /**
     * @dev Function to count the number of non-zero elements in the array.
     * @param array Array of addresses.
     * @return count Number of non-zero elements.
     * @return position Position of the last non-zero element.
     */
    function _countNonZeroElements(
        address[4] memory array
    ) internal pure returns (uint256, uint128) {
        uint256 count;
        uint128 position;
        for (uint128 i = 0; i < 4; i++) {
            if (array[i] != address(0)) {
                count++;
                position = i;
            }
        }
        return (count, position);
    }
        function _validateNoteFooterDuplication(bytes32[5] memory footers) 
            internal pure returns (bool) {
        for (uint i = 0; i < 5; i++) {
            if (footers[i] != bytes32(0)) {
                for (uint j = i + 1; j < 5; j++) {
                    if (footers[i] == footers[j]) {
                        return true;
                    }
                }
            }
        }
        return false;
    }
}
