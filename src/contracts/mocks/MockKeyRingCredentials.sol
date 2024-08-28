// SPDX-License-Identifier: MIT

// pragma solidity 0.8.14;
pragma solidity ^0.8.20;

contract MockKeyringCredentials {

    mapping(bytes32 => uint256) public subjectUpdates;
    
    address private constant NULL_ADDRESS = address(0);
    uint8 private constant VERSION = 1;
    bytes32 public constant ROLE_CREDENTIAL_UPDATER =
        keccak256("Credentials updater");

    mapping(address => bool) public verifiedAddresses;
    address private constant ALICE_ADDRESS =
        0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address private constant BOB_ADDRESS =
        0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    address private constant CHARLIE_ADDRESS =
        0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;

    constructor() {
        verifiedAddresses[ALICE_ADDRESS] = true;
        verifiedAddresses[BOB_ADDRESS] = true;
        verifiedAddresses[CHARLIE_ADDRESS] = true;
        subjectUpdates[keyGen(ALICE_ADDRESS, 3)] = uint256(1893456000);
        subjectUpdates[keyGen(BOB_ADDRESS, 3)] = uint256(1893456000);
        subjectUpdates[keyGen(CHARLIE_ADDRESS, 3)] = uint256(1893456000);
    }

    function verifyAddress(address _addressToVerify) public {
        verifiedAddresses[_addressToVerify] = true;
    }

    function unverifyAddress(address _addressToUnVerify) public {
        verifiedAddresses[_addressToUnVerify] = false;
    }

    function isVerified(address _address) public view returns (bool) {
        return verifiedAddresses[_address];
    }

    /**
     * @notice Inspect the credential cache.
     * @param observer The observer for degradation mitigation consent.
     * @param trader The user address for the Credential update.
     * @param admissionPolicyId The admission policy for the credential to inspect.
     * @return passed True if a valid cached credential exists or if mitigation measures are applicable.
     */
    function checkCredential(
        address observer,
        address trader,
        uint32 admissionPolicyId
    )
        external
        view
        returns (
            // ) public view returns (bool passed) {
            bool passed
        )
    {
        if (isVerified(trader)) {
            return true;
        } else {
            return false;
        }
    }

    /**
     * @notice Generate a cache key for a trader and policyId.
     * @param trader The trader for the credential cache.
     * @param admissionPolicyId The policyId.
     * @return key The credential cache key. 
     */
    function keyGen(
        address trader,
        uint32 admissionPolicyId
    ) public pure returns (bytes32 key) {
        key = keccak256(abi.encodePacked(
            VERSION,
            trader,
            admissionPolicyId
        ));
    }
}
