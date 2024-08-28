// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import { ISablierV2LockupDynamic } from "@sablier/v2-core/src/interfaces/ISablierV2LockupDynamic.sol";
import { ISablierV2LockupLinear } from "@sablier/v2-core/src/interfaces/ISablierV2LockupLinear.sol";
import { ISablierV2Batch } from "@sablier/v2-periphery/src/interfaces/ISablierV2Batch.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

abstract contract SablierAssetManagerHelper is Ownable {

    struct ClaimStreamArgs {
        bytes32 merkleRoot;
        bytes32 nullifierIn;
        address stream;
        uint256 streamId;
        address assetOut;
        uint128 amountOut;
        bytes32 noteFooter;
        address relayer;
        uint256 gasRefund;
    }

    ISablierV2LockupLinear internal _lockupLinear;
    ISablierV2LockupDynamic internal _lockupDynamic;
    ISablierV2Batch internal _batch;

    event SablierCreateStream(
        address sender,
        address nft,
        uint256[] streamIDs,
        bytes32[] notesOut,
        bytes32[] noteFooters
    );

    event SablierClaimStream(
        bytes32 nullifier,
        address asset,
        uint256 amountOut,
        bytes32 noteOut,
        bytes32 noteFooter
    );

    error StreamSizeError();
    error AmountNotCorrect();
    error ParametersHashMismatch();
    error StreamTypeNotSupported();
    error AssetNotCorrect();
    error StreamNotCorrect();

    function setLockupLinear(address llinear) external onlyOwner {
        _lockupLinear = ISablierV2LockupLinear(llinear);
    }
    
    function setLockupDynamic(address ldynamic) external onlyOwner {
        _lockupDynamic = ISablierV2LockupDynamic(ldynamic);
    }
    
    function setBatch(address batch) external onlyOwner {
        _batch = ISablierV2Batch(batch);
    }
    
    function _getLockupLinear() internal view returns (ISablierV2LockupLinear) {
        return _lockupLinear;
    }
    
    function _getLockupDynamic() internal view returns (ISablierV2LockupDynamic) {
        return _lockupDynamic;
    }

    function _getBatch() internal view returns (ISablierV2Batch) {
        return _batch;
    }

    function _validateStreamSize(uint256 streamSize, uint256 paramSize, uint256 noteFooterNum) internal pure {
        if (streamSize != paramSize || 
            streamSize != noteFooterNum || 
            noteFooterNum != paramSize ||
            streamSize > 5 || 
            streamSize == 0) 
        {
            revert StreamSizeError();
        }
    }
}