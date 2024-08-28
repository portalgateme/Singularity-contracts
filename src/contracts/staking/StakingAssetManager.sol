// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {IMerkleTreeOperator} from "../core/interfaces/IMerkleTreeOperator.sol";
import {IComplianceManager} from "../core/interfaces/IComplianceManager.sol";
import {IStakingOperator} from "./interfaces/IStakingOperator.sol";
import {IStakingAssetManager} from "./interfaces/IStakingAssetManager.sol";
import {IZKToken} from "./interfaces/IZKToken.sol";

import {BaseAssetManager} from "../core/base/BaseAssetManager.sol";
import {StakingInputBuilder} from "./StakingInputBuilder.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title Staking Asset Manager Contract
/// @notice Manages staking assets and operations for the system
contract StakingAssetManager is
    BaseAssetManager,
    StakingInputBuilder,
    IStakingAssetManager
{
    using SafeERC20 for IERC20;

    /// @notice The staking operator instance
    IStakingOperator public stakingOperator;

    /// @notice Checks if the address is compliant
    /// @param subject The address to check
    modifier isCompliant(address subject) {
        _validateIsCompliant(subject);
        _;
    }

    /// @notice Checks if the note footer is not used
    /// @param noteFooter The note footer to check
    modifier noteFooterIsNotUsed(bytes32 noteFooter) {
        _validateNoteFooterIsNotUsed(noteFooter);
        _;
    }

    /// @notice Checks if the note is not created
    /// @param note The note to check
    modifier noteIsNotCreated(bytes32 note) {
        _validateNoteIsNotCreated(note);
        _;
    }

    /// @notice Checks if the unlock is allowed
    /// @param timestamp The timestamp to check
    modifier onlyWhenUnlockAvailable(uint256 timestamp) {
        _validateUnlockIsAllowed(timestamp);
        _;
    }

    /// @notice Combines checks for nullifier
    /// @param nullifier The nullifier to check
    modifier checkNullifier(bytes32 nullifier) {
        _validateNullifierIsNotLocked(nullifier);
        _validateNullifierIsNotUsed(nullifier);
        _;
    }

    /// @notice Combines checks for relayer
    /// @param relayer The relayer address to check
    modifier checkRelayer(address relayer) {
        _validateRelayerIsRegistered(relayer);
        _validateSenderIsRelayer(relayer);
        _;
    }

    /// @notice Checks for merkle root
    /// @param merkleRoot The merkle root to check
    modifier checkMerkleRoot(bytes32 merkleRoot) {
        _validateMerkleRootIsAllowed(merkleRoot);
        _;
    }

    /**
     * @notice Initializes the contract with required addresses
     * @param assetPoolERC20_ The address of the ERC20 asset pool
     * @param assetPoolERC721_ The address of the ERC721 asset pool
     * @param assetPoolETH_ The address of the ETH asset pool
     * @param verifierHub_ The address of the verifier hub
     * @param relayerHub_ The address of the relayer hub
     * @param feeManager_ The address of the fee manager
     * @param complianceManager_ The address of the compliance manager
     * @param merkleTreeOperator_ The address of the Merkle tree operator
     * @param mimc254_ The address of the MiMC hash function
     * @param initialOwner_ The address of the initial owner
     * @param stakingOperator_ The address of the staking operator
     */
    constructor(
        address assetPoolERC20_,
        address assetPoolERC721_,
        address assetPoolETH_,
        address verifierHub_,
        address relayerHub_,
        address feeManager_,
        address complianceManager_,
        address merkleTreeOperator_,
        address mimc254_,
        address initialOwner_,
        address stakingOperator_
    )
        BaseAssetManager(
            assetPoolERC20_,
            assetPoolERC721_,
            assetPoolETH_,
            verifierHub_,
            relayerHub_,
            feeManager_,
            complianceManager_,
            merkleTreeOperator_,
            mimc254_,
            initialOwner_
        )
        StakingInputBuilder(P)
    {
        stakingOperator = IStakingOperator(stakingOperator_);
    }

    function getStakingOperator() external view returns (address) {
        return address(stakingOperator);
    }

    function setStakingOperator(address stakingOperator_) external onlyOwner {
        stakingOperator = IStakingOperator(stakingOperator_);
    }

    /**
     * @notice Locks assets using existing note
     * @param args The lock note arguments
     * @param proof The proof for the lock operation
     */
    function lockNote(
        LockNoteArgs calldata args,
        bytes calldata proof
    )
        external
        checkNullifier(args.nullifier)
        checkRelayer(args.relayer)
        noteFooterIsNotUsed(args.zkNoteFooter)
        checkMerkleRoot(args.merkleRoot)
    {
        address zkToken = stakingOperator.getCollateralToken(args.asset);
        if (zkToken == address(0)) {
            revert CollateralTokenMissing();
        }

        _verifyProof(
            proof,
            _buildLockNoteInputs(
                LockNoteRawInputs(
                    args.merkleRoot,
                    args.asset,
                    args.amount,
                    args.nullifier,
                    args.relayer,
                    args.zkNoteFooter,
                    zkToken
                )
            ),
            "zkLockNote"
        );

        _registerNoteFooter(args.zkNoteFooter);
        _postWithdraw(args.nullifier);

        uint256 amountToLock = _forwardFees(
            args.asset,
            args.relayer,
            args.amount,
            args.relayerGasFee,
            0
        );

        bytes32 note = _lock(
            LockArgs(zkToken, amountToLock, 0, args.zkNoteFooter)
        );

        emit Locked(
            address(0),
            args.asset,
            zkToken,
            amountToLock,
            args.nullifier,
            args.zkNoteFooter,
            note
        );
    }

    function lockERC20(
        LockERC20Args calldata args,
        bytes calldata proof
    ) external isCompliant(msg.sender) noteFooterIsNotUsed(args.zkNoteFooter) {
        address zkToken = stakingOperator.getCollateralToken(args.asset);
        if (zkToken == address(0)) {
            revert CollateralTokenMissing();
        }

        _verifyProof(
            proof,
            _buildLockAssetInputs(
                LockAssetRawInputs(
                    msg.sender,
                    args.asset,
                    args.amount,
                    args.zkNoteCommitment,
                    args.zkNoteFooter,
                    zkToken
                )
            ),
            "zkLockAsset"
        );
        
        _registerNoteFooter(args.zkNoteFooter);

        IERC20(args.asset).safeTransferFrom(
            msg.sender,
            address(_assetPoolERC20),
            args.amount
        );

        bytes32 note = _lock(
            LockArgs(
                zkToken,
                args.amount,
                args.zkNoteCommitment,
                args.zkNoteFooter
            )
        );

        emit Locked(msg.sender, args.asset, zkToken, args.amount, 0, args.zkNoteFooter, note);
    }

    function lockETH(
        LockETHArgs calldata args,
        bytes calldata proof
    )
        external
        payable
        isCompliant(msg.sender)
        noteFooterIsNotUsed(args.zkNoteFooter)
    {
        address zkToken = stakingOperator.getCollateralToken(ETH_ADDRESS);
        if (zkToken == address(0)) {
            revert CollateralTokenMissing();
        }

        uint256 amount = msg.value;

        _verifyProof(
            proof,
            _buildLockAssetInputs(
                LockAssetRawInputs(
                    msg.sender,
                    ETH_ADDRESS,
                    amount,
                    args.zkNoteCommitment,
                    args.zkNoteFooter,
                    zkToken
                )
            ),
            "zkLockAsset"
        );

        _registerNoteFooter(args.zkNoteFooter);

        (bool success, ) = address(_assetPoolETH).call{value: amount}("");
        require(success, "depositETH: transfer failed");

        bytes32 note = _lock(
            LockArgs(zkToken, amount, args.zkNoteCommitment, args.zkNoteFooter)
        );

        emit Locked(msg.sender, ETH_ADDRESS, zkToken, amount, 0, args.zkNoteFooter, note);
    }

    /**
     * @notice Unlocks assets
     * @param args The unlock arguments
     * @param proof The proof for the unlock operation
     */
    function unlock(
        UnlockNoteArgs memory args,
        bytes calldata proof
    )
        external
        checkNullifier(args.zkNoteNullifier)
        checkRelayer(args.relayer)
        noteFooterIsNotUsed(args.outNoteFooter)
        onlyWhenUnlockAvailable(block.timestamp)
        checkMerkleRoot(args.merkleRoot)
    {
        address originalToken = stakingOperator.getOriginalToken(
            args.zkNoteAsset
        );
        if (originalToken == address(0)) {
            revert CollateralTokenMissing();
        }

        _verifyProof(
            proof,
            _buildUnlockNoteInputs(
                UnlockNoteRawInputs(
                    args.merkleRoot,
                    args.zkNoteAsset,
                    args.zkNoteAmount,
                    args.zkNoteNullifier,
                    args.relayer,
                    args.outNoteFooter,
                    originalToken
                )
            ),
            "zkUnlockNote"
        );
        _registerNoteFooter(args.outNoteFooter);
        _postWithdraw(args.zkNoteNullifier);


        uint256 amountToUnlock = _forwardFees(
            originalToken,
            args.relayer,
            args.zkNoteAmount,
            args.relayerGasFee,
            0
        );

        bytes32 note = _unlock(
            UnlockArgs(
                args.zkNoteAmount,
                amountToUnlock,
                //args.zkNoteNullifier,
                args.outNoteFooter,
                args.zkNoteAsset,
                originalToken
            )
        );

        emit Unlocked(
            args.zkNoteAsset,
            originalToken,
            amountToUnlock,
            args.zkNoteNullifier,
            args.outNoteFooter,
            note
        );
    }

    struct LockArgs {
        address asset;
        uint256 amount;
        bytes32 zkNoteCommitment;
        bytes32 zkNoteFooter;
    }

    /**
     * @notice Internal function to lock assets
     * @param args The lock parameters
     * @return note The note commitment of the locked note
     */
    function _lock(LockArgs memory args) internal returns (bytes32 note) {
        note = args.zkNoteCommitment;

        if (note == 0) {
            note = _buildNoteForERC20(
                args.asset,
                args.amount,
                args.zkNoteFooter
            );
        }

        _postDeposit(note);

        IZKToken(args.asset).mint(address(_assetPoolERC20), args.amount);
    }

    struct UnlockArgs {
        uint256 fullAmount;
        uint256 amountToUnlock;
        //bytes32 zkNoteNullifier;
        bytes32 noteFooter;
        address zkToken;
        address originalToken;
    }

    /**
     * @notice Internal function to unlock assets
     * @param args The unlock parameters
     * @return The note of the unlocked asset
     */
    function _unlock(UnlockArgs memory args) internal returns (bytes32) {

        bytes32 note = _buildNoteForERC20(
            args.originalToken,
            args.amountToUnlock,
            args.noteFooter
        );

        _postDeposit(note);

        IZKToken(args.zkToken).burn(address(_assetPoolERC20), args.fullAmount);

        return note;
    }

    /**
     * @notice Internal function to validate if the address is compliant
     * @param subject The address to check
     */
    function _validateIsCompliant(address subject) internal {
        if (!_complianceManager.isAuthorized(address(this), subject)) {
            revert InvalidCompliance();
        }
    }

    function _validateUnlockIsAllowed(uint256 timestamp) internal view {
        bool isUnlockAllowed = stakingOperator.isUnlockAllowed(timestamp);
        if (!isUnlockAllowed) {
            revert UnlockNotAllowed();
        }
    }

    function _forwardFees(
        address asset,
        address relayer,
        uint256 amount,
        uint256 relayerGasFee,
        uint256 forceServiceFee
    ) internal returns (uint256) {
        (
            uint256 amountToLock,
            uint256 serviceFee,
            uint256 relayerRefund
        ) = _feeManager.calculateFeeForceServiceFee(
                amount,
                relayerGasFee,
                forceServiceFee
            );

        if (serviceFee > 0) {
            if (asset == ETH_ADDRESS) {
                _assetPoolETH.release(
                    payable(address(_feeManager)),
                    serviceFee
                );
            } else {
                _assetPoolERC20.release(
                    asset,
                    address(_feeManager),
                    serviceFee
                );
            }
        }

        if (relayerRefund > 0) {
            if (asset == ETH_ADDRESS) {
                _assetPoolETH.release(payable(relayer), relayerRefund);
            } else {
                _assetPoolERC20.release(asset, relayer, relayerRefund);
            }
        }

        return amountToLock;
    }
}
