// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {IQuadPassportStore} from "@quadrata/contracts/interfaces/IQuadPassportStore.sol";
import {QuadReaderUtils} from "@quadrata/contracts/utility/QuadReaderUtils.sol";

contract MockQuadReader {
    using QuadReaderUtils for bytes32;

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
    }

    function getAttributesBulk(address _account, bytes32[] calldata _attributes)
        external returns(IQuadPassportStore.Attribute[] memory attributes) {
        
        IQuadPassportStore.Attribute[] memory values = new IQuadPassportStore.Attribute[](2);
        values[0] = IQuadPassportStore.Attribute({
            value: bytes32("US"),
            epoch: uint256(0),
            issuer: address(0) 
        });

        uint256 amlValue = uint256(0);
        if (verifiedAddresses[_account]) {
            amlValue = uint256(6);
        }

        values[1] = IQuadPassportStore.Attribute({
            value: bytes32(amlValue),
            epoch: uint256(0),
            issuer: address(0) 
        });

    }
}

