// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {IKeyringCredentials} from "./interfaces/IKeyringCredentials.sol";
//import {IPolicyManager} from "./interfaces/IPolicyManager.sol";
//import {IWalletCheck} from "./interfaces/IWalletCheck.sol";
import {IComplianceManager} from "../interfaces/IComplianceManager.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title KeyringManager
 * @dev Contract to manage keyring compliance check of darkpool transactions.
 */

contract KeyringManager is Ownable, IComplianceManager {
    address public immutable keyringCredentials;
    //address public immutable policyManager;
    uint32 public admissionPolicyId; // 3 for the mainnet, 4 for the Sepolia
    bool private _keyringEnabled;


    /**
     * @dev Constructor sets everythign up.
     * @param tmpKeyringCredentials Address of keyringCredentials contract.
     * @param tmpAdmissionPolicyId Darkpool admission policy id.
     */
    constructor(
        address initialOwner,
        address tmpKeyringCredentials,
        //address tmpPolicyManager,
        uint32 tmpAdmissionPolicyId
    ) Ownable(initialOwner) {
        keyringCredentials = tmpKeyringCredentials;
        //policyManager = tmpPolicyManager;
        admissionPolicyId = tmpAdmissionPolicyId;
        _keyringEnabled = true;
    }

    function isAuthorized(
        address observer,
        address subject
    ) external returns (bool) {
        if (!_keyringEnabled) return true;
        
        //if (!_checkTraderWallet(observer, subject)) return false;
        if (!_checkZKPIICache(observer, subject)) return false;

        return true;
    }

    function setPolicyId(uint32 policyId) external onlyOwner {
        admissionPolicyId = policyId;
    }

    function setKeyringAvaliability(bool enabled) external onlyOwner {
        _keyringEnabled = enabled;
    }

    function getPolicyId() external view returns (uint32) {
        return admissionPolicyId;
    }

    /**
     * @notice Checks keyringCache for cached PII credential.
     * @param observer The user who must consent to reliance on degraded services.
     * @param subject The subject to inspect.
     * @return passed True if cached credential is new enough, or if degraded service mitigation is possible
     * and the user has provided consent.
     */
    function _checkZKPIICache(
        address observer,
        address subject
    ) internal view returns (bool) {
        bool passed = IKeyringCredentials(keyringCredentials).checkCredential(
            admissionPolicyId,
            subject
        );
        return passed;
    }

}
