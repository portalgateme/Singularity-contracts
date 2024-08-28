// SPDX-License-Identifier: MIT

pragma solidity >=0.8.20;


interface IMimc254 {
    enum NoteDomainSeparator {
        FUNGIBLE,
        NON_FUNGIBLE
    }

    function mimcBn254(uint256[] memory array) external view returns (uint256);

    /*function mimcBn254ForNote(
        uint256[3] memory array,
        NoteDomainSeparator domainSeparator
    ) external view returns (uint256);

    function mimcBn254ForTree(
        uint256[3] memory _array
    ) external view returns (uint256);

    function mimcBn254ForRoute(
        uint256[12] memory _array
    ) external view returns (uint256);*/
    
}
