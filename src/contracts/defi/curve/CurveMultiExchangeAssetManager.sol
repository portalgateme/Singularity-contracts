// SPDX-License-Identifier: MIT

pragma solidity >=0.8.20;

import {BaseAssetManager} from "../../core/base/BaseAssetManager.sol";
import {CurveInputBuilder} from "./CurveInputBuilder.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IMultiExchange} from "./interfaces/IMultiExchange.sol";
import {IPools} from "./interfaces/IPools.sol";
import {IAssetPool} from "../../core/interfaces/IAssetPool.sol";
import {ILPToken} from "./interfaces/ILPToken.sol";
import {CurveAssetManagerHelper} from "./CurveAssetManagerHelper.sol";

/**
 * @title CurveMultiExchangeAssetManager
 * @dev To exchange assets via curve router, up to 5 swaps.
 */
contract CurveMultiExchangeAssetManager is BaseAssetManager, CurveInputBuilder, CurveAssetManagerHelper {
    using SafeERC20 for IERC20;

    /**
     * @dev Struct to hold exchange arguments.
     * @param merkleRoot Merkle root of the note.
     * @param nullifier Nullifier of the note.
     * @param assetIn Address of the asset to be exchanged.
     * @param amountIn Amount of the asset to be exchanged.
     * @param route Array of addresses of the assets and pools to be used for the exchange.
     * @param swapParams Array of swap parameters of each swap/pool.
     * @param pools Array of pool addresses.
     * @param routeHash Hash of the route, swapParameter and pools.
     * @param assetOut Address of the asset to be received.
     * @param minExpectedAmountOut Minimum expected amount of the asset to be received.
     * @param noteFooter partial note to be used to build notes for out asset.
     * @param relayer Address of the relayer.
     * @param gasRefund Amount to be refunded to the relayer.
     */
    struct ExchangeArgs {
        bytes32 merkleRoot;
        bytes32 nullifier;
        address assetIn;
        uint256 amountIn;
        address[11] route;
        uint256[5][5] swapParams;
        address[5] pools;
        bytes32 routeHash;
        address assetOut;
        uint256 minExpectedAmountOut;
        bytes32 noteFooter;
        address payable relayer;
        uint256 gasRefund;
    }

    constructor(
        address assetPoolERC20,
        address assetPoolERC721,
        address assetPoolETH,
        address verifierHub,
        address relayerHub,
        address feeManager,
        address complianceManager,
        address merkleTreeOperator,
        address mimc254,
        address initialOwner
    )
        BaseAssetManager(
            assetPoolERC20,
            assetPoolERC721,
            assetPoolETH,
            verifierHub,
            relayerHub,
            feeManager,
            complianceManager,
            merkleTreeOperator,
            mimc254,
            initialOwner
        )
        CurveInputBuilder(P)
    {}

    /**
     * @dev Function to exchange assets via curve router, up to 5 swaps,
     *      checks all the requirements and verifies the ZK proof,
     *      release asset from the corresponding asset pool,
     *      exchange assets via curve router,
     *      deposit asset back to the corresponding asset pool,
     *      calculate fees and refunds,
     *      transfer fees and refunds to the fee manager and relayer,
     *      build note for the out asset,
     * @param _proof ZK proof of the whole user story.
     * @param _args Exchange arguments.
     */
    function curveMultiExchange(
        bytes calldata _proof,
        ExchangeArgs calldata _args
    ) external payable {
        _validateRelayerIsRegistered(_args.relayer);
        if(msg.sender != _args.relayer) {
            revert RelayerMismatch();
        }
        _validateNullifierIsNotUsed(_args.nullifier);
        _validateNullifierIsNotLocked(_args.nullifier);
        _validateMerkleRootIsAllowed(_args.merkleRoot);
        _validateNoteFooterIsNotUsed(_args.noteFooter);

        if (_args.amountIn == 0) {
            revert AmountNotCorrect();
        }
        
        _assertRoute(_args.assetIn, _args.assetOut, _args.route);
        _assertRouteHash(_args.routeHash, _args.route, _args.swapParams, _args.pools);

        _verifyProof(
            _proof,
            _buildMultiExchangeInputs(
                MulitExchangeRawInputs(
                    _args.merkleRoot,
                    _args.nullifier,
                    _args.assetIn,
                    _args.amountIn,
                    _args.routeHash,
                    _args.assetOut,
                    _args.minExpectedAmountOut,
                    _args.noteFooter,
                    _args.relayer
                )
            ),
            "curveMultiExchange"
        );

        uint256 amountToExchange;
        uint256 serviceFee;

        (amountToExchange, serviceFee, ) = _feeManager.calculateFee(
            _args.amountIn,
            _args.gasRefund
        );

        _postWithdraw(_args.nullifier);
        _registerNoteFooter(_args.noteFooter);

        //uint256 amountOut = IMultiExchange(ROUTER_PROVIDER).get_dy(
        //    _args.route,
        //    _args.swapParams,
        //    amountToExchange,
        //    _args.pools
        //);

        //amountOut = (amountOut / 100) * 95;
        uint256 amountOut;

        if (_args.assetIn == ETH_ADDRESS) {
            _assetPoolETH.release(payable(address(this)), _args.amountIn);
            amountOut = IMultiExchange(ROUTER_PROVIDER).exchange{
                value: amountToExchange
            }(
                _args.route,
                _args.swapParams,
                amountToExchange,
                _args.minExpectedAmountOut * 95 / 100,
                _args.pools
            );
        } else {
            _assetPoolERC20.release(
                _args.assetIn,
                address(this),
                _args.amountIn
            );
            IERC20(_args.assetIn).forceApprove(ROUTER_PROVIDER, _args.amountIn);
            amountOut = IMultiExchange(ROUTER_PROVIDER).exchange(
                _args.route,
                _args.swapParams,
                amountToExchange,
                _args.minExpectedAmountOut * 95 / 100,
                _args.pools
            );
        }

        bool success;
        if (_args.assetOut == ETH_ADDRESS) {
            (success, ) = payable(address(_assetPoolETH)).call{
                value: amountOut}("");
            if (!success) {
                revert ETHtransferFailed();
            }
        } else {
            IERC20(_args.assetOut).safeTransfer(
                address(_assetPoolERC20),
                amountOut
            );
        }
        
        if (_args.assetIn == ETH_ADDRESS) {
            (success, ) = payable(address(_feeManager)).call{
                value: serviceFee}("");
            if (!success) {
                revert ETHtransferFailed();
            }
            (success, ) = payable(address(_args.relayer)).call{
                value: _args.gasRefund}("");
            if (!success) {
                revert ETHtransferFailed();
            }
        } else {
            IERC20(_args.assetIn).safeTransfer(
                address(_feeManager),
                serviceFee
            );
            IERC20(_args.assetIn).safeTransfer(
                address(_args.relayer),
                _args.gasRefund
            );
        }

        bytes32 noteCommitment = _buildNoteForERC20(
            _args.assetOut,
            amountOut,
            _args.noteFooter
        );
        _postDeposit(noteCommitment);

        emit CurveExchange(
            _args.nullifier,
            _args.assetOut,
            amountOut,
            noteCommitment,
            _args.noteFooter
        );
    }

    function _assertRouteHash(
        bytes32 routeHash, 
        address[11] memory route, 
        uint256[5][5] memory swapParams ,
        address[5] memory pools) private pure 
    {
            uint256 sp;
            for (uint256 i = 0; i < 5; i++) {
                for (uint256 j = 0; j < 5; j++) {
                    sp = sp * 10 + swapParams[i][j];
                }
            }

            bytes32 ph = keccak256(
                abi.encode(
                    pools[0],
                    pools[1],
                    pools[2],
                    pools[3],
                    pools[4]
                )
            );

            bytes32 rh = keccak256(
                abi.encode(
                    route[0],
                    route[1],
                    route[2],
                    route[3],
                    route[4],
                    route[5],
                    route[6],
                    route[7],
                    route[8],
                    route[9],
                    route[10]
                )
            );

            bytes32 h = keccak256(
                abi.encode(
                    rh,
                    ph,
                    sp
                )
            );

        if (h != routeHash) {
            revert RouteHashNotCorrect();
        }
    }

    function _assertRoute(
        address assetIn,
        address assetOut,
        address[11] memory route
    ) private pure {
        if (assetIn != route[0]) {
            revert RouteNotCorrect();
        }
        for (uint256 i = 10; i > 0; i--) {
            if (route[i] == address(0)) {
                continue;
            } else {
                if (route[i] != assetOut) {
                    revert RouteNotCorrect();
                }
                return;
            }
        }
        revert RouteNotCorrect();
    }
}
