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
 * @title CurveRemoveLiquidityAssetManager.
 * @dev Contract to remove liquidity from Curve
 *      plain / lending /crypto pools.
 */
contract CurveRemoveLiquidityAssetManager is
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
     * @param poolFlag Bit Flag to indicate if it is:
     *                 (01) a legacy crypto pool, doesn't have isETH flag,deal eth as weth
     *                 (10) or a legacy pool with no amounts return from the liquidity functions(like 3pool),
     *                 (11) or 01 and 10,
     *                 (111) tricrypto2 pool, which uses uint256 instead of int128 for coin index,
     *                       no return amounts, no isEth flag, deal eth as weth
     *                 (100) factory-tricrypto pools, which uses uint256 for coin index，
     *                       but still has return amounts and isETH flag,
     *                 (1100) factory-crypto pools, which uses uint256 for coin index,
     *                        has return amount only for remove one coin (no return amounts for remove all), 
     *                        has isETH flag.
     *                 (100000) plain pool, no isETH flag.
     * @param booleanFlag Flag to indicate if ETH is used for crypto pool
     *                    or if underlyting coin is used for lending pool.
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
        uint256 poolFlag;
        bool booleanFlag;
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
                    _args.poolFlag,
                    _args.booleanFlag,
                    _args.minExpectedAmountsOut,
                    _args.noteFooters,
                    _args.relayer
                )
            ),
            "curveRemoveLiquidity"
        );

        if (
            !_validateAssets(_getCoins(_args.pool),_args.assetsOut)
        ) {
            if (
                !_validateAssets(
                    _getUnderlyingCoins(_args.pool),
                    _args.assetsOut
                )
            ) {
                revert AssetNotInPool();
            }
        }

        uint256[4] memory actualAmounts;
        uint256[4] memory serviceFees;

        _postWithdraw(_args.nullifier);

        actualAmounts = _removeLiquidity(_args);

        // 01 or 11 or 111
        if (_args.poolFlag & 1 == 1) {
            _unWrapEth(_args.assetsOut, actualAmounts);
        }

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
                _args.amount - _args.amountBurn > 0 ? _args.amount - _args.amountBurn : 0
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
        uint256 coinNum = _getCoinNum(_args.pool);

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
        IERC20(_args.asset).forceApprove(_args.pool, _args.amountBurn);

        if (count == 1) {
            //10 or 11 or 111
            if (_args.poolFlag & 2 ==2){
                uint256 initAmount;
                _args.assetsOut[i] == ETH_ADDRESS ? 
                    (_args.poolFlag & 1 == 1 ? 
                        initAmount = IERC20(_WETH_ADDRESS).balanceOf(address(this))
                        : initAmount = address(this).balance)
                    : initAmount = IERC20(_args.assetsOut[i]).balanceOf(address(this));
                // 111
                _args.poolFlag & 4 == 4 ?
                ILegacyPools(_args.pool).remove_liquidity_one_coin(
                        _args.amountBurn, uint256(i),
                        //((IPools(_args.pool).calc_withdraw_one_coin(
                        //    _args.amountBurn,
                        //    uint256(i))) / 100) * 95
                        expectedAmounts[i])
                : ILegacyPools(_args.pool).remove_liquidity_one_coin(
                        _args.amountBurn, int128(i),
                        //((IPools(_args.pool).calc_withdraw_one_coin(
                        //    _args.amountBurn,
                        //    int128(i))) / 100) * 95
                        expectedAmounts[i]);

                _args.assetsOut[i] == ETH_ADDRESS ? 
                    (_args.poolFlag & 1 == 1 ? 
                        expectedAmounts[i] = IERC20(_WETH_ADDRESS).balanceOf(address(this)) - initAmount
                        : expectedAmounts[i] = address(this).balance - initAmount)
                    : expectedAmounts[i] = IERC20(_args.assetsOut[i]).balanceOf(address(this)) - initAmount;
              //isPlain or 01  
            } else if (_args.poolFlag & 32 == 32 || _args.poolFlag & 1 == 1) {
                expectedAmounts[i] = IPools(_args.pool)
                    .remove_liquidity_one_coin(
                        _args.amountBurn,
                        int128(i),
                        //((IPools(_args.pool).calc_withdraw_one_coin(
                        //        _args.amountBurn,
                        //        int128(i))) / 100) * 95
                        expectedAmounts[i]);
            } else { // 100 or 1100 or other pools
                expectedAmounts[i] = _args.poolFlag & 4 == 4 ?
                    IPools(_args.pool).remove_liquidity_one_coin(
                        _args.amountBurn, uint256(i),
                        //((IPools(_args.pool).calc_withdraw_one_coin(
                        //        _args.amountBurn,
                        //        uint256(i))) / 100) * 95,
                        expectedAmounts[i],
                        _args.booleanFlag)
                    : IPools(_args.pool).remove_liquidity_one_coin(
                        _args.amountBurn, int128(i),
                        //((IPools(_args.pool).calc_withdraw_one_coin(
                        //        _args.amountBurn,
                        //        int128(i))) / 100) * 95,
                        expectedAmounts[i],
                        _args.booleanFlag);
            }
        } else if (count == coinNum) {
            
            //expectedAmounts = _caculateExpectAmounts(
            //    coinNum, _args.pool, _args.asset, _args.amountBurn);

            if (coinNum == 2) {
                uint256[2] memory curveInputAmounts;
                uint256[2] memory outAmounts;
                
                for (i = 0; i < 2; i++) {
                    curveInputAmounts[i] = expectedAmounts[i];
                }
                //10 or 11 or 111 or 1100
                if (_args.poolFlag & 2 ==2 || _args.poolFlag & 12 == 12){
                    uint256[2] memory initAmounts;
                    for (i = 0; i < 2; i++) {
                        _args.assetsOut[i] == ETH_ADDRESS ? 
                            (_args.poolFlag & 1 == 1 ? 
                                initAmounts[i] = IERC20(_WETH_ADDRESS).balanceOf(address(this))
                                : initAmounts[i] = address(this).balance)
                            : initAmounts[i] = IERC20(_args.assetsOut[i]).balanceOf(address(this));
                    }
                    //1100
                    _args.poolFlag & 12 == 12 ?
                        ILegacyPools(_args.pool).remove_liquidity(
                            _args.amountBurn,
                            curveInputAmounts,
                            _args.booleanFlag
                        )
                        : ILegacyPools(_args.pool).remove_liquidity(
                            _args.amountBurn, curveInputAmounts);

                    for (i = 0; i < 2; i++) {
                        _args.assetsOut[i] == ETH_ADDRESS ? 
                            (_args.poolFlag & 1 == 1 ? 
                                outAmounts[i] = IERC20(_WETH_ADDRESS).balanceOf(address(this)) - initAmounts[i]
                                : outAmounts[i] = address(this).balance - initAmounts[i])
                            : outAmounts[i] = IERC20(_args.assetsOut[i]).balanceOf(address(this)) - initAmounts[i];
                    } 
                    //plain pool or 01 
                }else if (_args.poolFlag & 32 == 32 || _args.poolFlag & 1 == 1) {
                    outAmounts = IPools(_args.pool).remove_liquidity(
                        _args.amountBurn,
                        curveInputAmounts
                    );
                } else { // 100 or other pools
                    outAmounts = IPools(_args.pool).remove_liquidity(
                        _args.amountBurn,
                        curveInputAmounts,
                        _args.booleanFlag
                    );

                }
                for (i = 0; i < 2; i++) {
                    expectedAmounts[i] = outAmounts[i];
                }
            } else if (coinNum == 3) {
                uint256[3] memory curveInputAmounts;
                uint256[3] memory outAmounts;

                for (i = 0; i < 3; i++) {
                    curveInputAmounts[i] = expectedAmounts[i];
                }
                //10 or 11 or 111 or 1100
                if (_args.poolFlag & 2 ==2){
                    uint256[3] memory initAmounts;
                    for (i = 0; i < 3; i++) {
                        _args.assetsOut[i] == ETH_ADDRESS ? 
                        (_args.poolFlag & 1 == 1 ?
                            initAmounts[i] = IERC20(_WETH_ADDRESS).balanceOf(address(this))
                            : initAmounts[i] = address(this).balance)
                        : initAmounts[i] = IERC20(_args.assetsOut[i]).balanceOf(address(this));
                    }

                    _args.poolFlag & 12 == 12 ?
                        ILegacyPools(_args.pool).remove_liquidity(
                            _args.amountBurn,
                            curveInputAmounts,
                            _args.booleanFlag
                        )
                        : ILegacyPools(_args.pool).remove_liquidity(
                            _args.amountBurn, curveInputAmounts);

                    for (i = 0; i < 3; i++) {
                        _args.assetsOut[i] == ETH_ADDRESS ? 
                            (_args.poolFlag & 1 == 1 ?
                                outAmounts[i] = IERC20(_WETH_ADDRESS).balanceOf(address(this)) - initAmounts[i]
                                : outAmounts[i] = address(this).balance - initAmounts[i])
                            : outAmounts[i] = IERC20(_args.assetsOut[i]).balanceOf(address(this)) - initAmounts[i];
                    } 
                //plain pool or 01
                } else if (_args.poolFlag & 32 == 32 || _args.poolFlag & 1 == 1) {
                    outAmounts = IPools(_args.pool).remove_liquidity(
                        _args.amountBurn,
                        curveInputAmounts
                    );
                } else { //100 or other pools
                    outAmounts = IPools(_args.pool).remove_liquidity(
                        _args.amountBurn,
                        curveInputAmounts,
                        _args.booleanFlag
                    );
                }
                for (i = 0; i < 3; i++) {
                    expectedAmounts[i] = outAmounts[i];
                }
            } else if (coinNum == 4) {
                uint256[4] memory curveInputAmounts;
                uint256[4] memory outAmounts;

                for (i = 0; i < 4; i++) {
                    curveInputAmounts[i] = expectedAmounts[i];
                }
                //10 or 11 or 111 or 1100
                if (_args.poolFlag & 2 ==2){
                    uint256[4] memory initAmounts;
                    for (i = 0; i < 4; i++) {
                        _args.assetsOut[i] == ETH_ADDRESS ? 
                            (_args.poolFlag & 1 == 1 ?
                                initAmounts[i] = IERC20(_WETH_ADDRESS).balanceOf(address(this))
                                : initAmounts[i] = address(this).balance)
                            : initAmounts[i] = IERC20(_args.assetsOut[i]).balanceOf(address(this));
                    }

                    _args.poolFlag & 12 == 12 ?
                        ILegacyPools(_args.pool).remove_liquidity(
                            _args.amountBurn,
                            curveInputAmounts,
                            _args.booleanFlag
                        )
                        : ILegacyPools(_args.pool).remove_liquidity(
                            _args.amountBurn, curveInputAmounts);

                    for (i = 0; i < 4; i++) {
                        _args.assetsOut[i] == ETH_ADDRESS ? 
                            (_args.poolFlag & 1 == 1 ?
                            outAmounts[i] = IERC20(_WETH_ADDRESS).balanceOf(address(this)) - initAmounts[i]
                            : outAmounts[i] = address(this).balance - initAmounts[i])
                        : outAmounts[i] = IERC20(_args.assetsOut[i]).balanceOf(address(this)) - initAmounts[i];
                    } 
                //plain pool or 01
                } else if (_args.poolFlag & 32 == 32 || _args.poolFlag & 1 == 1) {                    
                    outAmounts = IPools(_args.pool).remove_liquidity(
                        _args.amountBurn,
                        curveInputAmounts
                    );
                } else { //100 or other pools
                    outAmounts = IPools(_args.pool).remove_liquidity(
                        _args.amountBurn,
                        curveInputAmounts,
                        _args.booleanFlag
                    );
                }
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