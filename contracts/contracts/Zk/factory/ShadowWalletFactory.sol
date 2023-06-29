// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "./IShadowFactory.sol";
import "../interfaces/ICircuitValidator.sol";
import "../wallet/IShadowWallet.sol";

contract ShadowWalletFactory is IShadowFactory, Initializable{
    address public template;
    ICircuitValidator public validator;
    function initialize(address _template, ICircuitValidator _validator) external initializer{
        require(Address.isContract(_template), "invalid template");
        require(Address.isContract(address(_validator)), "invalid validator");
        template = _template;
        validator = _validator;
    }

    function clone(
        address _walletProxy,
        uint256 id,
        uint256[] calldata inputs,
        uint256[2] calldata a,
        uint256[2][2] calldata b,
        uint256[2] calldata c,
        bytes calldata action
    ) external override returns (address _shadowWallet) {
        _shadowWallet = Clones.clone(template);
        IShadowWallet(_shadowWallet).initialize(_walletProxy, address(this), id, inputs, a, b, c, action);
    }

    function getValidator() external override view returns (address) {
        return address(validator);
    }
}