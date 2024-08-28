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
 * @title CurveMPRemoveLiquidityAssetManager.
 * @dev Contract to remove liquidity from Curve meta pools when need to deal with base pool coins
 */
contract CurveMPRemoveLiquidityAssetManager is
    BaseAssetManager,
    CurveInputBuilder,
    CurveAssetManagerHelper
{
    using SafeERC20 for IERC20;

    /**
     * @dev Struct to hold the input arguments for removeLiquidity function.
     * @param merkleRoot Merkle root of the merkle tree.
     * @param nullifier Nullifier of the note.
     * @param asset LP token address.
     * @param amount LP token amount of LP token note.
     * @param amountBurn LP token amount to burn.
     * @param pool Curve pool address.
     * @param assetsOut Array of asset addresses. One to one mapping with curve pool coins.
     * @param basePoolType Bit Flag to indicate if it is:
     *        01: 3pool, 10: fraxusdc.
     * @param minExpectedAmountsOut Array of minimum expected asset amounts out. One to one mapping with assetsOut.
     * @param noteFooters Array of partial notes to be used to build notes for assets out and the changes of LP token.
     * @param relayer Relayer address.
     * @param gasRefund Gas refund to Relayer. Array of gas refund amounts. One to one mapping with assetsOut.
     */
    struct RemoveLiquidityArgs {
        bytes32 merkleRoot;
        bytes32 nullifier;
        address asset;
        uint256 amount;
        uint256 amountBurn;
        address pool;
        address[4] assetsOut;
        uint256 basePoolType;
        uint256[4] minExpectedAmountsOut;
        bytes32[5] noteFooters;
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
     * @dev Function to remove liquidity from the curve pool.
     * @param _proof ZK Proof of the whole use story.
     * @param _args Input arguments for removeLiquidity function.
     */
    function curveRemoveLiquidity(
        bytes calldata _proof,
        RemoveLiquidityArgs memory _args
    ) external payable {
        _validateRelayerIsRegistered(_args.relayer);
        if(msg.sender != _args.relayer) {
            revert RelayerMismatch();
        }
        _validateNullifierIsNotUsed(_args.nullifier);
        _validateNullifierIsNotLocked(_args.nullifier);
        _validateMerkleRootIsAllowed(_args.merkleRoot);
        for (uint256 i = 0; i < 5; i++) {
            _validateNoteFooterIsNotUsed(_args.noteFooters[i]);
            _registerNoteFooter(_args.noteFooters[i]);
        }
        if(_validateNoteFooterDuplication(_args.noteFooters)){
            revert NoteFooterDuplicated();
        }

        if (_args.asset != _getLPToken(_args.pool)) {
            revert LpTokenNotCorrect();
        }
        if (_args.amountBurn == 0 || _args.amount < _args.amountBurn) {
            revert AmountNotCorrect();
        }
        _verifyProof(
            _proof,
            _buildRemoveLiquidityInputs(
                RemoveLiquidityRawInputs(
                    _args.merkleRoot,
                    _args.nullifier,
                    _args.asset,
                    _args.amount,
                    _args.amountBurn,
                    _args.pool,
                    _args.assetsOut,
                    _args.basePoolType,
                    false,
                    _args.minExpectedAmountsOut,
                    _args.noteFooters,
                    _args.relayer
                )
            ),
            "curveRemoveLiquidity"
        );

        if (
            !_validateAssets(_getUnderlyingCoins(_args.pool), _args.assetsOut)
        ) {
            revert AssetNotInPool();
        }

        uint256[4] memory actualAmounts;
        uint256[4] memory serviceFees;

        _postWithdraw(_args.nullifier);

        actualAmounts = _removeLiquidity(_args);

        (actualAmounts, serviceFees, ) = _feeManager.calculateFee(
            actualAmounts,
            _args.gasRefund
        );

        bytes32[5] memory noteCommitments = _depositAndBuildNote(
            _args,
            actualAmounts
        );

        _transferFees(
            _args.assetsOut,
            serviceFees,
            _args.gasRefund,
            address(_feeManager),
            _args.relayer
        );

        emit CurveRemoveLiquidity(
            _args.nullifier,
            [
                _args.assetsOut[0],
                _args.assetsOut[1],
                _args.assetsOut[2],
                _args.assetsOut[3],
                _args.amount - _args.amountBurn > 0 ? _args.asset : address(0)
            ],
            [
                actualAmounts[0],
                actualAmounts[1],
                actualAmounts[2],
                actualAmounts[3],
                _args.amount - _args.amountBurn > 0
                    ? _args.amount - _args.amountBurn
                    : 0
            ],
            noteCommitments,
            _args.noteFooters
        );
    }

    /**
     * @dev Function to
     *      Release the LP tokens from the ER20 assets pool
     *      Burn the LP tokens to remove liquidity from the curve pool
     *      Only supports withdraw one coin or all coins in a balanced amount.
     * @param _args Input arguments for removeLiquidity function.
     * @return expectedAmounts Array of withdrawl assets amounts. One to one mapping with assetsOut.
     */
    function _removeLiquidity(
        RemoveLiquidityArgs memory _args
    ) private returns (uint256[4] memory) {
        uint256 currentPoolCoinNum = _getCoinNum(_args.pool);
        uint256 coinNum = currentPoolCoinNum - 1 + _getCoinNum(_getBasePool(_args.pool));

        uint256[4] memory expectedAmounts;
        uint128 i;
        for (i = 0; i < 4; i++) {
            if(_args.assetsOut[i] != address(0)) {
                expectedAmounts[i] = _args.minExpectedAmountsOut[i] * 95 / 100;
            }
        }
        uint256 count;
        i = 0;
        (count, i) = _countNonZeroElements(_args.assetsOut);
        IAssetPool(_assetPoolERC20).release(
            _args.asset,
            address(this),
            _args.amountBurn
        );
        if (_args.basePoolType & 1 == 1) {
            IERC20(_args.asset).forceApprove(_3POOL_ZAP, _args.amountBurn);
        } else if (_args.basePoolType & 2 == 2) {
            IERC20(_args.asset).forceApprove(_FRAXUSDC_ZAP, _args.amountBurn);
        } else {
            revert PoolNotSupported();
        }

        if (count == 1) {
            expectedAmounts[i] = _args.basePoolType & 1 == 1
                ? IPools(_3POOL_ZAP).remove_liquidity_one_coin(
                    _args.pool,
                    _args.amountBurn,
                    int128(i),
                    expectedAmounts[i]
                    //((
                    //    IPools(_3POOL_ZAP).calc_withdraw_one_coin(
                    //        _args.pool,
                    //        _args.amountBurn,
                    //        int128(i)
                    //    )
                    //) / 100) * 95
                )
                : IPools(_FRAXUSDC_ZAP).remove_liquidity_one_coin(
                    _args.pool,
                    _args.amountBurn,
                    int128(i),
                    expectedAmounts[i]
                    //((
                    //    IPools(_FRAXUSDC_ZAP).calc_withdraw_one_coin(
                    //        _args.pool,
                    //        _args.amountBurn,
                    //        int128(i)
                    //    )
                    //) / 100) * 95
                );
        } else if (count == coinNum) {
            //expectedAmounts = _caculateExpectAmountsForMeta(
            //    currentPoolCoinNum,
            //    _args.pool,
            //    _args.asset,
            //    _args.amountBurn
            //);
            if (coinNum == 3) {
                uint256[3] memory curveInputAmounts;
                uint256[3] memory outAmounts;
                for (i = 0; i < 3; i++) {
                    curveInputAmounts[i] = expectedAmounts[i];
                }
                outAmounts = _args.basePoolType & 1 == 1
                    ? IPools(_3POOL_ZAP).remove_liquidity(
                        _args.pool,
                        _args.amountBurn,
                        curveInputAmounts
                    )
                    : IPools(_FRAXUSDC_ZAP).remove_liquidity(
                        _args.pool,
                        _args.amountBurn,
                        curveInputAmounts
                    );
                for (i = 0; i < 3; i++) {
                    expectedAmounts[i] = outAmounts[i];
                }
            } else if (coinNum == 4) {
                uint256[4] memory curveInputAmounts;
                uint256[4] memory outAmounts;
                for (i = 0; i < 4; i++) {
                    curveInputAmounts[i] = expectedAmounts[i];
                }
                outAmounts = _args.basePoolType & 1 == 1
                    ? IPools(_3POOL_ZAP).remove_liquidity(
                        _args.pool,
                        _args.amountBurn,
                        curveInputAmounts
                    )
                    : IPools(_FRAXUSDC_ZAP).remove_liquidity(
                        _args.pool,
                        _args.amountBurn,
                        curveInputAmounts
                    );
                for (i = 0; i < 4; i++) {
                    expectedAmounts[i] = outAmounts[i];
                }
            } else {
                revert PoolNotSupported();
            }
        } else {
            revert FunctionNotSupported();
        }
        return expectedAmounts;
    }

    /**
     * @dev Function to build notes for the assets out and the changes of LP token
     *      and deposits them back to the assets pools.
     * @param _args Input arguments for removeLiquidity function.
     * @param actualAmounts Array of actual asset amounts to be added to the curve pool.
     * @return noteCommitments Array of notes committed.
     */
    function _depositAndBuildNote(
        RemoveLiquidityArgs memory _args,
        uint256[4] memory actualAmounts
    ) private returns (bytes32[5] memory) {
        bytes32[5] memory noteCommitments;
        for (uint256 i = 0; i < 4; i++) {
            if (actualAmounts[i] > 0) {
                if (_args.assetsOut[i] == ETH_ADDRESS) {
                    (bool success, ) = payable(address(_assetPoolETH)).call{
                        value: actualAmounts[i]
                    }("");
                    if (!success) {
                        revert ETHtransferFailed();
                    }
                } else {
                    IERC20(_args.assetsOut[i]).safeTransfer(
                        address(_assetPoolERC20),
                        actualAmounts[i]
                    );
                }
                bytes32 noteCommitment = _buildNoteForERC20(
                    _args.assetsOut[i],
                    actualAmounts[i],
                    _args.noteFooters[i]
                );
                _postDeposit(noteCommitment);
                //_registerNoteFooter(_args.noteFooters[i]);
                noteCommitments[i] = noteCommitment;
            }
        }
        if (_args.amount - _args.amountBurn > 0) {
            bytes32 noteCommitment = _buildNoteForERC20(
                _args.asset,
                _args.amount - _args.amountBurn,
                _args.noteFooters[4]
            );
            _postDeposit(noteCommitment);
            //_registerNoteFooter(_args.noteFooters[4]);
            noteCommitments[4] = noteCommitment;
        }
        return noteCommitments;
    }
}
