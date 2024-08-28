// SPDX-License-Identifier: MIT

pragma solidity >=0.8.20;

import {BaseAssetManager} from "./base/BaseAssetManager.sol";
import {DarkpoolInputBuilder} from "./DarkpoolInputBuilder.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title DarkpoolAssetManager
 * @dev Asset manager for deposit/withdrawal/transfer/join/split/join-split.
 */
contract DarkpoolAssetManager is BaseAssetManager, DarkpoolInputBuilder {
    using SafeERC20 for IERC20;

    event Deposit(
        address depositor,
        bytes32 noteOut, 
        uint256 amount, 
        address asset
    );

    event Withdraw(
        bytes32 nullifierIn,
        uint256 amount,
        address asset,
        address recipient
    );

    event Transfer(
        bytes32 nullifierIn, 
        uint256 amount,
        address asset,
        bytes32 noteOut,
        bytes32 noteFooter
    );

    event Split(
        bytes32 nullifierIn,
        bytes32 noteOut1,
        bytes32 noteOut2
    );

    event JoinSplit(
        bytes32 nullifierIn1,
        bytes32 nullifierIn2,
        bytes32 noteOut1,
        bytes32 noteOut2
    );

    event Join(
        bytes32 nullifierIn1,
        bytes32 nullifierIn2,
        bytes32 noteOut1
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
        DarkpoolInputBuilder(P)
    {}

    /**
     * @dev Function to deposit ERC20 tokens, guarded by the compliance manager.
     * @param _asset Address of the ERC20 token.
     * @param _amount Amount of ERC20 tokens to be deposited.
     * @param _noteCommitment Deposit note for commiting to the merkle tree.
     * @param _proof Deposit proof.
     */
    function depositERC20(
        address _asset,
        uint256 _amount,
        bytes32 _noteCommitment,
        bytes32 _noteFooter,
        bytes calldata _proof
    ) public {
        require(
            _complianceManager.isAuthorized(address(this), msg.sender),
            "BaseAssetManager: invalid credential"
        );
        _validateNoteIsNotCreated(_noteCommitment);
        _validateNoteFooterIsNotUsed(_noteFooter);

        DepositRawInputs memory inputs = DepositRawInputs(
            msg.sender,
            _noteCommitment,
            _asset,
            _amount,
            _noteFooter
        );

        _verifyProof(_proof, _buildDepositInputs(inputs), "deposit");
        _registerNoteFooter(_noteFooter);

        IERC20(_asset).safeTransferFrom(
            msg.sender,
            address(_assetPoolERC20),
            _amount
        );

        _postDeposit(_noteCommitment);

        emit Deposit(msg.sender, _noteCommitment, _amount, _asset);
    }

    /**
     * @dev Function to deposit ETH, guarded by the compliance manager.
     * @param _noteCommitment Deposit note for commiting to the merkle tree.
     * @param _proof Deposit proof.
     */
    function depositETH(
        bytes32 _noteCommitment,
        bytes32 _noteFooter,
        bytes calldata _proof
    ) public payable {
        require(
            _complianceManager.isAuthorized(address(this), msg.sender),
            "BaseAssetManager: invalid credential"
        );
        _validateNoteIsNotCreated(_noteCommitment);
        _validateNoteFooterIsNotUsed(_noteFooter);

        DepositRawInputs memory inputs = DepositRawInputs(
            msg.sender,
            _noteCommitment,
            ETH_ADDRESS,
            msg.value,
            _noteFooter
        );

        _verifyProof(_proof, _buildDepositInputs(inputs), "deposit");
        _registerNoteFooter(_noteFooter);

        (bool success, ) = address(_assetPoolETH).call{value: msg.value}("");
        require(success, "depositETH: transfer failed");

        _postDeposit(_noteCommitment);

        emit Deposit(msg.sender, _noteCommitment, msg.value, ETH_ADDRESS);
    }

    /**
     * @dev Function to withdraw ERC20 tokens, guarded by the compliance manager.
     * @param _asset Address of the ERC20 token.
     * @param _proof Withdraw proof.
     * @param _merkleRoot Merkle root of the merkle tree.
     * @param _nullifier Nullifier of the note to be withdrawn.
     * @param _recipient Address of the recipient.
     * @param _relayer Address of the relayer.
     * @param _amount Amount of ERC20 tokens to be withdrawn.
     * @param _relayerGasFee Gas fee to refund to the relayer.
     */
    function withdrawERC20(
        address _asset,
        bytes calldata _proof,
        bytes32 _merkleRoot,
        bytes32 _nullifier,
        address _recipient,
        address _relayer,
        uint256 _amount,
        uint256 _relayerGasFee
    ) public {
        require(
            _complianceManager.isAuthorized(address(this), _recipient),
            "BaseAssetManager: invalid credential"
        );

        _validateMerkleRootIsAllowed(_merkleRoot);
        _validateNullifierIsNotUsed(_nullifier);
        _validateNullifierIsNotLocked(_nullifier);
        _validateRelayerIsRegistered(_relayer);
        _validateSenderIsRelayer(_relayer);

        WithdrawRawInputs memory inputs = WithdrawRawInputs(
            _recipient,
            _merkleRoot,
            _asset,
            _amount,
            _nullifier,
            _relayer
        );

        _verifyProof(_proof, _buildWithdrawInputs(inputs), "withdraw");

        _postWithdraw(_nullifier);

        _releaseERC20WithFee(
            _asset,
            _recipient,
            _relayer,
            _relayerGasFee,
            _amount
        );

        emit Withdraw(_nullifier, _amount, _asset, _recipient);
    }

    /**
     * @dev Function to withdraw ETH from darkpool, guarded by the compliance manager.
     * @param _proof Withdraw proof.
     * @param _merkleRoot Merkle root of the merkle tree.
     * @param _nullifier Nullifier of the note to be withdrawn.
     * @param _recipient Address of the recipient.
     * @param _relayer Address of the relayer.
     * @param _relayerGasFee Gas fee to refund to the relayer.
     * @param _amount Amount of ETH to be withdrawn.
     */
    function withdrawETH(
        bytes calldata _proof,
        bytes32 _merkleRoot,
        bytes32 _nullifier,
        address payable _recipient,
        address payable _relayer,
        uint256 _relayerGasFee,
        uint256 _amount
    ) public {
        require(
            _complianceManager.isAuthorized(address(this), _recipient),
            "BaseAssetManager: invalid credential"
        );

        _validateMerkleRootIsAllowed(_merkleRoot);
        _validateNullifierIsNotUsed(_nullifier);
        _validateNullifierIsNotLocked(_nullifier);
        _validateRelayerIsRegistered(_relayer);
        _validateSenderIsRelayer(_relayer);

        WithdrawRawInputs memory inputs = WithdrawRawInputs(
            _recipient,
            _merkleRoot,
            ETH_ADDRESS,
            _amount,
            _nullifier,
            _relayer
        );

        _verifyProof(_proof, _buildWithdrawInputs(inputs), "withdraw");
        
        _postWithdraw(_nullifier);

        _releaseETHWithFee(_recipient, _relayer, _relayerGasFee, _amount);

        emit Withdraw(_nullifier, _amount, ETH_ADDRESS, _recipient);
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
        uint256 _amount,
        bytes32 _noteOut,
        bytes32 _noteFooter,
        bytes calldata _proof
    ) public {
        _validateMerkleRootIsAllowed(_merkleRoot);
        _validateNullifierIsNotUsed(_nullifierIn);
        _validateNullifierIsNotLocked(_nullifierIn);
        _validateNoteIsNotCreated(_noteOut);
        _validateNoteFooterIsNotUsed(_noteFooter);

        TransferRawInputs memory inputs = TransferRawInputs(
            _merkleRoot,
            _asset,
            _amount,
            _nullifierIn,
            _noteOut,
            _noteFooter
        );

        _verifyProof(_proof, _buildTransferInputs(inputs), "transfer");
        _registerNoteFooter(_noteFooter);
        _postWithdraw(_nullifierIn);
        _postDeposit(_noteOut);

        emit Transfer(
            _nullifierIn,
            _amount,
            _asset,
            _noteOut,
            _noteFooter
        );
    }

    /**
     * @dev Function to split a note into two.
     * @param _merkleRoot Merkle root of the merkle tree.
     * @param _nullifierIn1 Nullifier of the input note.
     * @param _noteOut1 note of the first output note.
     * @param _noteOut2 note of the second output note.
     * @param _proof Split proof.
     */
    function split(
        bytes32 _merkleRoot,
        bytes32 _nullifierIn1,
        bytes32 _noteOut1,
        bytes32 _noteOut2,
        bytes32 _noteFooter1,
        bytes32 _noteFooter2,
        bytes calldata _proof
    ) public payable {
        _validateMerkleRootIsAllowed(_merkleRoot);
        _validateNullifierIsNotUsed(_nullifierIn1);
        _validateNullifierIsNotLocked(_nullifierIn1);
        _validateNoteIsNotCreated(_noteOut1);
        _validateNoteIsNotCreated(_noteOut2);
        _validateNoteFooterIsNotUsed(_noteFooter1);
        _validateNoteFooterIsNotUsed(_noteFooter2);

        if(_noteFooter1 == _noteFooter2) {
            revert NoteFooterDuplicated();
        }

        SplitRawInputs memory inputs = SplitRawInputs(
            _merkleRoot,
            _nullifierIn1,
            _noteOut1,
            _noteOut2,
            _noteFooter1,
            _noteFooter2
        );

        _verifyProof(_proof, _buildSplitInputs(inputs), "split");
        _registerNoteFooter(_noteFooter1);
        _registerNoteFooter(_noteFooter2);
        _postWithdraw(_nullifierIn1);
        _postDeposit(_noteOut1);
        _postDeposit(_noteOut2);

        emit Split(_nullifierIn1, _noteOut1, _noteOut2);
    }

    /**
     * @dev Function to reassemble two notes' assets.
     * @param _merkleRoot Merkle root of the merkle tree.
     * @param _nullifierIn1 Nullifier of the first input note.
     * @param _nullifierIn2 Nullifier of the second input note.
     * @param _noteOut1 note of the first output note.
     * @param _noteOut2 note of the second output note.
     * @param _proof Join proof.
     */
    function joinSplit(
        bytes32 _merkleRoot,
        bytes32 _nullifierIn1,
        bytes32 _nullifierIn2,
        bytes32 _noteOut1,
        bytes32 _noteOut2,
        bytes32 _noteFooter1,
        bytes32 _noteFooter2,
        bytes calldata _proof
    ) public payable {
        _validateMerkleRootIsAllowed(_merkleRoot);
        _validateNullifierIsNotUsed(_nullifierIn1);
        _validateNullifierIsNotUsed(_nullifierIn2);
        _validateNullifierIsNotLocked(_nullifierIn1);
        _validateNullifierIsNotLocked(_nullifierIn2);
        _validateNoteIsNotCreated(_noteOut1);
        _validateNoteIsNotCreated(_noteOut2);
        _validateNoteFooterIsNotUsed(_noteFooter1);
        _validateNoteFooterIsNotUsed(_noteFooter2);

        if (_noteFooter1 == _noteFooter2) {
            revert NoteFooterDuplicated();
        }

        JoinSplitRawInputs memory inputs = JoinSplitRawInputs(
            _merkleRoot,
            _nullifierIn1,
            _nullifierIn2,
            _noteOut1,
            _noteOut2,
            _noteFooter1,
            _noteFooter2
        );

        _verifyProof(_proof, _buildJoinSplitInputs(inputs), "joinSplit");
        _registerNoteFooter(_noteFooter1);
        _registerNoteFooter(_noteFooter2);
        _postWithdraw(_nullifierIn1);
        _postWithdraw(_nullifierIn2);
        _postDeposit(_noteOut1);
        _postDeposit(_noteOut2);

        emit JoinSplit(_nullifierIn1, _nullifierIn2, _noteOut1, _noteOut2);
    }

    /**
     * @dev Function to join two notes into one.
     * @param _merkleRoot Merkle root of the merkle tree.
     * @param _nullifierIn1 Nullifier of the first input note.
     * @param _nullifierIn2 Nullifier of the second input note.
     * @param _noteOut note of the output note.
     * @param _proof Join proof.
     */
    function join(
        bytes32 _merkleRoot,
        bytes32 _nullifierIn1,
        bytes32 _nullifierIn2,
        bytes32 _noteOut,
        bytes32 _noteFooter,
        bytes calldata _proof
    ) public payable {
        _validateMerkleRootIsAllowed(_merkleRoot);
        _validateNullifierIsNotUsed(_nullifierIn1);
        _validateNullifierIsNotUsed(_nullifierIn2);
        _validateNullifierIsNotLocked(_nullifierIn1);
        _validateNullifierIsNotLocked(_nullifierIn2);
        _validateNoteIsNotCreated(_noteOut);
        _validateNoteFooterIsNotUsed(_noteFooter);

        JoinRawInputs memory inputs = JoinRawInputs(
            _merkleRoot,
            _nullifierIn1,
            _nullifierIn2,
            _noteOut,
            _noteFooter
        );

        _verifyProof(_proof, _buildJoinInputs(inputs), "join");

        _registerNoteFooter(_noteFooter);
        _postWithdraw(_nullifierIn1);
        _postWithdraw(_nullifierIn2);
        _postDeposit(_noteOut);

        emit Join(_nullifierIn1, _nullifierIn2, _noteOut);
    }

    /**
     * @dev Function for ORC swapping within the darkpool.
     * @param _merkleRoot Merkle root of the merkle tree.
     * @param _aliceNullifier Nullifier of Alice's note for swapping out.
     * @param _aliceOut note of the assets to be swapped in by Alice.
     * @param _bobNullifier Nullifier of Bob's note for swapping out.
     * @param _bobOut note of the assets to be swapped in by Bob.
     * @param _proof Swap proof.
     
    function swap(
        bytes32 _merkleRoot,
        bytes32 _aliceNullifier,
        bytes32 _aliceOut,
        bytes32 _aliceOutFooter,

        bytes32 _bobNullifier,
        bytes32 _bobOut,
        bytes32 _bobOutFooter,
        bytes calldata _proof
    ) public payable {
        _validateMerkleRootIsAllowed(_merkleRoot);
        _validateNullifierIsNotUsed(_aliceNullifier);
        _validateNullifierIsNotUsed(_bobNullifier);
        _validateNoteIsNotCreated(_aliceOut);
        _validateNoteIsNotCreated(_bobOut);
        _validateNoteFooterIsNotUsed(_aliceOutFooter);
        _validateNoteFooterIsNotUsed(_bobOutFooter);

        SwapRawInputs memory inputs = SwapRawInputs(
            _merkleRoot,
            _aliceNullifier,
            _aliceOut,
            _aliceOutFooter,
            _bobNullifier,
            _bobOut,
            _bobOutFooter
        );

        _verifyProof(_proof, _buildSwapInputs(inputs), "swap");

        _registerNoteFooter(_aliceOutFooter);
        _registerNoteFooter(_bobOutFooter);
        _postWithdraw(_aliceNullifier);
        _postWithdraw(_bobNullifier);
        _postDeposit(_aliceOut);
        _postDeposit(_bobOut);
    }*/
}
