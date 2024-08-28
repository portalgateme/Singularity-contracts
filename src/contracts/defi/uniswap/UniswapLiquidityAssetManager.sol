// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

// Internal imports
import {UniswapCoreAssetManager} from "./UniswapCoreAssetManager.sol";
import {INonfungiblePositionManager} from "./interfaces/INonfungiblePositionManager.sol";

// External imports
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title UniswapLiquidityAssetManager
 * @dev Extends UniswapCoreAssetManager to manage liquidity on Uniswap.
 *      Handles liquidity provision, fee collection, and liquidity removal.
 */
contract UniswapLiquidityAssetManager is UniswapCoreAssetManager {
    /**
     * * LIBRARIES
     */

    using SafeERC20 for IERC20;

    /**
     * * STRUCTS
     */

    struct UniswapLPData {
        address token1;
        address token2;
    }

    struct UniswapLiquidityProvisionArgs {
        // data of the note that will be used for liquidity provision as first token
        UniswapNoteData noteData1;
        // data of the note that will be used for liquidity provision as second token
        UniswapNoteData noteData2;
        // address of the relayer
        address payable relayer;
        // gas fees of the relayer
        uint256[2] relayerGasFees;
        // merkle root of the merkle tree that the commitment of the note is included
        bytes32 merkleRoot;
        // note footer of the note that will be created after mint (both tokens)
        bytes32[2] changeNoteFooters;
        // tick min of the liquidity provision
        int24 tickMin;
        // tick max of the liquidity provision
        int24 tickMax;
        // deadline of the liquidity provision
        uint256 deadline;
        // note footer of the NFT position note that will be created after liquidity provision
        bytes32 positionNoteFooter;
        // pool fee of the liquidity provision (Uniswap)
        uint24 poolFee;
        // minimum amount of the asset that will be minted as liquidity
        uint256[2] amountsMin;
    }

    struct UniswapCollectFeesArgs {
        // merkle root of the merkle tree that the commitment of the NFT position note is included
        bytes32 merkleRoot;
        // NFT position note id
        uint256 tokenId;
        // note footer of the notes that will be created after collecting fees (both tokens)
        bytes32[2] feeNoteFooters;
        // gas fees of the relayer (from both tokens)
        uint256[2] relayerGasFees;
        // address of the relayer
        address payable relayer;
    }

    struct UniswapRemoveLiquidityArgs {
        // merkle root of the merkle tree that the commitment of the NFT position note is included
        bytes32 merkleRoot;
        // NFT position note
        UniswapNoteData positionNote;
        // note footer of the notes that will be created after removing liquidity (both tokens)
        bytes32[2] outNoteFooters;
        // gas fees of the relayer (from both tokens)
        uint256[2] relayerGasFees;
        // deadline of the remove liquidity
        uint256 deadline;
        // address of the relayer
        address payable relayer;
        // minimum amount of the asset that will be received after remove liquidity
        uint256[2] amountsMin;
    }

    /**
     * * STATE VARIABLES
     */

    mapping(uint256 tokenId => UniswapLPData data) public uniswapLPData;
    INonfungiblePositionManager public immutable nonfungiblePositionManager;

    /**
     * * EVENTS
     */

    event UniswapLiquidityProvision(
        uint256 tokenId,
        bytes32 positionNote,
        bytes32[2] nullifiers,
        uint256[2] changeAmounts,
        bytes32[2] changeNoteCommitments,
        bytes32[2] changeNoteFooters
    );

    event UniswapCollectFees(
        uint256 tokenId,
        address[2] assets,
        uint256[2] amounts,
        bytes32[2] feeNoteCommitments,
        bytes32[2] feeNoteFooters
    );

    event UniswapRemoveLiquidity(
        uint256 tokenId,
        bytes32 positionNullifier,
        uint256[2] amounts,
        bytes32[2] outNoteCommitments,
        bytes32[2] outNoteFooters
    );

    /**
     * * CONSTRUCTOR
     */

    constructor(
        address assetPoolERC20,
        address assetPoolERC721,
        address assetPoolETH,
        address verifierHub,
        address relayerHub,
        address feeManager,
        address complianceManager,
        address merkleTreeOperator,
        address mimcBn254,
        address initialOwner,
        INonfungiblePositionManager _nonfungiblePositionManager,
        address wethAddress
    )
        UniswapCoreAssetManager(
            assetPoolERC20,
            assetPoolERC721,
            assetPoolETH,
            verifierHub,
            relayerHub,
            feeManager,
            complianceManager,
            merkleTreeOperator,
            mimcBn254,
            initialOwner,
            wethAddress
        )
    {
        nonfungiblePositionManager = _nonfungiblePositionManager;
    }

    /**
     * * HANDLERS (LIQUIDITY PROVISION)
     */

    /**
     * @dev Provisions liquidity to Uniswap by minting a new LP token.
     * Requires validation of input arguments, verification of proof, and preparation of liquidity provision arguments.
     * Mints the LP token and manages related assets and notes.
     * @param args Arguments required for liquidity provision including notes data,
     *        relayer information, fee details, and Uniswap pool parameters.
     * @param proof Cryptographic proof to verify the operation.
     */
    function uniswapLiquidityProvision(
        UniswapLiquidityProvisionArgs memory args,
        bytes calldata proof
    ) public returns (uint256 tokenId) {
        _validateLiquidityProvisionArgs(args);
        _verifyProofForLiquidityProvision(args, proof);

        INonfungiblePositionManager.MintParams memory mintParams;
        uint8[2] memory originalIndices;

        (
            mintParams,
            //feesDetails,
            originalIndices
        ) = _releaseFundsAndPrepareLiquidityProvisionArgs(args);


        bytes32[2] memory changeNoteCommitments;
        uint256[2] memory changeAmounts;
        bytes32 positionNote;

        (
            changeNoteCommitments,
            changeAmounts,
            positionNote,
            tokenId
        ) = _executeLPMint(args, mintParams, originalIndices);

        emit UniswapLiquidityProvision(
            tokenId,
            positionNote,
            [args.noteData1.nullifier, args.noteData2.nullifier],
            [changeAmounts[originalIndices[0]], changeAmounts[originalIndices[1]]],
            [changeNoteCommitments[originalIndices[0]], changeNoteCommitments[originalIndices[1]]],
            args.changeNoteFooters
        );
    }

    /**
     * * HANDLERS (COLLECT FEES)
     */

    /**
     * @dev Collects fees accrued from liquidity provision on Uniswap.
     * Validates arguments, verifies proof, and handles the transfer of collected fees to the asset vault.
     * @param args Arguments for fee collection including the LP token ID, fee note footers, and relayer information.
     * @param proof Cryptographic proof to verify the fee collection.
     * @return dataToken1 Information about the first token's fee collection
     *         including the amount transferred to the vault and fee details.
     * @return dataToken2 Information about the second token's fee collection
     *         including the amount transferred to the vault and fee details.
     */
    function uniswapCollectFees(
        UniswapCollectFeesArgs memory args,
        bytes calldata proof
    )
        public
        returns (
            TransferFundsToVaultWithFeesAndCreateNoteData memory dataToken1,
            TransferFundsToVaultWithFeesAndCreateNoteData memory dataToken2
        )
    {
        _validateCollectFeesArgs(args);
        _verifyProofForCollectFees(args, proof);
        _releaseERC721Position(args.tokenId);

        _registerNoteFooter(args.feeNoteFooters[0]);
        _registerNoteFooter(args.feeNoteFooters[1]);

        (uint256 amount0, uint256 amount1) = nonfungiblePositionManager.collect(
            _prepareCollectFeeParams(args.tokenId)
        );

        _transferERC721PositionToVault(args.tokenId);

        (dataToken1) = _transferFundsToVaultWithFeesAndCreateNote(
            uniswapLPData[args.tokenId].token1,
            amount0,
            args.feeNoteFooters[0],
            args.relayerGasFees[0],
            args.relayer
        );

        (dataToken2) = _transferFundsToVaultWithFeesAndCreateNote(
            uniswapLPData[args.tokenId].token2,
            amount1,
            args.feeNoteFooters[1],
            args.relayerGasFees[1],
            args.relayer
        );

        emit UniswapCollectFees(
            args.tokenId,
            [uniswapLPData[args.tokenId].token1, uniswapLPData[args.tokenId].token2],
            [dataToken1.actualAmount, dataToken2.actualAmount],
            [dataToken1.noteCommitment, dataToken2.noteCommitment],
            args.feeNoteFooters
        );
    }

    /**
     * * HANDLERS (REMOVE LIQUIDITY)
     */

    /**
     * @dev Removes liquidity from Uniswap, handling the return of underlying assets
     *      and the management of related notes.
     * Validates arguments, verifies proof, and executes liquidity removal.
     * @param args Arguments for liquidity removal including the LP token ID, note data, and relayer information.
     * @param proof Cryptographic proof to verify the operation.
     * @return dataToken1 Information about the first token's return
     *         including the amount transferred to the vault and fee details.
     * @return dataToken2 Information about the second token's return
     *         including the amount transferred to the vault and fee details.
     */
    function uniswapRemoveLiquidity(
        UniswapRemoveLiquidityArgs memory args,
        bytes calldata proof
    )
        public
        returns (
            TransferFundsToVaultWithFeesAndCreateNoteData memory dataToken1,
            TransferFundsToVaultWithFeesAndCreateNoteData memory dataToken2
        )
    {
        _validateRemoveLiquidityArgs(args);
        _verifyProofForRemoveLiquidity(args, proof);
        
        _postWithdraw(args.positionNote.nullifier);
        _registerNoteFooter(args.outNoteFooters[0]);
        _registerNoteFooter(args.outNoteFooters[1]);

        _releaseERC721Position(args.positionNote.amount);

        (
            ,
            ,
            address token1,
            address token2,
            ,
            ,
            ,
            uint128 liquidity,
            ,
            ,
            ,

        ) = nonfungiblePositionManager.positions(args.positionNote.amount);

        nonfungiblePositionManager.decreaseLiquidity(
            _prepareRemoveLiquidityParams(args, liquidity)
        );

        (uint256 amount0, uint256 amount1) = nonfungiblePositionManager.collect(
            _prepareCollectFeeParams(args.positionNote.amount)
        );

        _burnERC721Position(args.positionNote.amount);

        (dataToken1) = _transferFundsToVaultWithFeesAndCreateNote(
            token1,
            amount0,
            args.outNoteFooters[0],
            args.relayerGasFees[0],
            args.relayer
        );

        (dataToken2) = _transferFundsToVaultWithFeesAndCreateNote(
            token2,
            amount1,
            args.outNoteFooters[1],
            args.relayerGasFees[1],
            args.relayer
        );

        emit UniswapRemoveLiquidity(
            args.positionNote.amount,
            args.positionNote.nullifier,
            [dataToken1.actualAmount, dataToken2.actualAmount],
            [dataToken1.noteCommitment, dataToken2.noteCommitment],
            args.outNoteFooters
        );
    }

    /**
     * * UTILS (ARGS VALIDATORS)
     */

    /**
     * @dev Validates the arguments for provisioning liquidity. Ensures that the merkle root is allowed,
     * nullifiers are not used, note footers are not used, and the relayer is registered.
     * @param args The arguments for the liquidity provision operation.
     */
    function _validateLiquidityProvisionArgs(
        UniswapLiquidityProvisionArgs memory args
    ) internal view {
        _validateMerkleRootIsAllowed(args.merkleRoot);
        _validateNullifierIsNotUsed(args.noteData1.nullifier);
        _validateNullifierIsNotUsed(args.noteData2.nullifier);
        _validateNullifierIsNotLocked(args.noteData1.nullifier);
        _validateNullifierIsNotLocked(args.noteData2.nullifier);
        _validateNoteFooterIsNotUsed(args.positionNoteFooter);
        _validateNoteFooterIsNotUsed(args.changeNoteFooters[0]);
        _validateNoteFooterIsNotUsed(args.changeNoteFooters[1]);
        _validateRelayerIsRegistered(args.relayer);
        if(msg.sender != args.relayer) {
            revert RelayerMismatch();
        }

        if(args.changeNoteFooters[0] == args.changeNoteFooters[1] ||
            args.positionNoteFooter == args.changeNoteFooters[0] ||
            args.positionNoteFooter == args.changeNoteFooters[1]) {
            revert NoteFooterDuplicated();
        }
    }

    /**
     * @dev Validates the arguments for collecting fees from liquidity. Ensures that the merkle root is allowed,
     * fee note footers have not been used, and the relayer is registered.
     * @param args The arguments for the fee collection operation.
     */
    function _validateCollectFeesArgs(
        UniswapCollectFeesArgs memory args
    ) internal view {
        _validateMerkleRootIsAllowed(args.merkleRoot);
        _validateNoteFooterIsNotUsed(args.feeNoteFooters[0]);
        _validateNoteFooterIsNotUsed(args.feeNoteFooters[1]);
        _validateRelayerIsRegistered(args.relayer);
        if(msg.sender != args.relayer) {
            revert RelayerMismatch();
        }

        if(args.feeNoteFooters[0] == args.feeNoteFooters[1]) {
            revert NoteFooterDuplicated();
        }
    }

    /**
     * @dev Validates the arguments for removing liquidity. Ensures that the merkle root is allowed,
     * the position note nullifier has not been used, out note footers have not been used,
     * and the relayer is registered.
     * @param args The arguments for the liquidity removal operation.
     */
    function _validateRemoveLiquidityArgs(
        UniswapRemoveLiquidityArgs memory args
    ) internal view {
        _validateMerkleRootIsAllowed(args.merkleRoot);
        _validateNullifierIsNotUsed(args.positionNote.nullifier);
        _validateNullifierIsNotLocked(args.positionNote.nullifier);
        _validateNoteFooterIsNotUsed(args.outNoteFooters[0]);
        _validateNoteFooterIsNotUsed(args.outNoteFooters[1]);
        _validateRelayerIsRegistered(args.relayer);
        if(msg.sender != args.relayer) {
            revert RelayerMismatch();
        }

        if (args.outNoteFooters[0] == args.outNoteFooters[1]) {
            revert NoteFooterDuplicated();
        }
    }

    /**
     * * UTILS (PROOF VERIFIERS)
     */

    /**
     * @dev Verifies the proof for liquidity provision operation. This function is intended to integrate with
     * a zero-knowledge proof system to validate the operation's integrity and authorization.
     * @param args The arguments for the liquidity provision operation, used to construct the proof's inputs.
     * @param proof The cryptographic proof associated with the liquidity provision operation.
     */
    function _verifyProofForLiquidityProvision(
        UniswapLiquidityProvisionArgs memory args,
        bytes calldata proof
    ) internal view {
        UniswapLiquidityProvisionInputs memory inputs;

        inputs.merkleRoot = args.merkleRoot;
        inputs.asset1Address = args.noteData1.assetAddress;
        inputs.asset2Address = args.noteData2.assetAddress;
        inputs.amount1 = args.noteData1.amount;
        inputs.amount2 = args.noteData2.amount;
        inputs.nullifier1 = args.noteData1.nullifier;
        inputs.nullifier2 = args.noteData2.nullifier;
        inputs.noteFooter = args.positionNoteFooter;
        inputs.tickMin = args.tickMin;
        inputs.tickMax = args.tickMax;
        inputs.changeNoteFooter1 = args.changeNoteFooters[0];
        inputs.changeNoteFooter2 = args.changeNoteFooters[1];
        inputs.relayer = args.relayer;
        inputs.amount1Min = args.amountsMin[0];
        inputs.amount2Min = args.amountsMin[1];
        inputs.poolFee = args.poolFee;
        inputs.deadline = args.deadline;

        _verifyProof(
            proof,
            _buildUniswapLiquidityProvisionInputs(inputs),
            "uniswapLiquidityProvision"
        );
    }

    /**
     * @dev Verifies the proof for fee collection from liquidity. This function is intended to integrate with
     * a zero-knowledge proof system to validate the operation's integrity and authorization.
     * @param args The arguments for the fee collection operation, used to construct the proof's inputs.
     * @param proof The cryptographic proof associated with the fee collection operation.
     */
    function _verifyProofForCollectFees(
        UniswapCollectFeesArgs memory args,
        bytes calldata proof
    ) internal view {
        UniswapCollectFeesInputs memory inputs;

        inputs.merkleRoot = args.merkleRoot;
        inputs.positionAddress = address(nonfungiblePositionManager);
        inputs.tokenId = args.tokenId;
        inputs.fee1NoteFooter = args.feeNoteFooters[0];
        inputs.fee2NoteFooter = args.feeNoteFooters[1];
        inputs.relayer = args.relayer;

        _verifyProof(
            proof,
            _buildUniswapCollectFeesInputs(inputs),
            "uniswapCollectFees"
        );
    }

    /**
     * @dev Verifies the proof for liquidity removal operation. This function is intended to integrate with
     * a zero-knowledge proof system to validate the operation's integrity and authorization.
     * @param args The arguments for the liquidity removal operation, used to construct the proof's inputs.
     * @param proof The cryptographic proof associated with the liquidity removal operation.
     */
    function _verifyProofForRemoveLiquidity(
        UniswapRemoveLiquidityArgs memory args,
        bytes calldata proof
    ) internal view {
        UniswapRemoveLiquidityInputs memory inputs;

        inputs.merkleRoot = args.merkleRoot;
        inputs.positionAddress = address(nonfungiblePositionManager);
        inputs.positionNullifier = args.positionNote.nullifier;
        inputs.tokenId = args.positionNote.amount;
        inputs.out1NoteFooter = args.outNoteFooters[0];
        inputs.out2NoteFooter = args.outNoteFooters[1];
        inputs.deadline = args.deadline;
        inputs.relayer = args.relayer;
        inputs.amount1Min = args.amountsMin[0];
        inputs.amount2Min = args.amountsMin[1];

        _verifyProof(
            proof,
            _buildUniswapRemoveLiquidityInputs(inputs),
            "uniswapRemoveLiquidity"
        );
    }

    /**
     * * UTILS (LP)
     */

    /**
     * @dev Executes the minting of a Uniswap LP token as part of the liquidity provision process. 
     *      This involves interacting with the Uniswap contract, handling asset transfers, and creating necessary notes.
     * @param args Arguments for the liquidity provision, including details about the assets and pool parameters.
     * @param mintParams Parameters prepared for minting the LP token, derived from the provided arguments.
     * @param originalIndices The original indices of the tokens used in the liquidity provision.
     * @return changeNoteCommitments Commitments for any change notes created as a result of the minting process.
     * @return changeAmounts Amounts of assets not used in the minting and returned as change.
     * @return positionNote The note representing the newly created LP token position.
     * @return tokenId The ID of the minted LP token.
     */
    function _executeLPMint(
        UniswapLiquidityProvisionArgs memory args,
        INonfungiblePositionManager.MintParams memory mintParams,
        uint8[2] memory originalIndices
    )
        internal
        returns (
            bytes32[2] memory changeNoteCommitments,
            uint256[2] memory changeAmounts,
            bytes32 positionNote,
            uint256 tokenId
        )
    {
        uint256 mintedAmount0;
        uint256 mintedAmount1;

        _registerNoteFooter(args.positionNoteFooter);
        _registerNoteFooter(args.changeNoteFooters[0]);
        _registerNoteFooter(args.changeNoteFooters[1]);

        (tokenId, , mintedAmount0, mintedAmount1) = nonfungiblePositionManager
            .mint(mintParams);

        (changeNoteCommitments, changeAmounts) = _handleChangeAfterUniswapLp(
            mintParams,
            [mintedAmount0, mintedAmount1],
            args.changeNoteFooters,
            originalIndices
        );

        uniswapLPData[tokenId] = UniswapLPData({
            token1: mintParams.token0,
            token2: mintParams.token1
        });

        positionNote = _buildNoteForERC721(
            address(nonfungiblePositionManager),
            tokenId,
            args.positionNoteFooter
        );

        _transferERC721PositionToVault(tokenId);

        _postDeposit(positionNote);

        if (changeAmounts[0] > 0) {
            _postDeposit(changeNoteCommitments[0]);
        }

        if (changeAmounts[1] > 0) {
            _postDeposit(bytes32(changeNoteCommitments[1]));
        }
    }

    /**
     * * UTILS (CHANGE)
     */

    /**
     * @dev Handles any change returned after the Uniswap LP minting process. 
     *      This involves creating notes for the change amounts and transferring assets back to the vault if necessary.
     * @param mintParams The minting parameters including the desired amounts of assets for the liquidity provision.
     * @param actuallyMintedAmounts The actual amounts of assets used in the minting process.
     * @param noteFooters Footers for the notes representing the change amounts.
     * @param originalIndices The original indices of the tokens used in the liquidity provision.
     * @return changeNoteCommitments Commitments for the change notes created for any unutilized asset amounts.
     * @return changeAmounts The amounts of each asset not used in the minting and returned as change.
     */
    function _handleChangeAfterUniswapLp(
        INonfungiblePositionManager.MintParams memory mintParams,
        uint256[2] memory actuallyMintedAmounts,
        bytes32[2] memory noteFooters,
        uint8[2] memory originalIndices
    )
        internal
        returns (
            bytes32[2] memory changeNoteCommitments,
            uint256[2] memory changeAmounts
        )
    {
        changeAmounts = [
            mintParams.amount0Desired - actuallyMintedAmounts[0],
            mintParams.amount1Desired - actuallyMintedAmounts[1]
        ];

        //_registerNoteFooter(noteFooters[0]);
        //_registerNoteFooter(noteFooters[1]);

        address normalizedToken0 = _convertToEthIfNecessary(mintParams.token0, changeAmounts[0]);
        address normalizedToken1 = _convertToEthIfNecessary(mintParams.token1, changeAmounts[1]);

        _transferAssetToVault(normalizedToken0, changeAmounts[0]);
        _transferAssetToVault(normalizedToken1, changeAmounts[1]);

        if (changeAmounts[0] > 0) {
            changeNoteCommitments[0] = _buildNoteForERC20(
                normalizedToken0,
                changeAmounts[0],
                noteFooters[originalIndices[0]]
            );
        }

        if (changeAmounts[1] > 0) {
            changeNoteCommitments[1] = _buildNoteForERC20(
                normalizedToken1,
                changeAmounts[1],
                noteFooters[originalIndices[1]]
            );
        }
    }

    /**
     * * UTILS (ARGS PREPARERS)
     */

    /**
     * @dev Prepares the arguments for the liquidity provision operation,
     *      including releasing funds and setting up the mint parameters.
     * @param args The liquidity provision arguments, detailing the operation's specifics.
     * @return mintParams The parameters required for minting the LP token.
     * @return originalIndices The original indices of the tokens used in the liquidity provision.
     */
    function _releaseFundsAndPrepareLiquidityProvisionArgs(
        UniswapLiquidityProvisionArgs memory args
    )
        internal
        returns (
            INonfungiblePositionManager.MintParams memory mintParams,
            //FeesDetails memory feesDetails,
            uint8[2] memory originalIndices
        )
    {
        _postWithdraw(bytes32(args.noteData1.nullifier));
        _postWithdraw(bytes32(args.noteData2.nullifier));

        /**
         * * Release funds for token 1
         */

        FundReleaseDetails memory fundReleaseDetails1;

        fundReleaseDetails1.assetAddress = args.noteData1.assetAddress;
        fundReleaseDetails1.recipient = payable(address(this));
        fundReleaseDetails1.relayer = args.relayer;
        fundReleaseDetails1.relayerGasFee = args.relayerGasFees[0];
        fundReleaseDetails1.amount = args.noteData1.amount;
        

        (
            uint256 actualReleasedAmountToken1,
            //FeesDetails memory feesDetails1
        ) = _releaseAndPackDetails(fundReleaseDetails1);

        /**
         * * Release funds for token 2
         */

        FundReleaseDetails memory fundReleaseDetails2;

        fundReleaseDetails2.assetAddress = args.noteData2.assetAddress;
        fundReleaseDetails2.recipient = payable(address(this));
        fundReleaseDetails2.relayer = args.relayer;
        fundReleaseDetails2.relayerGasFee = args.relayerGasFees[1];
        fundReleaseDetails2.amount = args.noteData2.amount;


        (
            uint256 actualReleasedAmountToken2,
            //FeesDetails memory feesDetails2
        ) = _releaseAndPackDetails(fundReleaseDetails2);

        /**
         * * Post release setup
         */

        //feesDetails.serviceFee =
        //    feesDetails1.serviceFee +
        //    feesDetails2.serviceFee;

        //feesDetails.relayerRefund =
        //    args.relayerGasFees[0] +
        //    args.relayerGasFees[1];

        address[2] memory tokens;
        uint256[2] memory amounts;

        (
            tokens,
            amounts,
            originalIndices
        ) = _sortAndConvertToWeth(
                [args.noteData1.assetAddress, args.noteData2.assetAddress],
                [actualReleasedAmountToken1, actualReleasedAmountToken2]
            );

        /**
         * * Prepare mint parameters
         */

        mintParams.token0 = tokens[0];
        mintParams.token1 = tokens[1];

        mintParams.fee = args.poolFee;
        mintParams.tickLower = args.tickMin;
        mintParams.tickUpper = args.tickMax;
        mintParams.amount0Desired = amounts[0];
        mintParams.amount1Desired = amounts[1];
        mintParams.amount0Min = args.amountsMin[originalIndices[0]];
        mintParams.amount1Min = args.amountsMin[originalIndices[1]];
        mintParams.recipient = payable(address(this));
        mintParams.deadline = args.deadline;

        IERC20(mintParams.token0).forceApprove(
            address(nonfungiblePositionManager),
            mintParams.amount0Desired
        );
        IERC20(mintParams.token1).forceApprove(
            address(nonfungiblePositionManager),
            mintParams.amount1Desired
        );
    }

    /**
     * @dev Prepares the parameters required for collecting fees from the non-fungible position manager.
     * @param tokenId The ID of the LP token from which fees are to be collected.
     * @return collectParams The parameters required for the collect operation.
     */
    function _prepareCollectFeeParams(
        uint256 tokenId
    )
        internal
        view
        returns (INonfungiblePositionManager.CollectParams memory collectParams)
    {
        collectParams.tokenId = tokenId;
        collectParams.recipient = address(this);
        collectParams.amount0Max = type(uint128).max;
        collectParams.amount1Max = type(uint128).max;
    }

    /**
     * @dev Prepares the parameters required for removing liquidity via the non-fungible position manager.
     * @param args The arguments detailing the liquidity removal operation.
     * @param liquidity The liquidity amount to remove.
     * @return decreaseLiquidityParams The parameters required for the decrease liquidity operation.
     */
    function _prepareRemoveLiquidityParams(
        UniswapRemoveLiquidityArgs memory args,
        uint128 liquidity
    )
        internal
        view
        returns (
            INonfungiblePositionManager.DecreaseLiquidityParams
                memory decreaseLiquidityParams
        )
    {
        decreaseLiquidityParams.tokenId = args.positionNote.amount;
        decreaseLiquidityParams.liquidity = liquidity;
        decreaseLiquidityParams.amount0Min = args.amountsMin[0];
        decreaseLiquidityParams.amount1Min = args.amountsMin[1];
        decreaseLiquidityParams.deadline = args.deadline;
    }

    /**
     * * UTILS (RELEASE ERC721 POSITION RELATED)
     */

    /**
     * @dev Releases an ERC721 token (LP token) from the asset pool to this contract.
     * @param tokenId The ID of the LP token to release.
     */
    function _releaseERC721Position(uint256 tokenId) internal {
        _assetPoolERC721.release(
            address(nonfungiblePositionManager),
            address(this),
            tokenId
        );
    }

    /**
     * * UTILS (TRANSFER ERC721 POSITION RELATED)
     */

    /**
     * @dev Transfers an ERC721 token (LP token) from this contract to the asset vault.
     * @param tokenId The ID of the LP token to transfer.
     */
    function _transferERC721PositionToVault(uint256 tokenId) internal {
        IERC721(address(nonfungiblePositionManager)).safeTransferFrom(
            address(this),
            address(_assetPoolERC721),
            tokenId
        );
    }

    /**
 * @dev Burns position token after it is used.
     * @param tokenId The ID of the LP token to burn.
     */
    function _burnERC721Position(uint256 tokenId) internal {
        nonfungiblePositionManager.burn(tokenId);
    }

    /**
     * @dev Callback function to receive ERC721 tokens.
     * This function is called when the LP token is transferred to this contract.
     */
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
