// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

// Internal imports
import {BaseAssetManager} from "../../core/base/BaseAssetManager.sol";
import {UniswapInputBuilder} from "./UniswapInputBuilder.sol";
import {IWETH9} from "../../core/interfaces/IWETH9.sol";

// External imports
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title UniswapCoreAssetManager
 * @dev Core contract for Uniswap asset managers.
 */
contract UniswapCoreAssetManager is BaseAssetManager, UniswapInputBuilder {
    /**
     * * LIBRARIES
     */

    using SafeERC20 for IERC20;

    /**
     * * STRUCTS
     */

    struct UniswapNoteData {
        address assetAddress;
        uint256 amount;
        bytes32 nullifier;
    }

    struct FeesDetails {
        uint256 serviceFee;
        uint256 relayerRefund;
    }

    struct AutoSplitArgs {
        // asset address of the note that will be split
        address asset;
        // amount of the note that will be split
        uint256 actualAmount;
        // desired amount of the note that will be split
        uint256 desiredAmount;
        // nullifier of the note that will be split
        bytes32 nullifier;
        // note footer of the out note created after split
        bytes32 noteFooter;
        // note footer of the change note created after split
        bytes32 changeNoteFooter;
    }

    struct AutoSplitDetails {
        // out note commitment after split
        bytes32 note;
        // change note commitment after split
        bytes32 changeNote;
        // change amount after split
        uint256 changeAmount;
    }

    struct TransferFundsToVaultWithFeesAndCreateNoteData {
        // amount of the note that will be transferred to the vault
        uint256 actualAmount;
        // asset of the note that will be transferred to the vault (normailized means WETH IS ETH)
        address normalizedAsset;
        // note footer of the note that will be transferred to the vault
        bytes32 noteCommitment;
        // fees details of the transfer
        FeesDetails feesDetails;
    }

    /**
     * * STATE VARIABLES
     */

    address public WETH_ADDRESS;

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
        address wethAddress
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
            mimcBn254,
            initialOwner
        )
        UniswapInputBuilder(P)
    {
        WETH_ADDRESS = wethAddress;
    }

    /**
     * * UTILS (WETH RELATED)
     */

    /**
     * @dev Converts ETH to WETH if the specified asset is ETH. This is essential for handling ETH in contracts
     * that require ERC20 compatibility. If the asset is already an ERC20 token, no conversion occurs.
     * @param assetAddress The address of the asset to potentially convert to WETH.
     * @param amount The amount of the asset to convert.
     * @return The address of WETH if conversion occurred, or the original asset address otherwise.
     */
    function _convertToWethIfNecessary(
        address assetAddress,
        uint256 amount
    ) internal returns (address) {
        if (assetAddress == ETH_ADDRESS || assetAddress == address(0)) {
            if (amount > 0) {
                IWETH9(WETH_ADDRESS).deposit{value: amount}();
            }

            return WETH_ADDRESS;
        }

        return assetAddress;
    }

    /**
     * @dev Converts WETH to ETH if the specified asset is WETH. Facilitates operations requiring native ETH
     * by unwrapping WETH. If the asset is not WETH, no action is taken.
     * @param assetAddress The address of the asset to potentially convert to ETH.
     * @param amount The amount of the asset to convert.
     * @return The address of ETH (represented as 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE) if conversion occurred,
     *         or the original asset address otherwise.
     */
    function _convertToEthIfNecessary(
        address assetAddress,
        uint256 amount
    ) internal returns (address) {
        if (assetAddress == WETH_ADDRESS) {
            IWETH9(WETH_ADDRESS).withdraw(amount);
            return ETH_ADDRESS;
        }

        return assetAddress;
    }

    /**
     * * UTILS (NOTE RELATED)
     */

    /**
     * @dev Generates a unique note commitment from asset details and a note footer. This identifier can be used
     * for tracking and managing assets within the contract.
     * @param asset The address of the asset related to the note.
     * @param amount The amount of the asset.
     * @param noteFooter A unique identifier to ensure the uniqueness of the note.
     * @return A bytes32 representing the generated note commitment.
     */
    /*function _generateNoteCommitment(
        address asset,
        uint256 amount,
        bytes32 noteFooter
    ) internal view returns (bytes32) {
        return _buildNoteForERC20(asset, amount, noteFooter);
    }*/

    /**
     * * UTILS (TRANSFER RELATED)
     */

    /**
     * @dev Safely transfers ETH to a specified address. Ensures that the transfer is successful
     * and reverts the transaction if it fails.
     * @param to The recipient address.
     * @param amount The amount of ETH to transfer.
     */
    function _transferETH(address to, uint256 amount) internal {
        if (amount > 0) {
            (bool success, ) = to.call{value: amount}("");
            require(success, "transferETH: transfer failed");
        }
    }

    /**
     * @dev Transfers ERC20 tokens to a specified address using the SafeERC20 library. Provides safety checks
     * and reverts the transaction if the transfer fails.
     * @param token The ERC20 token address.
     * @param to The recipient address.
     * @param amount The amount of tokens to transfer.
     */
    function _transferERC20(
        address token,
        address to,
        uint256 amount
    ) internal {
        if (amount > 0) {
            //IERC20(token).forceApprove(to, amount);
            IERC20(token).safeTransfer(to, amount);
        }
    }

    /**
     * @dev General utility function to transfer an asset (ETH or ERC20 token) to a specified address.
     * Automates the distinction between ETH and ERC20 transfers.
     * @param asset The asset address.
     * @param to The recipient address.
     * @param amount The amount of the asset to transfer.
     */
    function _transferAsset(
        address asset,
        address to,
        uint256 amount
    ) internal {
        if (asset == ETH_ADDRESS || asset == address(0)) {
            _transferETH(to, amount);
        } else {
            _transferERC20(asset, to, amount);
        }
    }

    /**
     * @dev Transfers an asset (ETH or ERC20) to the contract's vault for asset management.
     * Utilizes internal methods to handle the specificities of ETH vs. ERC20 transfers.
     * @param assetAddress The address of the asset to transfer.
     * @param amount The amount of the asset to transfer.
     */
    function _transferAssetToVault(
        address assetAddress,
        uint256 amount
    ) internal {
        address transferTo = (assetAddress == ETH_ADDRESS ||
            assetAddress == address(0))
            ? address(_assetPoolETH)
            : address(_assetPoolERC20);

        _transferAsset(assetAddress, transferTo, amount);
    }

    /**
     * @dev Transfers funds to the vault, deducts necessary fees, and creates a note commitment.
     * This function is used after an operation (like swapping or liquidity provision) to move the resulted asset
     * into the vault. It handles fee deduction, transfers the net amount to the vault, and creates a new note
     * representing the deposited asset.
     * @param asset The address of the asset to be transferred to the vault.
     * @param amount The gross amount of the asset before fees are deducted.
     * @param noteFooter The unique identifier used to generate the note commitment.
     * @param relayerGasFee The gas fee to be compensated to the relayer.
     * @param relayer The address of the relayer to receive the gas fee refund.
     * @return data A struct containing details of the transfer, including the normalized asset
     *         address (converted to ETH if necessary), the actual amount transferred to the vault after fees,
     *         the note commitment, and details of the fees deducted.
     */
    function _transferFundsToVaultWithFeesAndCreateNote(
        address asset,
        uint256 amount,
        bytes32 noteFooter,
        uint256 relayerGasFee,
        address payable relayer
    )
        internal
        returns (TransferFundsToVaultWithFeesAndCreateNoteData memory data)
    {
        data.normalizedAsset = _convertToEthIfNecessary(asset, amount);

        (
            data.actualAmount,
            data.feesDetails.serviceFee,
            data.feesDetails.relayerRefund
        ) = _feeManager.calculateFee(amount, relayerGasFee);

        _chargeFees(data.normalizedAsset, relayer, data.feesDetails);
        
        if (data.actualAmount > 0 ){
            _transferAssetToVault(data.normalizedAsset, data.actualAmount);

            data.noteCommitment = _buildNoteForERC20(
            data.normalizedAsset,
            data.actualAmount,
            noteFooter
            );
            _postDeposit(bytes32(data.noteCommitment));
        }
    }

    /**
     * * UTILS (RELEASE RELATED)
     */

    /**
     * @dev Releases an asset from the vault to a specified address without charging any fees.
     * Can handle both ETH and ERC20 assets.
     * @param asset The asset to release.
     * @param to The recipient address.
     * @param amount The amount of the asset to release.
     */
    function _releaseAssetFromVaultWithoutFee(
        address asset,
        address to,
        uint256 amount
    ) internal {
        if (amount > 0) {
            if (asset == ETH_ADDRESS || asset == address(0)) {
                _assetPoolETH.release(payable(to), amount);
            } else {
                _assetPoolERC20.release(asset, to, amount);
            }
        }
    }

    /**
     * @dev Releases funds based on the details provided in the fundReleaseDetails struct.
     * Calculates fees and refunds associated with the release process.
     * @param fundReleaseDetails A struct containing details about the fund release.
     * @return releasedAmount The amount of funds released.
     * @return feesDetails A struct containing details about the fees and refunds.
     */
    function _releaseAndPackDetails(
        FundReleaseDetails memory fundReleaseDetails
    )
        internal
        returns (uint256 releasedAmount, FeesDetails memory feesDetails)
    {
        (
            releasedAmount,
            feesDetails.serviceFee,
            feesDetails.relayerRefund
        ) = _releaseFunds(fundReleaseDetails);
    }

    /**
     * * UTILS (FEE RELATED)
     */

    /**
     * @dev Charges fees for a transaction and transfers them to the relayer and the fee manager.
     * The function ensures that the appropriate parties receive their respective fees for the operation.
     * @param asset The asset from which fees are to be charged.
     * @param relayer The address of the relayer to receive the relayer refund.
     * @param feesDetails The details of the fees to be charged, including service fees and relayer refunds.
     */
    function _chargeFees(
        address asset,
        address payable relayer,
        FeesDetails memory feesDetails
    ) internal {
        _transferAsset(asset, relayer, feesDetails.relayerRefund);
        _transferAsset(asset, address(_feeManager), feesDetails.serviceFee);
    }

    /**
     * @dev Charges fees from the vault for a transaction, transferring them to the relayer and the fee manager.
     * This function is used when fees need to be paid from assets stored within the vault.
     * @param asset The asset from which fees are to be charged.
     * @param relayer The address of the relayer to receive the relayer refund.
     * @param feesDetails The details of the fees to be charged, including service fees and relayer refunds.
     */
    function _chargeFeesFromVault(
        address asset,
        address payable relayer,
        FeesDetails memory feesDetails
    ) internal {
        _releaseAssetFromVaultWithoutFee(
            asset,
            relayer,
            feesDetails.relayerRefund
        );
        _releaseAssetFromVaultWithoutFee(
            asset,
            address(_feeManager),
            feesDetails.serviceFee
        );
    }

    /**
     * * UTILS (AUTO SPLIT RELATED)
     */

    /**
     * @dev Splits a note into two parts: a desired amount and the remaining change. This is used
     * for operations where the exact note amount is not needed and the remainder needs to be handled.
     * @param args The arguments for the split operation, including the asset, amounts, and note footers.
     * @return autoSplitDetails The details of the split operation,
     *         including the new note commitments and change amount.
     */
    function _autosplit(
        AutoSplitArgs memory args
    ) internal returns (AutoSplitDetails memory autoSplitDetails) {
        require(
            args.actualAmount >= args.desiredAmount,
            "autosplit: actual amount is less than desired amount"
        );

        autoSplitDetails.changeAmount = args.actualAmount - args.desiredAmount;

        autoSplitDetails.note = _buildNoteForERC20(
            args.asset,
            args.desiredAmount,
            args.noteFooter
        );
        autoSplitDetails.changeNote = _buildNoteForERC20(
            args.asset,
            autoSplitDetails.changeAmount,
            args.changeNoteFooter
        );

        _postWithdraw(args.nullifier);
        _postDeposit(bytes32(autoSplitDetails.note));
        _postDeposit(bytes32(autoSplitDetails.changeNote));
    }

    /**
     * * UTILS (TOKENS SORT RELATED)
     */

    /**
     * @dev Sorts two tokens based on their addresses and ensures the amounts are aligned with the sorted order.
     * This is useful for operations that require a consistent ordering of token addresses.
     * @param tokens An array of two token addresses to be sorted.
     * @param amounts An array of two amounts corresponding to the tokens array.
     * @return sortedTokens The sorted array of token addresses.
     * @return sortedAmounts The array of amounts aligned with the sorted order of tokens.
     * @return originalIndices The array of original indices.
     */
    function _sortTokens(
        address[2] memory tokens,
        uint256[2] memory amounts
    ) internal pure returns (address[2] memory, uint256[2] memory, uint8[2] memory) {
        if (uint256(uint160(tokens[0])) < uint256(uint160(tokens[1]))) {
            return (tokens, amounts, [0, 1]);
        }

        return ([tokens[1], tokens[0]], [amounts[1], amounts[0]], [1, 0]);
    }

    /**
     * @dev Sorts two tokens based on their addresses, converts them to WETH if necessary,
     * and ensures the amounts are aligned with the sorted order. This function combines token sorting
     * with the conversion operation for contracts that require WETH.
     * @param tokens An array of two token addresses to be sorted and potentially converted to WETH.
     * @param amounts An array of two amounts corresponding to the tokens array.
     * @return sortedTokens The sorted array of token addresses, converted to WETH if necessary.
     * @return sortedAmounts The array of amounts aligned with the sorted and possibly converted order of tokens.
     * @return originalIndices The array of original indices.
     */
    function _sortAndConvertToWeth(
        address[2] memory tokens,
        uint256[2] memory amounts
    )
        internal
        returns (
            address[2] memory sortedTokens,
            uint256[2] memory sortedAmounts,
            uint8[2] memory originalIndices
        )
    {
        address[2] memory wethedTokens = [
            _convertToWethIfNecessary(tokens[0], amounts[0]),
            _convertToWethIfNecessary(tokens[1], amounts[1])
        ];

        (sortedTokens, sortedAmounts, originalIndices) = _sortTokens(wethedTokens, amounts);
    }
}
