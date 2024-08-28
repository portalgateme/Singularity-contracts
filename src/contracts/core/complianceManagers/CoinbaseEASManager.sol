// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {ICoinbaseAttestationIndexer} from "./interfaces/ICoinbaseAttestationIndexer.sol";
import {IComplianceManager} from "../interfaces/IComplianceManager.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract CoinbaseEASManager is Ownable, IComplianceManager {

    address public immutable coinbaseAttestationIndexer;
    bytes32 public immutable verifiedAccountSchemaID;
    bool private _coinBaseEnabled;

    constructor(
        address initialOwner,
        address indexer,
        bytes32 schemaID
    ) Ownable(initialOwner) {
        coinbaseAttestationIndexer = indexer;
        verifiedAccountSchemaID = schemaID;
        _coinBaseEnabled = true;
    }
    
    function setCoinbaseAttestationAvaliability(bool enabled) external onlyOwner {
        _coinBaseEnabled = enabled;
    }

    function isAuthorized(
        address observer,
        address subject
    ) external view returns (bool) {
        if (!_coinBaseEnabled) return true;
        
        return ICoinbaseAttestationIndexer(coinbaseAttestationIndexer)
            .getAttestationUid(subject, verifiedAccountSchemaID) != bytes32(0) ? true : false;
            
    }
}
