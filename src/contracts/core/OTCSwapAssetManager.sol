// SPDX-License-Identifier: MIT

pragma solidity >=0.8.20;

import {BaseAssetManager} from "./base/BaseAssetManager.sol";
import {OTCSwapInputBuilder} from "./OTCSwapInputBuilder.sol";


/**
 * @title OTCSwapAssetManager
 * @dev Asset manager for otc swap.
 */
contract OTCSwapAssetManager is BaseAssetManager, OTCSwapInputBuilder {
    
    event Swap(
        bytes32 nullifierIn1,
        bytes32 nullifierIn2,
        bytes32 noteOut1,
        bytes32 noteOut2
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
        OTCSwapInputBuilder(P)
    {}


    /**
     * @dev Function for ORC swapping within the darkpool.
     * @param _merkleRoot Merkle root of the merkle tree.
     * @param _aliceNullifier Nullifier of Alice's note for swapping out.
     * @param _aliceOut note of the assets to be swapped in by Alice.
     * @param _bobNullifier Nullifier of Bob's note for swapping out.
     * @param _bobOut note of the assets to be swapped in by Bob.
     * @param _proof Swap proof.
     */
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

        if(_aliceOutFooter == _bobOutFooter) {
            revert NoteFooterDuplicated();
        }
        
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

        emit Swap(_aliceNullifier, _bobNullifier, _aliceOut, _bobOut);
    }
    
}