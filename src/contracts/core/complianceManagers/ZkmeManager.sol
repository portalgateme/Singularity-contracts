// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {IZKMEVerifyUpgradeable} from "./interfaces/IZKMEVerifyUpgradeable.sol";
import {IComplianceManager} from "../interfaces/IComplianceManager.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract ZkmeManager is Ownable, IComplianceManager {

    address public immutable zkmeVerifyUpgradeable;
    address private _cooperator;
    bool private _zkmeEnabled;

    constructor(
        address initialOwner,
        address zkmeAddress,
        address zkmeCooperator
    ) Ownable(initialOwner) {
        zkmeVerifyUpgradeable = zkmeAddress;
        _cooperator = zkmeCooperator;
        _zkmeEnabled = true;
    }
    
    function setZkmeAvaliability(bool enabled) external onlyOwner {
        _zkmeEnabled = enabled;
    }

    function setCooperator(address cooperator) external onlyOwner {
        _cooperator = cooperator;
    }

    function isAuthorized(
        address observer,
        address subject
    ) external view returns (bool) {
        if (!_zkmeEnabled) return true;
        
        return IZKMEVerifyUpgradeable(zkmeVerifyUpgradeable)
            .hasApproved(_cooperator, subject);

    }
}
