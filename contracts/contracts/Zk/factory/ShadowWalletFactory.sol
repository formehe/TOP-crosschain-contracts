// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "./IShadowFactory.sol";

contract ShadowWalletFactory is IShadowFactory{
    address public template;
    constructor(address _template) {
        require(Address.isContract(_template), "invalid template address");
        template = _template;
    }

    function clone() external override returns (address _shadowWallet) {
        _shadowWallet = Clones.clone(template);
    }
}