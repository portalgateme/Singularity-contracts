// SPDX-License-Identifier: MIT

pragma solidity >=0.8.20;

import {BaseAssetManager} from "./base/BaseAssetManager.sol";
import {NftInputBuilder} from "./NftInputBuilder.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title DarkpoolAssetManager
 * @dev Asset manager for deposit/withdrawal/transfer/join/split/join-split.
 */
contract NftAssetManager is BaseAssetManager, NftInputBuilder {
    using SafeERC20 for IERC20;

    event NftWithdraw(
        bytes32 nullifierIn,
        uint256 amount,
        address nftAsset,
        address recipient
    );

    event NftTransfer(
        bytes32 nullifierIn, 
        uint256 amount,
        address asset,
        bytes32 noteOut,
        bytes32 noteFooter
    );

    constructor(
        address assetPoolERC20,
        address assetPoolERC721,
        address assetPoolETH,
        address verifierHub,
        address relayerHub,
        address feeManager,
        address comlianceManager,
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
            comlianceManager,
            merkleTreeOperator,
            mimc254,
            initialOwner
        )
        NftInputBuilder(P)
    {}


    /**
     * @dev Function to withdraw ERC20 tokens, guarded by the compliance manager, 
     *      No relayer involved
     * @param _asset Address of the ERC20 token.
     * @param _proof Withdraw proof.
     * @param _merkleRoot Merkle root of the merkle tree.
     * @param _nullifier Nullifier of the note to be withdrawn.
     * @param _recipient Address of the recipient.
     * @param _nftID NFT ID.
     */
    function nftWithdraw(
        address _asset,
        bytes calldata _proof,
        bytes32 _merkleRoot,
        bytes32 _nullifier,
        address _recipient,
        uint256 _nftID
    ) public {
        require(
            _complianceManager.isAuthorized(address(this), _recipient),
            "BaseAssetManager: invalid credential"
        );

        _validateMerkleRootIsAllowed(_merkleRoot);
        _validateNullifierIsNotUsed(_nullifier);
        _validateNullifierIsNotLocked(_nullifier);

        NftWithdrawRawInputs memory inputs = NftWithdrawRawInputs(
            _recipient,
            _merkleRoot,
            _asset,
            _nftID,
            _nullifier
        );

        _verifyProof(_proof, _buildNftWithdrawInputs(inputs), "withdrawNft");

        _postWithdraw(_nullifier);

        _assetPoolERC721.release(_asset, _recipient, _nftID);

        emit NftWithdraw(_nullifier, _nftID, _asset, _recipient);
    }

    /**
     * @dev Function to transfer assets within the darkpool.
     * @param _merkleRoot Merkle root of the merkle tree.
     * @param _nullifierIn Nullifier of the input note.
     * @param _noteOut note of the transfee.
     * @param _proof Transfer proof.
     */
    function transfer(
        bytes32 _merkleRoot,
        bytes32 _nullifierIn,
        address _asset,
        uint256 _nftID,
        bytes32 _noteOut,
        bytes32 _noteFooter,
        bytes calldata _proof
    ) public {
        _validateMerkleRootIsAllowed(_merkleRoot);
        _validateNullifierIsNotUsed(_nullifierIn);
        _validateNullifierIsNotLocked(_nullifierIn);
        _validateNoteIsNotCreated(_noteOut);
        _validateNoteFooterIsNotUsed(_noteFooter);

        NftTransferRawInputs memory inputs = NftTransferRawInputs(
            _merkleRoot,
            _asset,
            _nftID,
            _nullifierIn,
            _noteOut,
            _noteFooter
        );

        _verifyProof(_proof, _buildNftTransferInputs(inputs), "transferNft");
        _registerNoteFooter(_noteFooter);
        _postWithdraw(_nullifierIn);
        _postDeposit(_noteOut);

        emit NftTransfer(
            _nullifierIn,
            _nftID,
            _asset,
            _noteOut,
            _noteFooter
        );
    }

}
