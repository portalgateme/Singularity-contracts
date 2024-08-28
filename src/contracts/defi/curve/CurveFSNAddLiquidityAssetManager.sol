// SPDX-License-Identifier: MIT

pragma solidity >=0.8.20;

import {BaseAssetManager} from "../../core/base/BaseAssetManager.sol";
import {CurveInputBuilder} from "./CurveInputBuilder.sol";
import {CurveAssetManagerHelper} from "./CurveAssetManagerHelper.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IPools} from "./interfaces/IPools.sol";
import {IAssetPool} from "../../core/interfaces/IAssetPool.sol";

/**
 * @title CurveFSNAddLiquidityAssetManager.
 * @dev Contract to add liquidity to Curve stable ng factory pools.
 */
contract CurveFSNAddLiquidityAssetManager is
    BaseAssetManager,
    CurveInputBuilder,
    CurveAssetManagerHelper
{
    using SafeERC20 for IERC20;
    /**
     * @dev Struct to hold the input arguments for addLiquidity function.
     * @param merkleRoot Merkle root of the merkle tree.
     * @param nullifiers Nullifiers of the notes.
     * @param assets Array of asset addresses. One to one mapping with curve pool coins.
     * @param amounts Array of asset amounts. One to one mapping with assets.
     * @param pool Curve pool address.
     * @param lpToken LP token address.
     * @param minMintAmount min expected Amount of LP tokens minted.
     * @param noteFooter partial note to be used to build notes for lp tokens.
     * @param relayer Relayer address.
     * @param gasRefund Gas refund to Relayer. Array of gas refund amounts. One to one mapping with assets.
     */
    struct AddLiquidityArgs {
        bytes32 merkleRoot;
        bytes32[4] nullifiers;
        address[4] assets;
        uint256[4] amounts;
        address pool;
        address lpToken;
        uint256 minMintAmount;
        bytes32 noteFooter;
        address payable relayer;
        uint256[4] gasRefund;
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
     * @dev Function to add liquidity to the curve pool.
     * @param _proof ZK Proof of the whole use story.
     * @param _args Input arguments for addLiquidity function.
     */
    function curveAddLiquidity(
        bytes calldata _proof,
        AddLiquidityArgs calldata _args
    ) external payable {
        _validateRelayerIsRegistered(_args.relayer);
        if(msg.sender != _args.relayer) {
            revert RelayerMismatch();
        }
        for (uint256 i = 0; i < 4; i++) {
            _validateNullifierIsNotUsed(_args.nullifiers[i]);
            _validateNullifierIsNotLocked(_args.nullifiers[i]);
        }
        _validateMerkleRootIsAllowed(_args.merkleRoot);
        _validateNoteFooterIsNotUsed(_args.noteFooter);
        if (
            _args.amounts[0] +
                _args.amounts[1] +
                _args.amounts[2] +
                _args.amounts[3] ==
            0
        ) {
            revert AmountNotCorrect();
        }
        if (_args.lpToken != _args.pool) {
            revert LpTokenNotCorrect();
        }

        _verifyProof(
            _proof,
            _buildLPInputs(
                LPRawInputs(
                    _args.merkleRoot,
                    _args.nullifiers,
                    _args.assets,
                    _args.amounts,
                    _args.pool,
                    0,
                    false,
                    _args.minMintAmount,
                    _args.noteFooter,
                    _args.relayer
                )
            ),
            "curveAddLiquidity"
        );

        if (
            !_validateAssets(_getMetaFactoryCoins(_args.pool), _args.assets) 
        ) {
            revert AssetNotInPool();
        }
        
        _registerNoteFooter(_args.noteFooter);

        uint256[] memory actualAmounts;
        uint256[4] memory serviceFees;

        (actualAmounts, serviceFees, ) = _feeManager.calculateFeeForFSN(
            _args.amounts,
            _args.gasRefund
        );

        uint256 mintAmount = _addLiquidity(_args, actualAmounts);

        IERC20(_args.lpToken).safeTransfer(
            address(_assetPoolERC20),
            mintAmount
        );

        _transferFees(
            _args.assets,
            serviceFees,
            _args.gasRefund,
            address(_feeManager),
            _args.relayer
        );

        bytes32 noteCommitment = _buildNoteForERC20(
            _args.lpToken,
            mintAmount,
            _args.noteFooter
        );
        _postDeposit(noteCommitment);

        emit CurveAddLiquidity(
            _args.nullifiers,
            _args.lpToken,
            mintAmount,
            noteCommitment,
            _args.noteFooter
        );
    }

    /**
     * @dev Function to
     *      Release the assets from the assets pool
     *      add liquidity to the curve pool and mint LP tokens
     *      and nullify the nullifiers of the notes.
     * @param _args Input arguments for addLiquidity function.
     * @param actualAmounts Array of actual asset amounts to be added to the curve pool.
     * @return mintAmount LP token amount minted.
     */
    function _addLiquidity(
        AddLiquidityArgs memory _args,
        uint256[] memory actualAmounts
    ) private returns (uint256) {
        uint256 coinNum = _getMetaFactoryCoinNum(_args.pool);
        uint256 ethAmount;
        uint256 mintAmount = _args.minMintAmount * 95 / 100;
        uint256 i;
        
        for (i = 0; i < 4; i++) {
            _postWithdraw(_args.nullifiers[i]);
        }

        if (coinNum <= 4) {
            for (i = 0; i < coinNum; i++) {
                if (actualAmounts[i] > 0) {
                    if (_args.assets[i] == ETH_ADDRESS) {
                        if (ethAmount > 0) {
                            revert AmountNotCorrect();
                        }
                        _assetPoolETH.release(
                            payable(address(this)),
                            _args.amounts[i]);
                        ethAmount = actualAmounts[i];
                    } else {
                        _assetPoolERC20.release(
                            _args.assets[i],
                            address(this),
                            _args.amounts[i]);
                        IERC20(_args.assets[i]).forceApprove(
                            _args.pool,
                            actualAmounts[i]);
                    }
                }
            }
            //mintAmount = IPools(_args.pool).calc_token_amount(
            //    actualAmounts,
            //    true);
            //mintAmount = (mintAmount / 100) * 95;

            if (ethAmount > 0) {
                mintAmount = IPools(_args.pool).add_liquidity{
                    value: ethAmount}(actualAmounts, mintAmount);
                
            } else {
                mintAmount = IPools(_args.pool).add_liquidity(
                            actualAmounts,mintAmount);
            }
        } else {
            revert PoolNotSupported();
        }
        return mintAmount;
    }
}