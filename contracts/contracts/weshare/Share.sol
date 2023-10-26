// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

contract Share is ERC20, Initializable{
    constructor() ERC20("Room's shares", "Room's shares") {
    }

    function initialize(address owner_, uint256 shares_) initializer external {
        require(owner_ != address(0), "Invalid owner");
        _mint(owner_, shares_);
    }
}