// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

// Internal imports
import {UniswapCoreAssetManager} from "./UniswapCoreAssetManager.sol";

// External imports
import {TransferHelper} from "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title UniswapSwapAssetManager
 * @dev Contract for Uniswap swap asset manager.
 */
contract UniswapSwapAssetManager is UniswapCoreAssetManager {
    /**
     * * LIBRARIES
     */

    using SafeERC20 for IERC20;

    /**
     * * STRUCTS
     */

    struct UniswapSimpleSwapArgs {
        // data of the note that will be used for swap
        UniswapNoteData inNoteData;
        // merkle root of the merkle tree that the commitment of the note is included
        bytes32 merkleRoot;
        // address of the asset that will be received after swap
        address assetOut;
        // address of the relayer
        address payable relayer;
        // minimum amount of the asset that will be received after swap
        uint256 amountOutMin;
        // note footer of the note created after swap
        bytes32 noteFooter;
        // gas fee of the relayer
        uint256 relayerGasFee;
        // pool fee of the swap (Uniswap)
        uint24 poolFee;
    }

    /**
     * * STATE VARIABLES
     */

    ISwapRouter public immutable swapRouter;

    /**
     * * EVENTS
     */

    event UniswapSwap(
        address assetOut,
        uint256 amountOut,
        bytes32 noteNullifierIn,
        bytes32 noteFooter,
        bytes32 noteCommitmentOut
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
        ISwapRouter _swapRouter,
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
        swapRouter = _swapRouter;
    }

    /**
     * * HANDLERS
     */

    /**
     * @dev Performs a simple swap operation on Uniswap using ExactInputSingleParams,
     * converting an input asset to an output asset as specified in the UniswapSimpleSwapArgs.
     * Validates swap arguments, verifies the swap proof, prepares swap parameters, and executes the swap.
     * Transfers the swapped asset to the vault and generates a note commitment for the swapped asset.
     * Emits an UniswapSwap event upon successful swap.
     * @param args The UniswapSimpleSwapArgs struct containing swap parameters.
     * @param proof The cryptographic proof required for the swap operation.
     * @return amountOut The amount of the output asset received from the swap.
     * @return feesDetails The details of the fees incurred during the swap.
     */
    function uniswapSimpleSwap(
        UniswapSimpleSwapArgs memory args,
        bytes calldata proof
    ) public returns (uint256 amountOut, FeesDetails memory feesDetails) {
        _validateSimpleSwapArgs(args);
        _verifyProofForSwap(args, proof);

        ISwapRouter.ExactInputSingleParams memory swapParams;

        (swapParams, feesDetails) = _releaseFundsAndPrepareSwapArgs(args);
        _registerNoteFooter(args.noteFooter);

        amountOut = swapRouter.exactInputSingle(swapParams);
        address assetOut = _convertToEthIfNecessary(args.assetOut, amountOut);

        _transferAssetToVault(assetOut, amountOut);

        bytes32 noteCommitment = _buildNoteForERC20(
            assetOut,
            amountOut,
            args.noteFooter
        );

        _postDeposit(noteCommitment);

        emit UniswapSwap(
            assetOut,
            amountOut,
            args.inNoteData.nullifier,
            args.noteFooter,
            noteCommitment
        );
    }

    /**
     * * UTILS
     */

    /**
     * @dev Verifies the proof provided for a swap operation.
     * Constructs the inputs for the swap from the arguments and calls the proof verification function.
     * @param args The swap arguments containing details about the swap.
     * @param proof The cryptographic proof that validates the swap operation.
     */
    function _verifyProofForSwap(
        UniswapSimpleSwapArgs memory args,
        bytes calldata proof
    ) internal view {
        UniswapSimpleSwapInputs memory inputs;

        inputs.merkleRoot = args.merkleRoot;
        inputs.assetIn = args.inNoteData.assetAddress;
        inputs.amountIn = args.inNoteData.amount;
        inputs.nullifierIn = args.inNoteData.nullifier;
        inputs.assetOut = args.assetOut;
        inputs.noteFooter = args.noteFooter;
        inputs.poolFee = args.poolFee;
        inputs.amountOutMin = args.amountOutMin;
        inputs.relayer = args.relayer;

        _verifyProof(
            proof,
            _buildUniswapSimpleSwapInputs(inputs),
            "uniswapSwap"
        );
    }

    /**
     * @dev Validates the arguments provided for a simple swap operation.
     * Checks if the merkle root is allowed, the nullifier has not been used, the note footer is not used,
     * and if the relayer is registered.
     * Reverts with a descriptive error if any validation fails.
     * @param args The swap arguments to validate.
     */
    function _validateSimpleSwapArgs(
        UniswapSimpleSwapArgs memory args
    ) internal view {
        _validateMerkleRootIsAllowed(args.merkleRoot);
        _validateNullifierIsNotUsed(args.inNoteData.nullifier);
        _validateNullifierIsNotLocked(args.inNoteData.nullifier);
        _validateNoteFooterIsNotUsed(args.noteFooter);
        _validateRelayerIsRegistered(args.relayer);
        if(msg.sender != args.relayer) {
            revert RelayerMismatch();
        }
    }

    /**
     * @dev Prepares the swap parameters for the Uniswap router and releases funds for the swap.
     * Calculates the fees, releases the input asset from the vault, and sets up the swap parameters.
     * @param args The arguments specifying details about the swap.
     * @return swapParams The parameters prepared for the Uniswap swap operation.
     * @return feesDetails The details about the fees for the swap operation.
     */
    function _releaseFundsAndPrepareSwapArgs(
        UniswapSimpleSwapArgs memory args
    )
        internal
        returns (
            ISwapRouter.ExactInputSingleParams memory swapParams,
            FeesDetails memory feesDetails
        )
    {
        FundReleaseDetails memory fundReleaseDetails;

        fundReleaseDetails.assetAddress = args.inNoteData.assetAddress;
        fundReleaseDetails.recipient = payable(address(this));
        fundReleaseDetails.relayer = args.relayer;
        fundReleaseDetails.relayerGasFee = args.relayerGasFee;
        fundReleaseDetails.amount = args.inNoteData.amount;

        _postWithdraw(args.inNoteData.nullifier);

        uint256 actualReleasedAmount;

        (actualReleasedAmount, feesDetails) = _releaseAndPackDetails(
            fundReleaseDetails
        );

        swapParams.tokenIn = _convertToWethIfNecessary(
            args.inNoteData.assetAddress,
            actualReleasedAmount
        );

        swapParams.tokenOut = _convertToWethIfNecessary(args.assetOut, 0);

        swapParams.fee = args.poolFee;
        swapParams.recipient = address(this);
        swapParams.deadline = block.timestamp;
        swapParams.amountIn = actualReleasedAmount;
        swapParams.amountOutMinimum = args.amountOutMin;
        swapParams.sqrtPriceLimitX96 = 0;

        IERC20(swapParams.tokenIn).forceApprove(
            address(swapRouter),
            actualReleasedAmount
        );
    }
}
