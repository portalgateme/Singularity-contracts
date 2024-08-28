// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {BaseAssetPool} from "../base/BaseAssetPool.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";


contract ERC721AssetPool is BaseAssetPool, IERC721Receiver, ReentrancyGuard {
    constructor(address initialOwner) BaseAssetPool(initialOwner) {}

    function release(
        address nft,
        address to,
        uint256 tokenId
    ) external onlyAssetManager transferNotLocked nonReentrant{
        require(
            IERC721(nft).ownerOf(tokenId) == address(this),
            "ERC721AssetPool: NFT does not belong to asset pool"
        );

        IERC721(nft).safeTransferFrom(address(this), to, tokenId);
    }

    /*function approve(
        address nft,
        uint256 tokenId,
        address to
    ) external onlyAssetManager transferNotLocked {
        require(
            IERC721(nft).ownerOf(tokenId) == address(this),
            "ERC721AssetPool: NFT does not belong to asset pool"
        );

        IERC721(nft).approve(to, tokenId);
    }*/

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
