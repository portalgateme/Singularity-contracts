// SPDX-License-Identifier: MIT

pragma solidity >=0.8.20;

interface IGeneralDefiIntegration {
    /**
     * @dev This function is used to call the defi integration contract to get the assets and amounts
     * @param amountsOrNftIds The amounts/nft ids for passed in assets
     * @param defiParameters The parameters for the defi integration
     * @return assets The assets sent back
     * @return outAmounts Out amounts/nft ids for the assets sent back
     */
    function defiCall(uint256[] calldata amountsOrNftIds, string calldata defiParameters) 
        external payable returns (address[] memory assets, uint256[] memory outAmounts);
    
    /**
     * @dev This function is used to get what assets are used in the defi integration contract
     * @return assets The assets contains in the defi pool
     */
    function getAssets(string calldata defiParameters) external returns (address[] memory assets);

    /**
     * @dev This function is used to get the expected out amounts for a defi call
     * @param amountsOrNftIds The amounts/nft ID for passed in assets
     * @param defiParameters The parameters for the defi integration
     * @return outAmounts The amounts, could be 0 for placeholder
     */
    function getExpectedOutAmounts(uint256[] calldata amountsOrNftIds, string calldata defiParameters) 
        external returns (uint256[] memory outAmounts);
}