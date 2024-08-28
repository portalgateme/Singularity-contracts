// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MockWBTC is ERC20, Ownable {
    constructor()
        ERC20("Mock Wrapped Bitcoin", "MockWBTC")
        Ownable(msg.sender)
    {
        _mint(msg.sender, 100_000000000000000000); // 100 WBTC
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}
