// SPDX-License-Identifier: MIT

pragma solidity >=0.8.20;

import {BaseAssetManager} from "../../core/base/BaseAssetManager.sol";
import {CurveInputBuilder} from "./CurveInputBuilder.sol";
import {CurveAssetManagerHelper} from "./CurveAssetManagerHelper.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IPools} from "./interfaces/IPools.sol";
import {ILegacyPools} from "./interfaces/ILegacyPools.sol";
import {IAssetPool} from "../../core/interfaces/IAssetPool.sol";

/**
 * @title CurveAddLiquidityAssetManager.
 * @dev Contract to add liquidity to Curve meta pools when need to deal with base pool coins.
 */
contract CurveMPAddLiquidityAssetManager is
    BaseAssetManager,
    CurveInputBuilder,
    CurveAssetManagerHelper
{
    using SafeERC20 for IERC20;
    /**
     * @dev Struct to hold the input arguments for addLiquidity function.
     * @param merkleRoot Merkle root of the merkle tree.
     * @param nullifiers Nullifiers of the notes.
     * @param assets Array of asset addresses. start with meta pool coin (without lptoken of base pool), 
     *               followed by base pool coins. One to one mapping with curve pool coins.
     * @param amounts Array of asset amounts. One to one mapping with assets.
     * @param pool Curve pool address.
     * @param basePoolType Bit Flag to indicate if it is:
     *        01: 3pool, 10: fraxusdc.
     * @param lpToken LP token address.
     * @param minMintAmount Amount of LP tokens minted.
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
        uint256 basePoolType;
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
        if (_args.lpToken != _getLPToken(_args.pool)) {
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
                    _args.basePoolType,
                    false,
                    _args.minMintAmount,
                    _args.noteFooter,
                    _args.relayer
                )
            ),
            "curveAddLiquidity"
        );
        
        if (!_validateAssets(_getUnderlyingCoins(_args.pool)
            ,_args.assets)) {
            revert AssetNotInPool();
        }
       
        _registerNoteFooter(_args.noteFooter);

        uint256[4] memory actualAmounts;
        uint256[4] memory serviceFees;

        (actualAmounts, serviceFees, ) = _feeManager.calculateFee(
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
     * @return mintAmount LP token amount minted.
     */
    function _addLiquidity(
        AddLiquidityArgs memory _args,
        uint256[4] memory actualAmounts
    ) private returns (uint256) {
        uint256 coinNum = _getCoinNum(_args.pool) - 1 
            + _getCoinNum(_getBasePool(_args.pool));
        uint256 mintAmount = _args.minMintAmount * 95 / 100;
        uint256 i;
    
        for (i = 0; i < 4; i++) {
            _postWithdraw(_args.nullifiers[i]);
        }

        for (i = 0; i < 4; i++) {
            if (actualAmounts[i] > 0) {
                    _assetPoolERC20.release(
                        _args.assets[i],
                        address(this),
                        _args.amounts[i]);
                
                if (_args.basePoolType & 1 == 1){
                    IERC20(_args.assets[i]).forceApprove(
                        _3POOL_ZAP,
                        actualAmounts[i]);
                } else if (_args.basePoolType & 2 == 2){
                    IERC20(_args.assets[i]).forceApprove(
                        _FRAXUSDC_ZAP,
                        actualAmounts[i]);
                } else {
                    revert PoolNotSupported();
                }
            }
        }

        if (coinNum == 3) {
            uint256[3] memory curveInputAmounts;
            for (i = 0; i < 3; i++) {
                curveInputAmounts[i] = actualAmounts[i];
            }
             
             if (_args.basePoolType & 2 == 2){
                //mintAmount = (_calcTokenAmountForFRAXUSDCZap(_args.pool, curveInputAmounts) 
                //mintAmount = (IPools(_FRAXUSDC_ZAP).calc_token_amount(_args.pool, curveInputAmounts, true) 
                //                / 100) * 95;
             } else {
                revert PoolNotSupported();
             }

            mintAmount = IPools(_FRAXUSDC_ZAP).add_liquidity(
                    _args.pool, curveInputAmounts, mintAmount);

        } else if (coinNum == 4) {
            uint256[4] memory curveInputAmounts;
            for (i = 0; i < 4; i++) {
                curveInputAmounts[i] = actualAmounts[i];
            }
            if (_args.basePoolType & 1 == 1){
                //mintAmount = (IPools(_3POOL_ZAP).calc_token_amount(_args.pool, curveInputAmounts, true) 
                //    / 100) * 95;
            } else {
                revert PoolNotSupported();
            }
            
            mintAmount = IPools(_3POOL_ZAP).add_liquidity(
                _args.pool, curveInputAmounts, mintAmount);
       } else {
            revert PoolNotSupported();
        }
        return mintAmount;
    }
    /**
    * @dev Function to calculate the expected LP token amount minted for depositing assets to FRAXUSDC based meta pool
    *      Suppose to call FRAXUSDCZap contract instead, but there is bug in curve ZAP contract, 
    *      so we have to calculate it manually.
    * @param _pool Curve pool address.
    * @param _amounts Array of asset amounts.
    *
    function _calcTokenAmountForFRAXUSDCZap(address _pool, uint256[3] memory _amounts) 
        private view returns (uint256) {
        uint256[2] memory poolAmounts;

        for (uint256 i = 0; i < 2; i++) {
            poolAmounts[i] = _amounts[i + 1];
        }

            poolAmounts[1] =  IPools(_getBasePool(_pool)).calc_token_amount(poolAmounts, true);
            poolAmounts[0] = _amounts[0];
        

        return IPools(_pool).calc_token_amount(poolAmounts, true);
    }*/
}