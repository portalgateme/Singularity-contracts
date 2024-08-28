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
 * @title AerodromeAddLiquidityAssetManager.
 * @dev Contract to add liquidity to the aerodrome pools.  
 */
contract AerodromeAddLiquidityAssetManager is
    BaseAssetManager,
    AerodromeInputBuilder,
    AerodromeAssetManagerHelper
{
    using SafeERC20 for IERC20;
    /**
     * @dev Struct to hold the input arguments for addLiquidity function.
     * @param merkleRoot Merkle root of the merkle tree.
     * @param nullifiers Nullifiers of the notes.
     * @param assets Array of asset addresses. One to one mapping with aerodrome pool coins.
     * @param amounts Array of asset amounts. One to one mapping with assets.
     * @param pool Aerodrome pool address. Are also the liquidity token address.
     * @param stable Flag to indicate if the pool is stable or volatile.
     * @param amounstMin Array of min expected asset amounts to be added to the pool. One to one mapping with assets.
     * @param deadline Deadline to add liquidity.
     * @param noteFooters Array of note footers, 2 for assets changes 1 for LP token minted.
     * @param relayer Relayer address.
     * @param gasRefund Gas refund to Relayer. Array of gas refund amounts. One to one mapping with assets.
     */
    struct AddLiquidityArgs {
        bytes32 merkleRoot;
        bytes32[2] nullifiers;
        address[2] assets;
        uint256[2] amounts;
        address pool;
        bool stable;
        uint256[2] amountsMin;
        uint256 deadline;
        bytes32[3] noteFooters;
        address payable relayer;
        uint256[2] gasRefund;
    }
    /**
     * @dev Struct to hold the input arguments for zapIn function.
     * @param merkleRoot Merkle root of the merkle tree.
     * @param nullifier Nullifier of the note.
     * @param asset Address of the asset to be zaped in
     * @param amountInA    Amount of input token you wish to send down routesA
     * @param amountInB    Amount of input token you wish to send down routesB
     * @param zapInPool    Contains zap struct information. See Zap struct.
     * @param zapHash      Hash of the zap struct
     * @param routesA      Route used to convert input token to tokenA
     * @param routesB      Route used to convert input token to tokenB
     * @param routesAHash  Hash of the routesA
     * @param routesBHash  Hash of the routesB
     * @param stake Auto-stake liquidity in corresponding gauge.
     * @param relayer Relayer address.
     * @param gasRefund Gas refund to Relayer.    
     */
    struct ZapInArgs {
        bytes32 merkleRoot;
        bytes32 nullifier;
        address asset;
        uint256 amountInA;
        uint256 amountInB;
        IAerodromeRouter.Zap zapInPool;
        bytes32 zapHash;
        IAerodromeRouter.Route[] routesA;
        IAerodromeRouter.Route[] routesB;
        bytes32 routesAHash;
        bytes32 routesBHash;
        bool stake;
        bytes32 noteFooter;
        address payable relayer;
        uint256 gasRefund;
    }

    event AerodromeAddLiquidity(
        bytes32[2] nullifiers,
        address[3] assetsOut,
        uint256[3] amountsOut,
        bytes32[3] noteCommitments,
        bytes32[3] noteFooters
    );

    event AerodromeZapIn(
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
     * @dev Function to add liquidity to the curve pool.
     * @param _proof ZK Proof of the whole use story.
     * @param _args Input arguments for addLiquidity function.
     */
    function aerodromeAddLiquidity(
        bytes calldata _proof,
        AddLiquidityArgs calldata _args
    ) external payable {
        _validateMerkleRootIsAllowed(_args.merkleRoot);
        _validateRelayerIsRegistered(_args.relayer);
        _validateTokens(_args.assets, _args.pool);
        
        if(msg.sender != _args.relayer) {
            revert RelayerMismatch();
        }
        
        uint256 i;
        for (i = 0; i < 2; i++) {
            _validateNullifierIsNotUsed(_args.nullifiers[i]);
            _validateNullifierIsNotLocked(_args.nullifiers[i]);
        }
        
        if(_validateNoteFooterDuplication(_args.noteFooters)){
            revert NoteFooterDuplicated();
        }

        for (i = 0; i < 3; i++) {
            _validateNoteFooterIsNotUsed(_args.noteFooters[i]);
            _registerNoteFooter(_args.noteFooters[i]);
        }
        
        if ((_args.amounts[0] == 0 || _args.amounts[1] == 0) ||
            (_args.amounts[0] < _args.amountsMin[0] || _args.amounts[1] < _args.amountsMin[1])) {
            revert AmountNotCorrect();
        }
        
        uint256[2] memory actualDesiredAmounts;
        uint256[2] memory actualAmountsMin;
        uint256[2] memory serviceFees;

        for (i = 0; i < 2; i++) {
            (actualDesiredAmounts[i], serviceFees[i], ) = _feeManager.calculateFee(
            _args.amounts[i],
            _args.gasRefund[i]);
            (actualAmountsMin[i], serviceFees[i], ) = _feeManager.calculateFee(
            _args.amountsMin[i],
            _args.gasRefund[i]);
        }

        _verifyProof(
            _proof,
            _buildLPInputs(
                LPRawInputs(
                    _args.merkleRoot,
                    _args.nullifiers,
                    _args.assets,
                    _args.amounts,
                    _args.stable,
                    _args.amountsMin,
                    _args.pool,
                    _args.deadline,
                    _args.noteFooters,
                    _args.relayer
                )
            ),
            "aerodromeAddLiquidity"
        );

        uint256[3] memory actualAmounts =  
            _addLiquidity(_args, actualDesiredAmounts, actualAmountsMin);                           


        bytes32[3] memory noteCommitments;
        uint256[2] memory changeAmounts;
        (noteCommitments, changeAmounts)= 
            _depositAndBuildNote(_args, actualAmounts, serviceFees);

        _transferFees(
            _args.assets,
            serviceFees,
            _args.gasRefund,
            address(_feeManager),
            _args.relayer
        );


        emit AerodromeAddLiquidity(
            _args.nullifiers,
            [_args.assets[0], _args.assets[1], _args.pool],
            [changeAmounts[0], changeAmounts[1],actualAmounts[2]],
            noteCommitments,
            _args.noteFooters
        );
    }

    function aerodromeZapIn( bytes calldata _proof,ZapInArgs calldata _args) external {

        _validateMerkleRootIsAllowed(_args.merkleRoot);
        _validateRelayerIsRegistered(_args.relayer);
        _validateNullifierIsNotUsed(_args.nullifier);
        _validateNullifierIsNotLocked(_args.nullifier);
        _validateNoteFooterIsNotUsed(_args.noteFooter);
        if(msg.sender != _args.relayer) {
            revert RelayerMismatch();
        }
        if (_args.amountInA == 0 || _args.amountInB == 0) {
            revert AmountNotCorrect();
        }
        if (_args.asset != _args.zapInPool.tokenA && _args.asset != _args.zapInPool.tokenB) {
            revert PoolNotCorrect();
        }

        _assertZapHash(_args.zapHash, _args.zapInPool);
        _assertRouteHash(_args.routesAHash, _args.routesA);
        _assertRouteHash(_args.routesBHash, _args.routesB);

        _verifyProof(
            _proof,
            _buildZapInInputs(
                ZapInRawInputs(
                    _args.merkleRoot,
                    _args.nullifier,
                    _args.asset,
                    _args.amountInA,
                    _args.amountInB,
                    _args.zapHash,
                    _args.routesAHash,
                    _args.routesBHash,
                    _args.stake,
                    _args.noteFooter,
                    _args.relayer
                )
            ),
            "aerodromeZapIn"
        );

        _registerNoteFooter(_args.noteFooter);

        uint256[2] memory amountToZapIn;
        uint256 serviceFee;
        (amountToZapIn, serviceFee) = _calculateZapInAmountsAndServiceFee(
            _args.amountInA,
            _args.amountInB,
            _args.gasRefund
        );

        address lpToken = _poolFor(_args.zapInPool);
        uint256 mintAmount = _zapIn(_args, amountToZapIn);

        IERC20(lpToken).safeTransfer(
            address(_assetPoolERC20),
            mintAmount
        );

        IERC20(_args.asset).safeTransfer(
            address(_feeManager),
            serviceFee
        );
        IERC20(_args.asset).safeTransfer(
            address(_args.relayer),
            _args.gasRefund
        );

        bytes32 noteCommitment = _buildNoteForERC20(
            lpToken,
            mintAmount,
            _args.noteFooter
        );
        _postDeposit(noteCommitment);

        emit AerodromeZapIn(
            _args.nullifier,
            lpToken,
            mintAmount,
            noteCommitment,
            _args.noteFooter
        );
    }

    /**
     * @dev Function to
     *      Release the assets from the assets pool
     *      add liquidity to the  pool and mint LP tokens
     *      and nullify the nullifiers of the notes.
     * @param _args Input arguments for addLiquidity function.
     * @param actualDesiredAmounts Array of actual asset amounts desired to be added to the pool.
     * @param actualAmountsMin Array of actual min expected asset amounts to be added to the pool.
     * @return actualAmounts Array of actual asset amounts added to the pool, and the amount of the lptoken
     */
    function _addLiquidity(
        AddLiquidityArgs memory _args,
        uint256[2] memory actualDesiredAmounts, 
        uint256[2] memory actualAmountsMin
    ) private returns (uint256[3] memory actualAmounts) {
        uint256 ethAmount;
        uint256 noneEthPosition;
        
        for (uint i = 0; i < 2; i++) {
            _postWithdraw(_args.nullifiers[i]);
            
            if (actualDesiredAmounts[i] > 0) {
                if (_args.assets[i] == ETH_ADDRESS) {
                    if (ethAmount > 0) {
                        revert AmountNotCorrect();
                    }
                    _assetPoolETH.release(
                        payable(address(this)),
                        _args.amounts[i]
                    );
                    ethAmount = actualDesiredAmounts[i];
                    noneEthPosition = i == 0 ? 1 : 0;
                } else {
                    _assetPoolERC20.release(
                        _args.assets[i],
                        address(this),
                        _args.amounts[i]
                    );
                    IERC20(_args.assets[i]).forceApprove(
                        ROUTER,
                        actualDesiredAmounts[i]
                    );
                }
            }
        }

        if (ethAmount > 0) {
            (actualAmounts[noneEthPosition], 
             actualAmounts[noneEthPosition == 0 ? 1 : 0], 
             actualAmounts[2]) =
                IAerodromeRouter(ROUTER).addLiquidityETH{
                    value: ethAmount
                }(
                    _args.assets[noneEthPosition],
                    _args.stable,
                    actualDesiredAmounts[noneEthPosition],
                    actualAmountsMin[noneEthPosition],
                    actualAmountsMin[noneEthPosition == 0 ? 1 : 0],
                    address(this),
                    _args.deadline
            );
        } else {
            (actualAmounts[0], actualAmounts[1], actualAmounts[2]) =
                IAerodromeRouter(ROUTER).addLiquidity(
                    _args.assets[0],
                    _args.assets[1],
                    _args.stable,
                    actualDesiredAmounts[0],
                    actualDesiredAmounts[1],
                    actualAmountsMin[0],
                    actualAmountsMin[1],
                    address(this),
                    _args.deadline
            );
        }
   }

    function _zapIn (
        ZapInArgs memory _args,
        uint256[2] memory amountsToZapIn
    ) private returns (uint256 mintAmount) {
        _postWithdraw(_args.nullifier);

        if (_args.asset == ETH_ADDRESS) {
            _assetPoolETH.release(payable(address(this)), _args.amountInA + _args.amountInB);
        } else {
            _assetPoolERC20.release(_args.asset, address(this), _args.amountInA + _args.amountInB);
            IERC20(_args.asset).forceApprove(ROUTER, _args.amountInA + _args.amountInB);
        }

        mintAmount = IAerodromeRouter(ROUTER).zapIn(
            _args.asset,
            amountsToZapIn[0],
            amountsToZapIn[1],
            _args.zapInPool,
            _args.routesA,
            _args.routesB,
            address(this),
            _args.stake
        );
    }

    /**
     * @dev Function to build notes for changes of the assets and the LP token
     *      and deposits them back to the assets pools.
     * @param _args Input arguments for Liquidity function.
     * @param actualAmounts Array of actual asset amounts to be added to the pool.
     * @return noteCommitments Array of notes committed.
     */
    function _depositAndBuildNote(
        AddLiquidityArgs memory _args,
        uint256[3] memory actualAmounts,
        uint256[2] memory serviceFees
        //uint256 mintAmount
    ) private returns (bytes32[3] memory, uint256[2] memory) {
        bytes32[3] memory noteCommitments;
        uint256[2] memory changeAmounts;
        for (uint256 i = 0; i < 2; i++) {
            uint256 amount = _args.amounts[i] - actualAmounts[i] - serviceFees[i] - _args.gasRefund[i];
            changeAmounts[i] = amount;
            if (amount > 0) {
                if (_args.assets[i] == ETH_ADDRESS) {
                    (bool success, ) = payable(address(_assetPoolETH)).call{
                        value: amount
                    }("");
                    if (!success) {
                        revert ETHtransferFailed();
                    }
                } else {
                    IERC20(_args.assets[i]).safeTransfer(
                        address(_assetPoolERC20),
                        amount
                    );
                }
                noteCommitments[i] = _buildNoteForERC20(
                    _args.assets[i],
                    amount,
                    _args.noteFooters[i]
                );
                _postDeposit(noteCommitments[i]);
            }
        }

        IERC20(_args.pool).safeTransfer(
                        address(_assetPoolERC20),
                        actualAmounts[2]
                    );
        
        noteCommitments[2] = _buildNoteForERC20(
                _args.pool,
                actualAmounts[2],
                _args.noteFooters[2]
            );
            _postDeposit(noteCommitments[2]);
        
        return (noteCommitments, changeAmounts);
    }

    function _calculateZapInAmountsAndServiceFee(
        uint256 amountInA, 
        uint256 amountInB,
        uint256 gasRefund
    ) private view returns (uint256[2] memory amountToZapIn, uint256 serviceFee) {
        uint256 serviceFeeA;
        uint256 serviceFeeB;
        uint256 gasRefundA = ((amountInA * gasRefund)/ (amountInA + amountInB)); 
        uint256 gasRefundB = gasRefund - gasRefundA;
        
        (amountToZapIn[0], serviceFeeA, ) = _feeManager.calculateFee(amountInA, gasRefundA);
        (amountToZapIn[1], serviceFeeB, ) = _feeManager.calculateFee(amountInB, gasRefundB);

        serviceFee = serviceFeeA + serviceFeeB;
    }
}