// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "./IShadowWallet.sol";

contract ShadowWallet is IShadowWallet, Initializable {
    address public caller;

    function initialize(address _caller) external override initializer{
        require(Address.isContract(_caller), "invalid caller");
        caller = _caller;
    }

    function forwardCall(address objectContract, bytes memory method) external override returns (bytes memory) {
        require(msg.sender == caller, "can not call");
        return Address.functionCall(objectContract, method);
    }
}