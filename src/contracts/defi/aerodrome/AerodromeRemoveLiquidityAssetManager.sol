// SPDX-License-Identifier: MIT

pragma solidity >=0.8.20;

import {BaseAssetManager} from "../../core/base/BaseAssetManager.sol";
import {AerodromeInputBuilder} from "./AerodromeInputBuilder.sol";
import {AerodromeAssetManagerHelper} from "./AerodromeAssetManagerHelper.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IAerodromePool} from "./interfaces/IAerodromePool.sol";
import {IAerodromeRouter} from "./interfaces/IAerodromeRouter.sol";
import {IAssetPool} from "../../core/interfaces/IAssetPool.sol";

/**
 * @title AerodromeRemoveLiquidityAssetManager.
 * @dev Contract to remove liquidity from the aerodrome pools.  
 */
contract AerodromeRemoveLiquidityAssetManager is
    BaseAssetManager,
    AerodromeInputBuilder,
    AerodromeAssetManagerHelper
{
    using SafeERC20 for IERC20;
    /**
     * @dev Struct to hold the input arguments for addLiquidity function.
     * @param merkleRoot Merkle root of the merkle tree.
     * @param nullifier Nullifier of the lp token noyr.
     * @param pool Aerodrome pool address. Are also the liquidity token address.
     * @param amounts Array of asset amounts. One to one mapping with assets.
     * @param pool Aerodrome pool address. Are also the liquidity token address.
     * @param stable Flag to indicate if the pool is stable or volatile.
     * @param amounstMin Array of min expected asset amounts to be added to the pool. One to one mapping with assets.
     * @param deadline Deadline to add liquidity.
     * @param noteFooters Array of note footers, 2 for assets changes 1 for LP token minted.
     * @param relayer Relayer address.
     * @param gasRefund Gas refund to Relayer. Array of gas refund amounts. One to one mapping with assets.
     */
    struct RemoveLiquidityArgs {
        bytes32 merkleRoot;
        bytes32 nullifier;
        address pool;
        uint256 amount;
        uint256 amountBurn;
        bool stable;
        address[2] assetsOut;
        uint256[2] amountsOutMin;
        uint256 deadline;
        bytes32[3] noteFooters;
        address payable relayer;
        uint256[2] gasRefund;
    }

    struct ZapOutArgs {
        bytes32 merkleRoot;
        bytes32 nullifier;
        address pool;
        address assetOut;
        uint256 amount;
        uint256 amountBurn;
        IAerodromeRouter.Zap zapOutPool;
        bytes32 zapHash;
        IAerodromeRouter.Route[] routesA;
        IAerodromeRouter.Route[] routesB;
        bytes32 routesAHash;
        bytes32 routesBHash;
        bytes32[2] noteFooters;
        address relayer;
        uint256 gasRefund;
    }

    event AerodromeRemoveLiquidity(
        bytes32 nullifier,
        address[3] assetsOut,
        uint256[3] amountsOut,
        bytes32[3] noteCommitments,
        bytes32[3] noteFooters
    );

    event AerodromeZapOut(
        bytes32 nullifier,
        address[2] assetOut,
        uint256[2] amountOut,
        bytes32[2] noteCommitments,
        bytes32[2] noteFooters
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
     * @dev Function to remove liquidity from the curve pool.
     * @param _proof ZK Proof of the whole use story.
     * @param _args Input arguments for removeLiquidity function.
     */
    function aerodromeRemoveLiquidity(
        bytes calldata _proof,
        RemoveLiquidityArgs calldata _args
    ) external payable {
        _validateMerkleRootIsAllowed(_args.merkleRoot);
        _validateRelayerIsRegistered(_args.relayer);
        _validateTokens(_args.assetsOut, _args.pool);
        _validateNullifierIsNotUsed(_args.nullifier);
        _validateNullifierIsNotLocked(_args.nullifier);

        if(msg.sender != _args.relayer) {
            revert RelayerMismatch();
        }
        
        if(_validateNoteFooterDuplication(_args.noteFooters)){
            revert NoteFooterDuplicated();
        }

        uint256 i;
        for (i = 0; i < 3; i++) {
            _validateNoteFooterIsNotUsed(_args.noteFooters[i]);
            _registerNoteFooter(_args.noteFooters[i]);
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
                    _args.pool,
                    _args.amount,
                    _args.amountBurn,
                    _args.stable,
                    _args.assetsOut,
                    _args.amountsOutMin,
                    _args.deadline,
                    _args.noteFooters,
                    _args.relayer)),
            "aerodromeRemoveLiquidity"
        );

        uint256[2] memory outAmounts = _removeLiquidity(_args);
        uint256[2] memory serviceFees;

        for (i = 0; i < 2; i++) {
            (outAmounts[i], serviceFees[i], ) = _feeManager.calculateFee(
            outAmounts[i],
            _args.gasRefund[i]);
        }

        bytes32[3] memory noteCommitments = 
            _depositAndBuildNote(_args, outAmounts);

        _transferFees(
            _args.assetsOut,
            serviceFees,
            _args.gasRefund,
            address(_feeManager),
            _args.relayer
        );


        emit AerodromeRemoveLiquidity(
            _args.nullifier,
            [_args.assetsOut[0], _args.assetsOut[1], _args.pool],
            [outAmounts[0], outAmounts[1], _args.amount - _args.amountBurn],
            noteCommitments,
            _args.noteFooters
        );
    }

    function aerodromeZapOut(bytes calldata _proof,ZapOutArgs calldata _args) 
        external payable {
        _validateMerkleRootIsAllowed(_args.merkleRoot);
        _validateRelayerIsRegistered(_args.relayer);
        _validateNullifierIsNotUsed(_args.nullifier);
        _validateNullifierIsNotLocked(_args.nullifier);

        if(_args.pool != _poolFor(_args.zapOutPool)){
            revert PoolNotCorrect();
        }
        if(
        (_args.routesA.length == 0 && _args.routesB.length == 0) ||
        (_args.routesA.length != 0 && _args.assetOut != _args.routesA[_args.routesA.length -1].to) ||
        (_args.routesB.length != 0 && _args.assetOut != _args.routesB[_args.routesB.length -1].to)){
            revert PoolNotCorrect();
        }
        if(msg.sender != _args.relayer) {
            revert RelayerMismatch();
        }
        if(_args.noteFooters[0] == _args.noteFooters[1]){
            revert NoteFooterDuplicated();
        }
        
        if (_args.amountBurn == 0 || _args.amount < _args.amountBurn) {
            revert AmountNotCorrect();
        }

        uint256 i;
        for (i = 0; i < 2; i++) {
            _validateNoteFooterIsNotUsed(_args.noteFooters[i]);
            _registerNoteFooter(_args.noteFooters[i]);
        }
        _assertZapHash(_args.zapHash, _args.zapOutPool);
        _assertRouteHash(_args.routesAHash, _args.routesA);
        _assertRouteHash(_args.routesBHash, _args.routesB);

        _verifyProof(
            _proof,
            _buildZapOutInputs(
                ZapOutRawInputs(
                    _args.merkleRoot,
                    _args.nullifier,
                    _args.pool,
                    _args.assetOut,
                    _args.amount,
                    _args.amountBurn,
                    _args.zapHash,
                    _args.routesAHash,
                    _args.routesBHash,
                    _args.noteFooters,
                    _args.relayer)),
            "aerodromeZapOut"
        );

        uint256 outAmount = _zapOut(_args);
        uint256 serviceFee;

        (outAmount, serviceFee, ) = _feeManager.calculateFee(
        outAmount,
        _args.gasRefund);

        if(_args.assetOut == ETH_ADDRESS) {
            (bool success, ) = payable(address(_assetPoolETH)).call{
                        value: outAmount
                    }("");
            if (!success) {
                revert ETHtransferFailed();
            }
            (success, ) = payable(address(_feeManager)).call{
                        value: serviceFee
                    }("");
            if (!success) {
                revert ETHtransferFailed();
            }
            (success, ) = payable(address(_args.relayer)).call{
                        value: _args.gasRefund
                    }("");
            if (!success) {
                revert ETHtransferFailed();
            }
        } else {
            IERC20(_args.assetOut).safeTransfer(
                address(_assetPoolERC20),
                outAmount);
            IERC20(_args.assetOut).safeTransfer(
                address(_feeManager),
                serviceFee);
            IERC20(_args.assetOut).safeTransfer(
                address(_args.relayer),
                _args.gasRefund);
        }

        bytes32 outAssetNoteCommitment = _buildNoteForERC20(
                _args.assetOut,
                outAmount,
                _args.noteFooters[0]);
        _postDeposit(outAssetNoteCommitment);

        bytes32 changesNoteCommitment = bytes32(0);
        if(_args.amount - _args.amountBurn > 0){
            changesNoteCommitment = _buildNoteForERC20(
                    _args.pool,
                    _args.amount - _args.amountBurn,
                    _args.noteFooters[1]);
            _postDeposit(changesNoteCommitment);
        }

        emit AerodromeZapOut(
            _args.nullifier,
            [_args.assetOut,_args.pool],
            [outAmount, _args.amount - _args.amountBurn],
            [outAssetNoteCommitment, changesNoteCommitment],
            _args.noteFooters
        );


    }

    /**
     * @dev Function to
     *      Release the  LP tokens from the assets pool
     *      remove liquidity from the  pool and burn LP tokens
     *      and nullify the nullifier of the note.
     * @param _args Input arguments for removeLiquidity function.
     * @return outAmounts Array of actual asset amounts removed from the pool
     */
    function _removeLiquidity(
        RemoveLiquidityArgs memory _args
    ) private returns (uint256[2] memory outAmounts) {
        bool isEth = false;
        uint256 noneEthPosition;

        _postWithdraw(_args.nullifier);

        IAssetPool(_assetPoolERC20).release(
            _args.pool,
            address(this),
            _args.amountBurn
        );

        IERC20(_args.pool).forceApprove(ROUTER, _args.amountBurn);

        for (uint i = 0; i < 2; i++) {
               if (_args.assetsOut[i] == ETH_ADDRESS) {
                    isEth = true;
                    noneEthPosition = i == 0 ? 1 : 0;
                } 
        }

        if (isEth) {
            (outAmounts[noneEthPosition], outAmounts[noneEthPosition == 0 ? 1 : 0]) = 
                IAerodromeRouter(ROUTER).removeLiquidityETH(
                    _args.assetsOut[noneEthPosition],
                    _args.stable,
                    _args.amountBurn,
                    _args.amountsOutMin[noneEthPosition],
                    _args.amountsOutMin[noneEthPosition == 0 ? 1 : 0],
                    address(this),
                    _args.deadline
                );
        } else {
            (outAmounts[0], outAmounts[1]) = 
                IAerodromeRouter(ROUTER).removeLiquidity(
                    _args.assetsOut[0],
                    _args.assetsOut[1],
                    _args.stable,
                    _args.amountBurn,
                    _args.amountsOutMin[0],
                    _args.amountsOutMin[1],
                    address(this),
                    _args.deadline
            );
        }
   }

    function _zapOut (
        ZapOutArgs memory _args
    ) private returns (uint256 outAmount) {
        _postWithdraw(_args.nullifier);

        _assetPoolERC20.release(_args.pool, address(this), _args.amountBurn);
        IERC20(_args.pool).forceApprove(ROUTER, _args.amountBurn);

        uint256 initAmount = _args.assetOut == ETH_ADDRESS ?
            address(this).balance : IERC20(_args.assetOut).balanceOf(address(this));
        
        IAerodromeRouter(ROUTER).zapOut(
            _args.assetOut,
            _args.amountBurn,
            _args.zapOutPool,
            _args.routesA,
            _args.routesB);
        
        outAmount = (_args.assetOut == ETH_ADDRESS ?
                    address(this).balance : 
                    IERC20(_args.assetOut).balanceOf(address(this))) - initAmount;
    }


    /**
     * @dev Function to build notes for changes of the assets and the LP token
     *      and deposits them back to the assets pools.
     * @param _args Input arguments for Liquidity function.
     * @param actualAmounts Array of actual asset amounts to be added to the pool.
     * @return noteCommitments Array of notes committed.
     */
    function _depositAndBuildNote(
        RemoveLiquidityArgs memory _args,
        uint256[2] memory actualAmounts
    ) private returns (bytes32[3] memory) {

        bytes32[3] memory noteCommitments;

        for (uint256 i = 0; i < 2; i++) {
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
                noteCommitments[i] = _buildNoteForERC20(
                    _args.assetsOut[i],
                    actualAmounts[i],
                    _args.noteFooters[i]
                );
                _postDeposit(noteCommitments[i]);
            }
        }

        if (_args.amount - _args.amountBurn > 0){
                noteCommitments[2] = _buildNoteForERC20(
                _args.pool,
                _args.amount - _args.amountBurn,
                _args.noteFooters[2]
            );
            _postDeposit(noteCommitments[2]);
        }
        
        return noteCommitments;
    }
}