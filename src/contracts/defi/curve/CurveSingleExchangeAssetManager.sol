// SPDX-License-Identifier: MIT

pragma solidity >=0.8.20;

import {BaseAssetManager} from "../../core/base/BaseAssetManager.sol";
import {CurveInputBuilder} from "./CurveInputBuilder.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IAddressProvider} from "./interfaces/IAddressProvider.sol";
import {IExchange} from "./interfaces/IExchange.sol";
import {IPools} from "./interfaces/IPools.sol";
import {IAssetPool} from "../../core/interfaces/IAssetPool.sol";
import {CurveAssetManagerHelper} from "./CurveAssetManagerHelper.sol";

/**
 * @title CurveSingleExchangeAssetManager
 * @dev To swap assets in a curve pool, single swap.
 */
contract CurveSingleExchangeAssetManager is
    BaseAssetManager,
    CurveInputBuilder,
    CurveAssetManagerHelper
{
    using SafeERC20 for IERC20;

    /**
     * @dev Struct to hold exchange arguments.
     * @param merkleRoot Merkle root of the note.
     * @param nullifier Nullifier of the note.
     * @param assetIn Address of the asset to be exchanged.
     * @param amountIn Amount of the asset to be exchanged.
     * @param pool Address of the pool to be used for the exchange.
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
        address pool;
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
     *      swap asset,
     *      deposit asset back to the corresponding asset pool,
     *      calculate fees and refunds,
     *      transfer fees and refunds to the fee manager and relayer,
     *      build note for the out asset,
     * @param _proof ZK proof of the whole user story.
     * @param _args Exchange arguments.
     */
    function curveSingleExchange(
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
        
        _verifyProof(
            _proof,
            _buildExchangeInputs(
                ExchangeRawInputs(
                    _args.merkleRoot,
                    _args.nullifier,
                    _args.assetIn,
                    _args.amountIn,
                    _args.pool,
                    _args.assetOut,
                    _args.minExpectedAmountOut,
                    _args.noteFooter,
                    _args.relayer
                )
            ),
            "curveExchange"
        );
        if (_args.amountIn == 0) {
            revert AmountNotCorrect();
        }

        uint256 amountToExchange;
        uint256 serviceFee;

        (amountToExchange, serviceFee, ) = _feeManager.calculateFee(
            _args.amountIn,
            _args.gasRefund
        );

        _postWithdraw(_args.nullifier);
        _registerNoteFooter(_args.noteFooter);

        address exchangeContract = IAddressProvider(ADDRESS_PROVIDER)
            .get_address(2);
        //uint256 amountOut = IExchange(exchangeContract).get_exchange_amount(
        //    _args.pool,
        //    _args.assetIn,
        //    _args.assetOut,
        //    amountToExchange
        //);
        //amountOut = (amountOut / 100) * 95;

        uint256 amountOut;
        if (_args.assetIn == ETH_ADDRESS) {
            _assetPoolETH.release(payable(address(this)), _args.amountIn);
            amountOut = IExchange(exchangeContract).exchange{value: amountToExchange}(
                _args.pool,
                _args.assetIn,
                _args.assetOut,
                amountToExchange,        
                _args.minExpectedAmountOut * 95 / 100
            );
        } else {
            _assetPoolERC20.release(
                _args.assetIn,
                address(this),
                _args.amountIn
            );
            IERC20(_args.assetIn).forceApprove(
                exchangeContract,
                amountToExchange 
            );
            amountOut = IExchange(exchangeContract).exchange(
                _args.pool,
                _args.assetIn,
                _args.assetOut,
                amountToExchange,        
                _args.minExpectedAmountOut * 95 / 100
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
}
