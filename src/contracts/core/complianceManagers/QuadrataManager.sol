// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {IComplianceManager} from "../interfaces/IComplianceManager.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IQuadPassportStore} from "@quadrata/contracts/interfaces/IQuadPassportStore.sol";
import {QuadReaderUtils} from "@quadrata/contracts/utility/QuadReaderUtils.sol";
import {IQuadReader} from "@quadrata/contracts/interfaces/IQuadReader.sol";

contract QuadrataManager is Ownable, IComplianceManager {
    using QuadReaderUtils for bytes32;

    address public immutable quadReader;
    bool private _quadrataEnabled;

    constructor(
        address initialOwner,
        address readerAddress
    ) Ownable(initialOwner) {
        quadReader = readerAddress;
        _quadrataEnabled = true;
    }

    function setQuadrataAvaliability(bool enabled) external onlyOwner {
        _quadrataEnabled = enabled;
    }

    function isAuthorized(
        address observer,
        address subject
    ) external returns (bool) {
        if (!_quadrataEnabled) return true;

        bytes32[] memory attributesToQuery = new bytes32[](2);
        attributesToQuery[0] = keccak256("COUNTRY");
        attributesToQuery[1] = keccak256("AML");

        IQuadPassportStore.Attribute[] memory attributes = IQuadReader(
            quadReader
        ).getAttributesBulk(subject, attributesToQuery);

        if (attributes.length == attributesToQuery.length) {
            if (
                uint256(attributes[1].value) < uint256(5) &&
                uint256(attributes[1].value) > uint256(0)
            ) {
                return true;
            }
        }
        return false;
    }
}
