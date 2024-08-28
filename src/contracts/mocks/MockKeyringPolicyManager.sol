// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

contract MockKeyringPolicyManager {
    address private _mockKeyringWalletCheck;

    struct PolicyScalar {
        bytes32 ruleId;
        string descriptionUtf8;
        uint32 ttl;
        uint32 gracePeriod;
        bool allowApprovedCounterparties;
        uint256 disablementPeriod;
        bool locked;
    }

    constructor(address mockKeyringWalletCheck) {
        _mockKeyringWalletCheck = mockKeyringWalletCheck;
    }

    function policyWalletChecks(
        uint32
    ) public view returns (address[] memory walletChecks) {
        address[] memory checks = new address[](1);
        checks[0] = _mockKeyringWalletCheck;
        return checks;
    }

    function policyCount() public pure returns (uint256 count) {
        count = 7;
    }

    function policy(uint32)
        public view
        returns (
            PolicyScalar memory config,
            address[] memory attestors,
            address[] memory walletChecks,
            bytes32[] memory backdoors,
            uint256 deadline
        )
    {
        config = PolicyScalar(
            0x1e0f1b859f5d1fa745c2c25964bd77044c6e9798a16dd56599a83d66768fe362,
            "KYC token",2592000,60,false,5184000,false
        );
        attestors = new address[](0);
        walletChecks = new address[](1);
        walletChecks[0] = _mockKeyringWalletCheck;
        backdoors = new bytes32[](0);

        return (config, attestors, walletChecks, backdoors, deadline);
    }

    function policyTtl(uint32) 
        public pure
        returns (uint32 ttl)
    {
        return uint32(2592000);
    }
}
