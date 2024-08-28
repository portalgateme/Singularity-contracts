// SPDX-License-Identifier: MIT

pragma solidity >=0.8.20;

import {BaseAssetManager} from "../../core/base/BaseAssetManager.sol";
import {AerodromeInputBuilder} from "./AerodromeInputBuilder.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IAerodromeRouter} from "./interfaces/IAerodromeRouter.sol";
import {IAssetPool} from "../../core/interfaces/IAssetPool.sol";
import {AerodromeAssetManagerHelper} from "./AerodromeAssetManagerHelper.sol";

/**
 * @title AerodromeSwapAssetManager
 * @dev To swap assets via Aerodrome router.
 */
contract AerodromeSwapAssetManager is BaseAssetManager, AerodromeInputBuilder, AerodromeAssetManagerHelper {
    using SafeERC20 for IERC20;

    /**
     * @dev Struct to hold exchange arguments.
     * @param merkleRoot Merkle root of the note.
     * @param nullifier Nullifier of the note.
     * @param assetIn Address of the asset to be swaped.
     * @param amountIn Amount of the asset to be swaped.
     * @param route Array of addresses of the from & to assets, stability and pool factory to be used for the swap.
     * @param routeHash Hash of the route.
     * @param minExpectedAmountOut Minimum expected amount of the asset to be received.
     * @param deadline Deadline for the swap.
     * @param noteFooter partial note to be used to build notes for out asset.
     * @param relayer Address of the relayer.
     * @param gasRefund Amount to be refunded to the relayer.
     */
    struct SwapArgs {
        bytes32 merkleRoot;
        bytes32 nullifier;
        address assetIn;
        uint256 amountIn;
        IAerodromeRouter.Route[] route;
        bytes32 routeHash;
        uint256 minExpectedAmountOut;
        uint256 deadline;
        bytes32 noteFooter;
        address payable relayer;
        uint256 gasRefund;
    }

    event AerodromeSwap(
        bytes32 nullifier,
        address assetOut,
        uint256 amountOut,
        bytes32 noteCommitment,
        bytes32 noteFooter
    );

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
        address initialOwner,
        address router
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
        AerodromeInputBuilder(P)
        AerodromeAssetManagerHelper(router)
    {}

    /**
     * @dev Function to exchange assets via aerodrom router,
     *      checks all the requirements and verifies the ZK proof,
     *      release asset from the corresponding asset pool,
     *      exchange assets via router,
     *      deposit asset back to the corresponding asset pool,
     *      calculate fees and refunds,
     *      transfer fees and refunds to the fee manager and relayer,
     *      build note for the out asset,
     * @param _proof ZK proof of the whole user story.
     * @param _args Swap arguments.
     */
    function aerodromeSwap( bytes calldata _proof, SwapArgs calldata _args ) 
        external payable {
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
        
        if (_args.assetIn != _args.route[0].from) {
            revert RouteNotCorrect();
        }
        _assertRouteHash(_args.routeHash, _args.route);

        _verifyProof(
            _proof,
            _buildSwapInputs(
                SwapRawInputs(
                    _args.merkleRoot,
                    _args.nullifier,
                    _args.assetIn,
                    _args.amountIn,
                    _args.routeHash,
                    _args.minExpectedAmountOut,
                    _args.deadline,
                    _args.noteFooter,
                    _args.relayer
                )
            ),
            "aerodromeSwap"
        );

        address assetOut = _args.route[_args.route.length - 1].to;

        uint256 amountToSwap;
        uint256 serviceFee;

        (amountToSwap, serviceFee, ) = _feeManager.calculateFee(
            _args.amountIn,
            _args.gasRefund
        );

        _postWithdraw(_args.nullifier);
        _registerNoteFooter(_args.noteFooter);

        uint256[] memory amountsOut;

        if (_args.assetIn == ETH_ADDRESS) {
            _assetPoolETH.release(payable(address(this)), _args.amountIn);
            amountsOut = IAerodromeRouter(ROUTER).swapExactETHForTokens{
                value: amountToSwap}(
                _args.minExpectedAmountOut * 95 / 100,
                _args.route, 
                address(this),
                _args.deadline
            );
        } else if (assetOut == ETH_ADDRESS) {
            _assetPoolERC20.release(_args.assetIn, address(this),_args.amountIn);
            IERC20(_args.assetIn).forceApprove(ROUTER, _args.amountIn);
            amountsOut = IAerodromeRouter(ROUTER).swapExactTokensForETH(
                amountToSwap,
                _args.minExpectedAmountOut * 95 / 100,
                _args.route, 
                address(this),
                _args.deadline
            );
        } else {
            _assetPoolERC20.release(_args.assetIn,address(this),_args.amountIn);
            IERC20(_args.assetIn).forceApprove(ROUTER, _args.amountIn);
            amountsOut = IAerodromeRouter(ROUTER).swapExactTokensForTokens(
                amountToSwap,
                _args.minExpectedAmountOut * 95 / 100,
                _args.route, 
                address(this),
                _args.deadline
            );
        }

        uint256 amountOut = amountsOut[amountsOut.length - 1];

        bool success;
        if (assetOut == ETH_ADDRESS) {
            (success, ) = payable(address(_assetPoolETH)).call{
                value: amountOut}("");
            if (!success) {
                revert ETHtransferFailed();
            }
        } else {
            IERC20(assetOut).safeTransfer(
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
            assetOut,
            amountOut,
            _args.noteFooter
        );
        _postDeposit(noteCommitment);

        emit AerodromeSwap(
            _args.nullifier,
            assetOut,
            amountOut,
            noteCommitment,
            _args.noteFooter
        );
    }        
}
