// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title RelayerHub
 * @dev Contract to manage relayers in a darkpool.
 */
contract RelayerHub is Ownable {
    mapping(address relayer => bool registered) private _isRelayer;

    event RelayerAdded(address indexed relayer);
    event RelayerRemoved(address indexed relayer);

    /**
     * @dev Constructor to set the initial owner of the contract.
     * @param initialOwner Address of the initial owner.
     */
    constructor(address initialOwner) Ownable(initialOwner) {}

    /**
     * @dev Public function to check if an address is a registered relayer.
     * @param _relayer Address of the relayer to check.
     * @return bool Returns true if the address is a registered relayer, false otherwise.
     */
    function isRelayerRegistered(
        address _relayer
    ) external view returns (bool) {
        return _isRelayer[_relayer];
    }

    /**
     * @dev Public function to add a new relayer. Only callable by the owner.
     * @param _relayer Address of the relayer to add.
     * Emits a {RelayerAdded} event.
     */
    function add(address _relayer) public onlyOwner {
        require(
            !_isRelayer[_relayer],
            "RelayerHub: The relayer already exists"
        );
        _isRelayer[_relayer] = true;
        emit RelayerAdded(_relayer);
    }

    /**
     * @dev Public function to remove an existing relayer. Only callable by the owner.
     * @param _relayer Address of the relayer to remove.
     * Emits a {RelayerRemoved} event.
     */
    function remove(address _relayer) public onlyOwner {
        require(_isRelayer[_relayer], "RelayerHub: The relayer does not exist");
        _isRelayer[_relayer] = false;
        emit RelayerRemoved(_relayer);
    }
}
