// SPDX-License-Identifier: MIT

pragma solidity >=0.8.20;

import {BaseAssetManager} from "../../core/base/BaseAssetManager.sol";
import {RocketPoolStakeInputBuilder} from "./RocketPoolStakeInputBuilder.sol";
import {IFeeManager} from "../../core/interfaces/IFeeManager.sol";
import {IRocketStorage} from "./interfaces/IRocketStorage.sol";
import {IRocketDepositPool} from "./interfaces/IRocketDepositPool.sol";
import {IRocketTokenRETH} from "./interfaces/IRocketTokenRETH.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title RocketPoolStakeAssetManager
 * @dev Asset manager for stake/withdraw to/from rocket pool.
 */
contract RocketPoolStakeAssetManager is BaseAssetManager, RocketPoolStakeInputBuilder {
    using SafeERC20 for IERC20;

    address private _rocketStorageAddress;

    event RocketDeposit(
        bytes32 nullifier,
        uint256 amount,
        bytes32 noteFooter,
        bytes32 noteCommitment
    );

    event RocketWithdrawal(
        bytes32 nullifier,
        uint256 amount,
        bytes32 noteFooter,
        bytes32 noteCommitment
    );
    
    error AmountNotCorrect();

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
        address initialOwner,
        address rocketStorageAddress
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
        RocketPoolStakeInputBuilder(P)
    {
        _rocketStorageAddress = rocketStorageAddress;
    }
    
    function rocketPoolDeposit (
        bytes calldata _proof,
        bytes32 _merkleRoot,
        bytes32 _nullifier,
        uint256 _amount,
        bytes32 _noteFooter,
        address payable _relayer,
        uint256 _gasRefund
    ) external {
        _validateMerkleRootIsAllowed(_merkleRoot);
        _validateNullifierIsNotUsed(_nullifier);
        _validateNullifierIsNotLocked(_nullifier);
        _validateNoteFooterIsNotUsed(_noteFooter);
        _validateRelayerIsRegistered(_relayer);
        if(msg.sender != _relayer) {
            revert RelayerMismatch();
        }

        IRocketDepositPool rocketDepositPool = IRocketDepositPool(IRocketStorage(_rocketStorageAddress)
            .getAddress(keccak256(abi.encodePacked("contract.address", "rocketDepositPool"))));

        if (_amount == 0 || _amount > rocketDepositPool.getMaximumDepositAmount()) {
            revert AmountNotCorrect();
        }

        RocketPoolStakeRawInputs memory inputs = RocketPoolStakeRawInputs(
            _merkleRoot,
            ETH_ADDRESS,
            _amount,
            _nullifier,
            _noteFooter,
            _relayer
        );

        _verifyProof(_proof, _buildRocketPoolStakeInputs(inputs), "rocketPoolStake");
        
        _registerNoteFooter(_noteFooter);
        _postWithdraw(_nullifier);

        _assetPoolETH.release(payable(address(this)), _amount);

        address rocketTokenRETH = IRocketStorage(_rocketStorageAddress)
            .getAddress(keccak256(abi.encodePacked("contract.address", "rocketTokenRETH")));

        uint256 actualAmount;
        uint256 serviceFee;
        (actualAmount, serviceFee, ) = IFeeManager(_feeManager)
            .calculateFee(_amount, _gasRefund);

        uint256 initRETHBalance = IERC20(rocketTokenRETH).balanceOf(address(this));
        rocketDepositPool.deposit{value: actualAmount}();
        uint256 finalRETHBalance = IERC20(rocketTokenRETH).balanceOf(address(this)) - initRETHBalance;

        IERC20(rocketTokenRETH).safeTransfer(address(_assetPoolERC20),finalRETHBalance);

        (bool success, ) = payable(address(_feeManager)).call{value: serviceFee}("");
        require(success, "BaseAssetManager: Failed to send Ether");
        (success, ) = payable(_relayer).call{value: _gasRefund}("");
        require(success, "BaseAssetManager: Failed to send Ether");

        bytes32 noteCommitment = _buildNoteForERC20(
            rocketTokenRETH,
            finalRETHBalance,
            _noteFooter
        );

        _postDeposit(noteCommitment);

        emit RocketDeposit(_nullifier, finalRETHBalance, _noteFooter, noteCommitment);
    }

    function rocketPoolWithdraw (
        bytes calldata _proof,
        bytes32 _merkleRoot,
        bytes32 _nullifier,
        uint256 _amount,
        bytes32 _noteFooter,
        address payable _relayer,
        uint256 _gasRefund
    ) external {
        _validateMerkleRootIsAllowed(_merkleRoot);
        _validateNullifierIsNotUsed(_nullifier);
        _validateNullifierIsNotLocked(_nullifier);
        _validateNoteFooterIsNotUsed(_noteFooter);
        _validateRelayerIsRegistered(_relayer);
        if(msg.sender != _relayer) {
            revert RelayerMismatch();
        }

        address rocketTokenRETH = IRocketStorage(_rocketStorageAddress)
            .getAddress(keccak256(abi.encodePacked("contract.address", "rocketTokenRETH")));

        if (_amount == 0 ) {
            revert AmountNotCorrect();
        }

        RocketPoolStakeRawInputs memory inputs = RocketPoolStakeRawInputs(
            _merkleRoot,
            rocketTokenRETH,
            _amount,
            _nullifier,
            _noteFooter,
            _relayer
        );

        _verifyProof(_proof, _buildRocketPoolStakeInputs(inputs), "rocketPoolStake");
        _postWithdraw(_nullifier);
        _registerNoteFooter(_noteFooter);

        _assetPoolERC20.release(rocketTokenRETH, address(this), _amount);
        
        uint256 initETHBalance = address(this).balance;
        IRocketTokenRETH(rocketTokenRETH).burn(_amount);
        uint256 finalETHBalance = address(this).balance - initETHBalance;

        uint256 actualAmount;
        uint256 serviceFee;
        (actualAmount, serviceFee, ) = IFeeManager(_feeManager)
            .calculateFee(finalETHBalance, _gasRefund);

        (bool success, ) = payable(address(_assetPoolETH)).call{value: actualAmount}("");
        require(success, "BaseAssetManager: Failed to send Ether");
        (success, ) = payable(address(_feeManager)).call{value: serviceFee}("");
        require(success, "BaseAssetManager: Failed to send Ether");
        (success, ) = payable(_relayer).call{value: _gasRefund}("");
        require(success, "BaseAssetManager: Failed to send Ether");

        bytes32 noteCommitment = _buildNoteForERC20(
            ETH_ADDRESS,
            actualAmount,
            _noteFooter
        );

        _postDeposit(noteCommitment);

        emit RocketWithdrawal(_nullifier, actualAmount, _noteFooter, noteCommitment);
    }

    function setRocketStorageAddress(address rocketStorageAddress) external onlyOwner {
        _rocketStorageAddress = rocketStorageAddress;
    }

    function getRocketStorageAddress() public view returns (address) {
        return _rocketStorageAddress;
    }   
}
