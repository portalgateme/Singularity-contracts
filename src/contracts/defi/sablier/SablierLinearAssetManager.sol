// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {BaseAssetManager} from "../../core/base/BaseAssetManager.sol";
import {SablierInputBuilder} from "./SablierInputBuilder.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IAssetPool} from "../../core/interfaces/IAssetPool.sol";
import {SablierAssetManagerHelper} from "./SablierAssetManagerHelper.sol";
import {ISablierV2LockupLinear} from "@sablier/v2-core/src/interfaces/ISablierV2LockupLinear.sol";
import {Batch, Broker, LockupLinear} from "@sablier/v2-periphery/src/types/DataTypes.sol";
import {ud60x18} from "@prb/math/src/UD60x18.sol";

contract SablierLinearAssetManager is BaseAssetManager ,SablierInputBuilder, SablierAssetManagerHelper {
    using SafeERC20 for IERC20;

    /**
     * @dev Struct to hold create stream arguments.
     * @param assetIn Address of the asset to be streamed.
     * @param amountIn Total amount of the asset to be streamed for stream(s).
     * @param streamType type of the stream. 
     *        1 - Lockup Linear with durations
     *        2 - Lockup Linear with ranges
     * @param streamSize number of streams, up to 5.  
     * @param streamParams Array of stream parameter struct.
     * @param parametersHash Hash of the stream type and parameters.
     * @param nftOut Address of the stream NFT to be received.
     * @param noteFooters arrary of partial note to be used to build notes for out NFT.
     */
    
    struct LinearStreamParam{
        uint128 amount;
        bool cancelable;
        bool transferable;
        uint40 cliff; // durations and rang
        uint40 total; //duration
        uint40 start; //range
        uint40 end; //range
    }
    
    struct CreateStreamArgs {
        address assetIn;
        uint128 amountIn;
        uint128 streamType;
        uint128 streamSize;
        LinearStreamParam[] streamParams;
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

    function createLinearStream(bytes calldata _proof, CreateStreamArgs memory _args) external {   
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
            
        uint256[] memory streamIds = _createLinearStream(_args);
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

        if (address(_getLockupLinear()) != _args.stream){
            revert StreamNotCorrect();
        }
        if(address(_getLockupLinear().getAsset(_args.streamId))!=_args.assetOut){
            revert AssetNotCorrect();
        }
        if(_args.amountOut == 0 ||
            _args.amountOut > _getLockupLinear().withdrawableAmountOf(_args.streamId))
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
        _getLockupLinear().withdraw(_args.streamId, address(this), _args.amountOut);
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


    function _createLinearStream (CreateStreamArgs memory _args) private returns(uint256[] memory streamIds){
        uint256 i;
        if (_args.streamType == 1) {
            if (_args.streamSize == 1){
                streamIds = new uint256[](1);
                IERC20(_args.assetIn).forceApprove(address(_getLockupLinear()), _args.amountIn);

                LockupLinear.CreateWithDurations memory params;
                params.sender = msg.sender;
                params.recipient = address(this);
                params.totalAmount = _args.amountIn;
                params.asset = IERC20(_args.assetIn);
                params.cancelable = _args.streamParams[0].cancelable;
                params.transferable = _args.streamParams[0].transferable;
                params.durations = LockupLinear.Durations({
                    cliff: _args.streamParams[0].cliff,
                    total: _args.streamParams[0].total
                });
                params.broker = Broker(address(0), ud60x18(0));
                
                streamIds[0] = _getLockupLinear().createWithDurations(params);

            } else {
                streamIds = new uint256[](_args.streamSize);

                IERC20(_args.assetIn).forceApprove(address(_getBatch()), _args.amountIn);
                                
                Batch.CreateWithDurations[] memory streamBatch = new Batch.CreateWithDurations[](_args.streamSize);

                for (i = 0; i < _args.streamSize; i++) {
                    Batch.CreateWithDurations memory stream;
                    stream.sender = msg.sender;
                    stream.recipient = address(this);
                    stream.totalAmount = _args.streamParams[i].amount;
                    stream.cancelable = _args.streamParams[i].cancelable;
                    stream.transferable = _args.streamParams[i].transferable;

                    stream.durations = LockupLinear.Durations({
                        cliff: _args.streamParams[i].cliff,
                        total: _args.streamParams[i].total
                    });
                    stream.broker = Broker(address(0), ud60x18(0));

                    streamBatch[i] = stream;
                }
                streamIds = _getBatch().createWithDurations(_getLockupLinear() , IERC20(_args.assetIn), streamBatch);
            }
        } else if (_args.streamType == 2){
            if (_args.streamSize == 1){
                streamIds = new uint256[](1);
                IERC20(_args.assetIn).forceApprove(address(_getLockupLinear()), _args.amountIn);

                LockupLinear.CreateWithRange memory params;
                params.sender = msg.sender;
                params.recipient = address(this);
                params.totalAmount = _args.amountIn;
                params.asset = IERC20(_args.assetIn);
                params.cancelable = _args.streamParams[0].cancelable;
                params.transferable = _args.streamParams[0].transferable;

                params.range = LockupLinear.Range({
                    start: _args.streamParams[0].start,
                    cliff: _args.streamParams[0].cliff,
                    end: _args.streamParams[0].end
                });
                params.broker = Broker(address(0), ud60x18(0));

                streamIds[0] = _getLockupLinear().createWithRange(params);
                
            } else {

                streamIds = new uint256[](_args.streamSize);
                
                IERC20(_args.assetIn).forceApprove(address(_getBatch()), _args.amountIn);
                                
                Batch.CreateWithRange[] memory streamBatch = new Batch.CreateWithRange[](_args.streamSize);

                for (i = 0; i < _args.streamSize; i++) {
                    Batch.CreateWithRange memory stream;
                    stream.sender = msg.sender;
                    stream.recipient = address(this);
                    stream.totalAmount = _args.streamParams[i].amount;
                    stream.cancelable = _args.streamParams[i].cancelable;
                    stream.transferable = _args.streamParams[i].transferable;
                    stream.range = LockupLinear.Range({
                        start: _args.streamParams[i].start,
                        cliff: _args.streamParams[i].cliff,
                        end: _args.streamParams[i].end
                    });
                    stream.broker = Broker(address(0), ud60x18(0));

                    streamBatch[i] = stream;
                }
                streamIds = _getBatch().createWithRange(_getLockupLinear() , IERC20(_args.assetIn), streamBatch);
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
        uint256 totalAmount;

        if (args.streamType == 1 || args.streamType == 2){
            for (i=0; i < args.streamSize; i++) {
                totalAmount += args.streamParams[i].amount;
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
        LinearStreamParam[] memory _streamParams) private pure
    {
        bytes32[] memory pHashes = new bytes32[](_streamSize);
        if (_streamType == 1 || _streamType == 2){
            for (uint256 i = 0; i < _streamSize; i++) {
                pHashes[i] = keccak256(abi.encode(
                    _streamParams[i].amount,
                    _streamParams[i].cancelable,
                    _streamParams[i].transferable,
                    _streamParams[i].cliff,
                    _streamParams[i].total,
                    _streamParams[i].start,
                    _streamParams[i].end
                ));
            }
        } else {
            revert StreamTypeNotSupported();
        }
        if (_parametersHash != keccak256(abi.encode(_streamType, _streamSize, pHashes))){
            revert ParametersHashMismatch();
        }
    }
}