// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title VerifierHub
 * @dev Contract to manage ZK verifiers.
 */
contract VerifierHub is Ownable {
    mapping(bytes32 nameHash => address verifier) private _verifiers;
    string[] private _verifierNames;

    event VerifierSet(string verifierName, address addr);

    constructor(address _initialOwner) Ownable(_initialOwner) {}

    function setVerifier(
        string memory verifierName,
        address addr
    ) external onlyOwner {
        _setVerifier(verifierName, addr);
        emit VerifierSet(verifierName, addr);
    }

    /**
     * @notice Register multiple verifiers.
     * @param verifierNames Array of verifier names.
     * @param addrs Array of verifier addresses.
     */
    function setVerifierBatch(
        string[] memory verifierNames,
        address[] memory addrs
    ) external onlyOwner {
        require(
            verifierNames.length == addrs.length,
            "VerifierHub: arrays are not equal length"
        );
        for (uint16 i = 0; i < verifierNames.length; i++) {
            _setVerifier(verifierNames[i], addrs[i]);
        }
    }

    function getVerifierNames() external view returns (string[] memory) {
        return _verifierNames;
    }

    function getVerifier(
        string memory verifierName
    ) external view returns (address) {
        return _verifiers[keccak256(bytes(verifierName))];
    }

    function _setVerifier(string memory verifierName, address addr) internal {
        if (!_exists(verifierName)) {
            _verifierNames.push(verifierName);
        }
        _verifiers[keccak256(bytes(verifierName))] = addr;
    }

    function _exists(string memory verifierName) internal view returns (bool) {
        for (uint16 i = 0; i < _verifierNames.length; i++) {
            string memory _verifierName = _verifierNames[i];
            if (_equal(_verifierName, verifierName)) {
                return true;
            }
        }

        return false;
    }

    function _equal(
        string memory a,
        string memory b
    ) internal pure returns (bool) {
        return
            bytes(a).length == bytes(b).length &&
            keccak256(bytes(a)) == keccak256(bytes(b));
    }
}
