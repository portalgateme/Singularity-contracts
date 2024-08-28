// SPDX-License-Identifier: MIT

pragma solidity >=0.8.20;

import {BaseAssetManager} from "../../core/base/BaseAssetManager.sol";
import {DefiInputBuilder} from "./DefiInputBuilder.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IGeneralDefiIntegration} from "./interfaces/IGeneralDefiIntegration.sol";
import {IAssetPool} from "../../core/interfaces/IAssetPool.sol";
import {IFeeManager} from "../../core/interfaces/IFeeManager.sol";
import {IMimc254} from "../../core/interfaces/IMimc254.sol";

/**
 * @title GeneralDefiIntegrationAssetManager.
 * @dev 
 */
contract GeneralDefiIntegrationAssetManager is BaseAssetManager, DefiInputBuilder{
    using SafeERC20 for IERC20;

    uint256 public constant MAXISUM_ASSETS_ALLOWED = 4; 

    /**
     * @dev Struct to hold the input arguments for addLiquidity function. 
     * @param merkleRoot Merkle root of the merkle tree.
     * @param nullifiers Nullifiers of the notes.
     * @param inNoteType In note type(Fungable or non fungable). 
     * @param assets Array of asset addresses. One to one mapping with pool coins. Maxisum 4 assets are allowed.
     * @param amounts Array of asset amounts. One to one mapping with assets. Maxisum 4 assets are allowed.
     * @param contractAddress The contract (Defi gateway) to intergrate with.
     * @param defiParameters Defi parameters to be used to integrate with defi protocals.
     * @param defiParametersHash Hash of defi parameters.
     * @param noteFooters partial note to be used to build notes for lp tokens. Maxisum 4 assets are allowed.
     * @param outNoteType out note type(Fungable or non fungable). 
     * @param relayer Relayer address.
     * @param gasRefund Gas refund to Relayer. Array of gas refund amounts. One to one mapping with assets.
     */
    struct DefiArgs {
        bytes32 merkleRoot;
        bytes32[] nullifiers;
        IMimc254.NoteDomainSeparator inNoteType;
        address[] assets;
        uint256[] amountsOrNftIds;
        address contractAddress;
        string defiParameters;
        bytes32 defiParametersHash;
        bytes32[] noteFooters;
        IMimc254.NoteDomainSeparator outNoteType;
        address payable relayer;
        uint256[] gasRefund;
    }

    struct EventOutput {
        address contractAddress;
        bytes32[] nullifiers;
        bytes32[] outNote;
        uint256[] outAmount;
        bytes32[] noteFooter;
    }

    event DefiIntegration(
        address contractAddress,
        bytes32[] nullifiers,
        bytes32[] outNote,
        uint256[] outAmount,
        bytes32[] noteFooter
    );

    error AmountNotCorrect();
    error ParametersHashNotCorrect();
    error AssetNotInPool();
    error ETHtransferFailed();
    error NoteTypeMismatch();
    error ParametesMismatch();

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
        DefiInputBuilder(P)
    {}

    /**
     * @dev Function to integrate with DiFi protocals.
     * @param _proof ZK Proof of the whole use story.
     * @param _args Input arguments.
     */
    function deFiIntegrate(
        bytes calldata _proof,
        DefiArgs calldata _args
    ) external payable {
        if(_args.nullifiers.length > MAXISUM_ASSETS_ALLOWED || _args.nullifiers.length == 0 ||
            _args.nullifiers.length != _args.assets.length ||
            _args.nullifiers.length != _args.amountsOrNftIds.length ||
            _args.noteFooters.length > MAXISUM_ASSETS_ALLOWED || _args.noteFooters.length == 0 ||
            (_args.gasRefund.length != _args.nullifiers.length && _args.gasRefund.length != _args.noteFooters.length)) {
            revert ParametesMismatch();
        }
        
        _validateRelayerIsRegistered(_args.relayer);
        if(msg.sender != _args.relayer) {
            revert RelayerMismatch();
        }
        uint256 i;

        for (i = 0; i < _args.nullifiers.length; i++) {
            _validateNullifierIsNotUsed(_args.nullifiers[i]);
            _validateNullifierIsNotLocked(_args.nullifiers[i]);
        }
        _validateMerkleRootIsAllowed(_args.merkleRoot);
        _validateNoteFooterDuplication(_args.noteFooters);

        for (i = 0; i < _args.noteFooters.length; i++) {
            _validateNoteFooterIsNotUsed(_args.noteFooters[i]);
            _registerNoteFooter(_args.noteFooters[i]);
        }
        if (_args.inNoteType == _args.outNoteType && 
            _args.inNoteType == IMimc254.NoteDomainSeparator.NON_FUNGIBLE) {
            revert NoteTypeMismatch();
        }
        for (i = 0; i < _args.amountsOrNftIds.length; i++) {
            if (_args.amountsOrNftIds[i] > 0) {
                break;
            }
        }
        if (i == _args.amountsOrNftIds.length) {
            revert AmountNotCorrect();
        }

        bytes32 dh = keccak256(abi.encode(
                _args.defiParameters));

        if (dh != _args.defiParametersHash) {
            revert ParametersHashNotCorrect();
        }

        _verifyProof(
            _proof,
            _buildLPInputs(
                DefiRawInputs(
                    _args.merkleRoot,
                    _args.nullifiers,
                    _args.inNoteType,
                    _args.assets,
                    _args.amountsOrNftIds,
                    _args.contractAddress,
                    dh,
                    _args.noteFooters,
                    _args.outNoteType,
                    _args.relayer
                )
            ),
            "generalDefiIntegration"
        );

        if (!_validateAssets(IGeneralDefiIntegration(
                _args.contractAddress).getAssets(_args.defiParameters),
                _args.assets)) {
            revert AssetNotInPool();
        }

        uint256[] memory actualAmounts = _args.amountsOrNftIds;
        uint256[] memory serviceFees = new uint256[](_args.amountsOrNftIds.length);
        
        if (_args.inNoteType == IMimc254.NoteDomainSeparator.FUNGIBLE) {
            for (i = 0; i < _args.amountsOrNftIds.length; i++) {
                (actualAmounts[i],serviceFees[i],) = IFeeManager(_feeManager).calculateFee(
                    _args.amountsOrNftIds[i],
                    _args.gasRefund[i]
                );
            }
        }

        address[] memory outAssets;
        uint256[] memory outAmountsOrNftIds;

        (outAssets, outAmountsOrNftIds) = _defiCall(_args, actualAmounts);

        if (_args.inNoteType == IMimc254.NoteDomainSeparator.FUNGIBLE){
            _transferFees(
                _args.assets,
                serviceFees,
                _args.gasRefund,
                address(_feeManager),
                _args.relayer
            );
        }

        if (_args.outNoteType == IMimc254.NoteDomainSeparator.FUNGIBLE && 
            _args.inNoteType != IMimc254.NoteDomainSeparator.FUNGIBLE) {
            for (i = 0; i < outAmountsOrNftIds.length; i++) {
                (outAmountsOrNftIds[i], serviceFees[i], ) = IFeeManager(_feeManager).calculateFee(
                    outAmountsOrNftIds[i],
                    _args.gasRefund[i]
                );
            }
            _transferFees(
                outAssets,
                serviceFees,
                _args.gasRefund,
                address(_feeManager),
                _args.relayer
            );
        }

        bytes32[] memory noteCommitments = _depositAndBuildNote(
            outAssets,
            outAmountsOrNftIds,
            _args
        );

        emit DefiIntegration(
            _args.contractAddress,
            _args.nullifiers,
            noteCommitments,
            outAmountsOrNftIds,
            _args.noteFooters
        );
    }

    /**
     * @dev Function to
     *      Release the assets from the assets pool
     *      integrate with DeFi protocals,
     *      transfer return assets back to the assets pools,
     *      and nullify the nullifiers of the notes.
     * @param _args Input arguments for Defi integration.
     * @param actualAmountsOrNftIds Array of actual asset amounts to interact with DeFi protocals.
     * @return assets Array of assets returned from the DeFi protocals.
     * @return amountsOrNftIds Array of asset amounts or NFT ids returned from the DeFi protocals.
     */
    function _defiCall(
        DefiArgs memory _args,
        uint256[] memory actualAmountsOrNftIds
    ) private returns (address[] memory, uint256[] memory) {
        uint256 ethAmount = 0;
        uint256 i = 0;

        for (i = 0; i < _args.nullifiers.length; i++) {
            if (_args.inNoteType == IMimc254.NoteDomainSeparator.FUNGIBLE) {
                _postWithdraw(_args.nullifiers[i]);
            }
        }

        for (i = 0; i < actualAmountsOrNftIds.length; i++) {
            if (actualAmountsOrNftIds[i] > 0) {
                if (_args.assets[i] == ETH_ADDRESS) {
                    if (ethAmount > 0) {
                        revert AmountNotCorrect();
                    }
                    _assetPoolETH.release(
                        payable(address(this)),
                        _args.amountsOrNftIds[i]
                    );
                    ethAmount = actualAmountsOrNftIds[i];
                } else {
                    if (_args.inNoteType == IMimc254.NoteDomainSeparator.FUNGIBLE) {
                        _assetPoolERC20.release(
                            _args.assets[i],
                            address(this),
                            _args.amountsOrNftIds[i]
                        );
                        IERC20(_args.assets[i]).forceApprove(
                            _args.contractAddress,
                            actualAmountsOrNftIds[i]
                        );
                    } else {
                        _assetPoolERC721.release(
                            _args.assets[i],
                            address(this),
                            _args.amountsOrNftIds[i]
                        );
                    }
                }
            }
        }

        address[] memory assets;
        uint256[] memory amountsOrNftIds;

        if (ethAmount > 0) {
            (assets, amountsOrNftIds)  = IGeneralDefiIntegration(
                _args.contractAddress
                ).defiCall{value:ethAmount}(actualAmountsOrNftIds, _args.defiParameters);
        } else {
            (assets, amountsOrNftIds) = IGeneralDefiIntegration(
                _args.contractAddress
                ).defiCall(actualAmountsOrNftIds, _args.defiParameters);
        }

        return (assets, amountsOrNftIds);
    }

    /**
     * @dev Function to build notes for the assets out and the changes (if any)
     *      and deposits them back to the assets pools.
     * @param assets Array of asset returnd from the DeFi protocals.
     * @param amountsOrNftIds Array of asset amounts or NFT ids returnd from the DeFi protocals.
     * @param _args Input arguments for Defi integration.
     * @return eventOutputs Array of EventOutput structs.
     */
    function _depositAndBuildNote(
        address[] memory assets,
        uint256[] memory amountsOrNftIds,
        DefiArgs memory _args
    ) private returns (bytes32[] memory) {
        bytes32[] memory noteCommitments = new bytes32[](amountsOrNftIds.length);
        for (uint256 i = 0; i < amountsOrNftIds.length; i++) {
            if (amountsOrNftIds[i] > 0) {
                bytes32 noteCommitment;
                if (_args.outNoteType == IMimc254.NoteDomainSeparator.FUNGIBLE) {

                    if (assets[i] == ETH_ADDRESS) {
                        (bool success, ) = payable(address(_assetPoolETH)).call{
                            value: amountsOrNftIds[i]}("");
                        if (!success) {
                            revert ETHtransferFailed();
                        }
                    } else {
                        IERC20(assets[i]).safeTransfer(
                            address(_assetPoolERC20),
                            amountsOrNftIds[i]
                        );
                    }

                    noteCommitment = _buildNoteForERC20(
                        assets[i],
                        amountsOrNftIds[i],
                        _args.noteFooters[i]
                    );
                } else {
                    IERC721(assets[i]).safeTransferFrom(
                        address(this),
                        address(_assetPoolERC721),
                        amountsOrNftIds[i]
                    );
                    noteCommitment = _buildNoteForERC721(
                        assets[i],
                        amountsOrNftIds[i],
                        _args.noteFooters[i]
                    );
                }
                noteCommitments[i] = noteCommitment;
                _postDeposit(noteCommitment);
            }
        }
        return noteCommitments;
    }

    function _transferFees(
        address[] memory assets,
        uint256[] memory serviceFees,
        uint256[] memory gasRefund,
        address feeManager,
        address relayer
    ) private {
        for (uint256 i = 0; i < assets.length; i++) {
            if (assets[i] == ETH_ADDRESS) {
                (bool success, ) = payable(feeManager).call{
                    value: serviceFees[i]
                }("");
                (success, ) = payable(relayer).call{value: gasRefund[i]}("");
            } else {
                if (assets[i] != address(0)) {
                    IERC20(assets[i]).safeTransfer(feeManager, serviceFees[i]);
                    IERC20(assets[i]).safeTransfer(relayer, gasRefund[i]);
                }
            }
        }
    }


    function _validateAssets(
        address[] memory coins,
        address[] memory assets
    ) private pure returns (bool) {
        if (coins.length != assets.length) {
            return false;
        }
        for (uint256 i = 0; i < coins.length; i++) {
            if (assets[i] != coins[i]) {
                return false;
            }
        }
        return true;
    }

    function _validateNoteFooterDuplication(bytes32[] memory footers) 
            private pure returns (bool) {
        for (uint i = 0; i < footers.length; i++) {
            if (footers[i] != bytes32(0)) {
                for (uint j = i + 1; j < footers.length; j++) {
                    if (footers[i] == footers[j]) {
                        return true;
                    }
                }
            }
        }
        return false;
    }

}