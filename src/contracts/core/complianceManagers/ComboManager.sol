// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {IComplianceManager} from "../interfaces/IComplianceManager.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";


contract ComboManager is  Ownable, IComplianceManager {
    address[] public managers;

    constructor(
        address initialOwner,
        address[] memory managerAddresses
    ) Ownable(initialOwner) {
        managers = managerAddresses;
    }

    function isAuthorized(
        address observer,
        address subject
    ) external  returns (bool) {
        for (uint256 i = 0; i < managers.length; i++) {
            try IComplianceManager(managers[i]).isAuthorized(observer, subject) 
                returns (bool authorized) {
                if (authorized) {
                    return true;
                }
            } catch {
                continue;
            }
        }
        return false;
    }

    function addManager(address manager) external onlyOwner {
        managers.push(manager);
    }

    function removeManager(address manager) external onlyOwner {
        for (uint256 i = 0; i < managers.length; i++) {
            if (managers[i] == manager) {
                managers[i] = managers[managers.length - 1];
                managers.pop();
                return;
            }
        }
    }
}