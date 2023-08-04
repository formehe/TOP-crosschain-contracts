// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Reward is ERC20 {
    constructor(string memory name_, string memory symbol_, uint256 totalSupply_, address supplier_) ERC20(name_,symbol_) {
        require(supplier_.code.length > 0, "not contract address");
        _mint(supplier_, totalSupply_);
    }
}