// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {BaseAssetManager} from "../../core/base/BaseAssetManager.sol";
import {SablierInputBuilder} from "./SablierInputBuilder.sol";
import {SablierAssetManagerHelper} from "./SablierAssetManagerHelper.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IAssetPool} from "../../core/interfaces/IAssetPool.sol";
import {ISablierV2LockupDynamic} from "@sablier/v2-core/src/interfaces/ISablierV2LockupDynamic.sol";
import {Batch, Broker, LockupDynamic} from "@sablier/v2-periphery/src/types/DataTypes.sol";
import {ud60x18} from "@prb/math/src/UD60x18.sol";
import {ud2x18} from "@prb/math/src/UD2x18.sol";


contract SablierDynamicAssetManager is BaseAssetManager, SablierInputBuilder, SablierAssetManagerHelper {
    using SafeERC20 for IERC20;

    /**
     * @dev Struct to hold create stream arguments.
     * @param assetIn Address of the asset to be streamed.
     * @param amountIn Total amount of the asset to be streamed for stream(s). 
     * @param streamType type of the stream. 
     *        3 - Lockup Dynamic with milestones
     *        4 - Lockup Dynamic with deltas. 
     * @param streamSize number of streams, up to 5.  
     * @param streamParams Array of stream parameter struct.
     * @param parametersHash Hash of the stream type and parameters.
     * @param nftOut Address of the stream NFT to be received.
     * @param noteFooters arrary of partial note to be used to build notes for out NFT.
     */

    struct InputSegement{
        uint128 amount;
        uint64 exponent;
        uint40 milestoneOrDelta;
    }
    
    struct DynamicStreamParam{
        uint128 amount; 
        bool cancelable;
        bool transferable;
        uint40 startTime;
        InputSegement[] segments;
    }
    
    struct CreateStreamArgs {
        address assetIn;
        uint128 amountIn;
        uint128 streamType;
        uint128 streamSize;
        DynamicStreamParam[] streamParams;
        bytes32 parametersHash;
        address nftOut;
        bytes32[] noteFooters;
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
        SablierInputBuilder(P)
    {}
    function createDynamicStream(bytes calldata _proof, CreateStreamArgs memory _args) external {       
        require(
            _complianceManager.isAuthorized(address(this), msg.sender),
            "BaseAssetManager: invalid credential"
        );

        _validateStreamSize(_args.streamSize, _args.streamParams.length, _args.noteFooters.length);
        
        for (uint256 i = 0; i < _args.streamSize; i++) {
            _validateNoteFooterIsNotUsed(_args.noteFooters[i]);
            _registerNoteFooter(_args.noteFooters[i]);
        }
        
        _validateAmounts(_args);
        _validateParameterHash(_args.parametersHash, _args.streamSize, _args.streamType, _args.streamParams);

        _verifyProof(
            _proof,
            _buildCreateStreamInputs(
                CreateStreamRawInputs(
                    msg.sender,
                    _args.assetIn,
                    _args.amountIn,
                    _args.streamSize,
                    _args.streamType,
                    _args.parametersHash,
                    _args.nftOut,
                    _args.noteFooters
                )
            ),
            "sablierCreateStream"
        );

        IERC20(_args.assetIn).safeTransferFrom(msg.sender, address(this), _args.amountIn);
            
        uint256[] memory streamIds = _createDynamicStream(_args);
        bytes32[] memory noteCommitments = new bytes32[](_args.streamSize);

        for (uint256 i = 0; i < _args.streamSize; i++) {
            noteCommitments[i] = _buildNoteForERC721(_args.nftOut, streamIds[i], _args.noteFooters[i]);
            _postDeposit(noteCommitments[i]);
        }

        emit SablierCreateStream(
            msg.sender,
            _args.nftOut,
            streamIds,
            noteCommitments,
            _args.noteFooters
        );
    }

    function claimStream(
        bytes calldata _proof,
        ClaimStreamArgs memory _args
    ) external {
        _validateRelayerIsRegistered(_args.relayer);
        if(msg.sender != _args.relayer) {
            revert RelayerMismatch();
        }
        _validateMerkleRootIsAllowed(_args.merkleRoot);
        _validateNullifierIsNotUsed(_args.nullifierIn);
        _validateNullifierIsNotLocked(_args.nullifierIn);
        _validateNoteFooterIsNotUsed(_args.noteFooter);

        if (address(_getLockupDynamic()) != _args.stream){
            revert StreamNotCorrect();
        }
        if(address(_getLockupDynamic().getAsset(_args.streamId))!=_args.assetOut){
            revert AssetNotCorrect();
        }
        if(_args.amountOut == 0 ||
            _args.amountOut > _getLockupDynamic().withdrawableAmountOf(_args.streamId))
        {
            revert AmountNotCorrect();
        }

        _verifyProof(
            _proof,
            _buildClaimStreamInputs(
                ClaimStreamRawInputs(
                    _args.merkleRoot,
                    _args.nullifierIn,
                    _args.stream,
                    _args.streamId,
                    _args.assetOut,
                    _args.amountOut,
                    _args.noteFooter,
                    _args.relayer
                )
            ),
            "sablierClaimStream"
        );
        _registerNoteFooter(_args.noteFooter);        

        uint256 initBalance = IERC20(_args.assetOut).balanceOf(address(this));
        _getLockupDynamic().withdraw(_args.streamId, address(this), _args.amountOut);
        uint256 finalBalance = IERC20(_args.assetOut).balanceOf(address(this)) - initBalance;
        uint256 serviceFee;

        (finalBalance, serviceFee, ) = _feeManager.calculateFee(finalBalance, _args.gasRefund);

        IERC20(_args.assetOut).safeTransfer(address(_assetPoolERC20), finalBalance);
        IERC20(_args.assetOut).safeTransfer(address(_feeManager), serviceFee);
        IERC20(_args.assetOut).safeTransfer(_args.relayer, _args.gasRefund);

        bytes32 noteCommitment = _buildNoteForERC20(_args.assetOut, finalBalance, _args.noteFooter);

        _postDeposit(noteCommitment);

        emit SablierClaimStream(
            _args.nullifierIn,
            _args.assetOut,
            finalBalance,
            noteCommitment,
            _args.noteFooter
        );
    }

    function _createDynamicStream (CreateStreamArgs memory _args) private returns(uint256[] memory streamIds){
        uint256 i;
        uint256 j;
        if (_args.streamType == 1) {
            if (_args.streamSize == 1){
                streamIds = new uint256[](1);

                IERC20(_args.assetIn).forceApprove(address(_getLockupDynamic()), _args.amountIn);

                LockupDynamic.CreateWithMilestones memory params;
                params.segments = new LockupDynamic.Segment[](_args.streamParams[0].segments.length);

                params.sender = msg.sender;
                params.recipient = address(this);
                params.asset = IERC20(_args.assetIn);
                params.totalAmount = _args.amountIn;
                params.startTime = _args.streamParams[0].startTime;
                params.cancelable = _args.streamParams[0].cancelable;
                params.transferable = _args.streamParams[0].transferable;
                params.broker = Broker(address(0), ud60x18(0));

                for (i = 0; i < _args.streamParams[0].segments.length; i++) {
                    params.segments[i] = LockupDynamic.Segment({
                        amount: _args.streamParams[0].segments[i].amount,
                        exponent: ud2x18(_args.streamParams[0].segments[i].exponent),
                        milestone: _args.streamParams[0].segments[i].milestoneOrDelta
                    });
                }
                streamIds[0] = _getLockupDynamic().createWithMilestones(params);

            } else {
                streamIds = new uint256[](_args.streamSize);

                IERC20(_args.assetIn).forceApprove(address(_getBatch()), _args.amountIn);
                                
                Batch.CreateWithMilestones[] memory streamBatch = new Batch.CreateWithMilestones[](_args.streamSize);


                for (i = 0; i < _args.streamSize; i++) {
                    Batch.CreateWithMilestones memory stream;
                    stream.sender = msg.sender;
                    stream.recipient = address(this);
                    stream.segments = new LockupDynamic.Segment[](_args.streamParams[i].segments.length);

                    stream.startTime = _args.streamParams[i].startTime;
                    stream.cancelable = _args.streamParams[i].cancelable;
                    stream.transferable = _args.streamParams[i].transferable;
                    stream.broker = Broker(address(0), ud60x18(0));

                    for(j = 0; j < _args.streamParams[i].segments.length; j++){
                        stream.segments[j] = LockupDynamic.Segment({
                            amount: _args.streamParams[i].segments[j].amount,
                            exponent: ud2x18(_args.streamParams[i].segments[j].exponent),
                            milestone: _args.streamParams[i].segments[j].milestoneOrDelta
                        });
                    }
                    stream.totalAmount = _args.streamParams[i].amount;

                    streamBatch[i] = stream;
                }
                streamIds = _getBatch().createWithMilestones(_getLockupDynamic() , IERC20(_args.assetIn), streamBatch);
            }
        } else if (_args.streamType == 2){
            if (_args.streamSize == 1){
                streamIds = new uint256[](1);

                IERC20(_args.assetIn).forceApprove(address(_getLockupDynamic()), _args.amountIn);

                LockupDynamic.CreateWithDeltas memory params;

                params.sender = msg.sender;
                params.recipient = address(this);
                params.asset = IERC20(_args.assetIn);
                params.totalAmount = _args.amountIn;
                params.cancelable = _args.streamParams[0].cancelable;
                params.transferable = _args.streamParams[0].transferable;
                params.broker = Broker(address(0), ud60x18(0));
                params.segments = new LockupDynamic.SegmentWithDelta[](_args.streamParams[0].segments.length);

                for (i = 0; i < _args.streamParams[0].segments.length; i++) {
                    params.segments[i] = LockupDynamic.SegmentWithDelta({
                        amount: _args.streamParams[0].segments[i].amount,
                        exponent: ud2x18(_args.streamParams[0].segments[i].exponent),
                        delta: _args.streamParams[0].segments[i].milestoneOrDelta
                    });
                }
                streamIds[0] = _getLockupDynamic().createWithDeltas(params);

            } else {
                streamIds = new uint256[](_args.streamSize);

                IERC20(_args.assetIn).forceApprove(address(_getBatch()), _args.amountIn);
                                
                Batch.CreateWithDeltas[] memory streamBatch = new Batch.CreateWithDeltas[](_args.streamSize);

                for (i = 0; i < _args.streamSize; i++) {
                    Batch.CreateWithDeltas memory stream;
                    stream.sender = msg.sender;
                    stream.recipient = address(this);
                    stream.segments = new LockupDynamic.SegmentWithDelta[](_args.streamParams[i].segments.length);

                    stream.cancelable = _args.streamParams[i].cancelable;
                    stream.transferable = _args.streamParams[i].transferable;
                    stream.broker = Broker(address(0), ud60x18(0));

                    for(j = 0; j < _args.streamParams[i].segments.length; j++){
                        stream.segments[j] = LockupDynamic.SegmentWithDelta({
                            amount: _args.streamParams[i].segments[j].amount,
                            exponent: ud2x18(_args.streamParams[i].segments[j].exponent),
                            delta: _args.streamParams[i].segments[j].milestoneOrDelta
                        });
                    }      
                    stream.totalAmount = _args.streamParams[i].amount;

                    streamBatch[i] = stream;
                }
                streamIds = _getBatch().createWithDeltas(_getLockupDynamic() , IERC20(_args.assetIn), streamBatch);
            }
        } else {
            revert StreamTypeNotSupported();
        }
    }
    function _validateAmounts(CreateStreamArgs memory args) private pure 
    {
        if (args.amountIn == 0) {
            revert AmountNotCorrect();
        }

        uint256 i;
        uint256 j;
        uint256 totalAmount;

        if (args.streamType == 1 || args.streamType == 2){
            for (i=0; i < args.streamSize; i++) {
                uint256 segmentAmount;
                for (j = 0; j < args.streamParams[i].segments.length; j++) {
                    segmentAmount += args.streamParams[i].segments[j].amount;
                }
                if (segmentAmount != args.streamParams[i].amount){
                    revert AmountNotCorrect();
                }
                totalAmount += segmentAmount;
            }
        } else {
            revert StreamTypeNotSupported();
        }
        
        if (totalAmount != args.amountIn){
            revert AmountNotCorrect();
        }

    }

    function _validateParameterHash(
        bytes32 _parametersHash,
        uint256 _streamSize,
        uint256 _streamType,
        DynamicStreamParam[] memory _streamParams) private pure
    {
        bytes32[] memory pHashes = new bytes32[](_streamSize);
        uint256 i;
        uint256 j;
        if (_streamType == 1 || _streamType == 2){
            for (i = 0; i < _streamSize; i++) {
                pHashes[i] = keccak256(abi.encode(
                _streamParams[i].amount,
                _streamParams[i].cancelable,
                _streamParams[i].transferable,
                _streamParams[i].startTime
                ));

                for (j = 0; j < _streamParams[i].segments.length; j++) {
                    pHashes[i] = keccak256(abi.encode(
                        pHashes[i],
                        _streamParams[i].segments[j].amount,
                        _streamParams[i].segments[j].exponent,
                        _streamParams[i].segments[j].milestoneOrDelta
                    ));
                }
            }
        } else {
            revert StreamTypeNotSupported();
        }

        if (_parametersHash != keccak256(abi.encode(_streamType, _streamSize, pHashes))){
            revert ParametersHashMismatch();
        }
    }
}