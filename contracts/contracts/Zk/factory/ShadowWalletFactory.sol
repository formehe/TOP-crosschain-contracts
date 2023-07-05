// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./IShadowFactory.sol";
import "../interfaces/IValidator.sol";
import "../wallet/IShadowWallet.sol";

contract ShadowWalletFactory is IShadowFactory, AccessControl, Initializable{
    address public template;
    mapping(uint256 => IValidator)  public validators;
    uint256 public rootProofKind = 0x2daa737e13c50c4bbce0e98ee727347a0b510c39a5766854fc1e579342d095aa;
    //keccak256("OWNER.ROLE");
    bytes32 constant OWNER_ROLE = 0x0eddb5b75855602b7383774e54b0f5908801044896417c7278d8b72cd62555b6;
    //keccak256("ADMIN.ROLE");
    bytes32 constant ADMIN_ROLE = 0xa8a2e59f1084c6f79901039dbbd994963a70b36ee6aff99b7e17b2ef4f0e395c;

    event ValidatorBound(
        uint256 id,
        address validator
    );

    function initialize(address _template, IValidator _validator, address _owner) external initializer{
        require(Address.isContract(_template), "invalid template");
        require(Address.isContract(address(_validator)), "invalid validator");
        require(_owner != address(0), "invalid owner");
        uint256 proofKind = uint256(_validator.getID());

        require(address(validators[proofKind]) == address(0), "validator is exist");
        require(proofKind == rootProofKind, "only root proof kind can be used during initailizing");
        template = _template;
        validators[proofKind] = _validator;
        _setRoleAdmin(ADMIN_ROLE, OWNER_ROLE);

        _grantRole(OWNER_ROLE,_owner);
        _grantRole(ADMIN_ROLE,msg.sender);
    }

    function bindValidator(IValidator _validator) external onlyRole(ADMIN_ROLE) {
        //require(address(validators[uint256(_validator.getID())]) == address(0), "validator is exist");
        validators[uint256(_validator.getID())] = _validator;
        emit ValidatorBound(uint256(_validator.getID()), address(_validator));
    }

    function clone(
        address        _walletProxy,
        uint256        id,
        uint256        proofKind,
        bytes calldata proof,
        bytes calldata action
    ) external override returns (address _shadowWallet) {
        _shadowWallet = Clones.clone(template);
        require(proofKind == rootProofKind, "only root proof kind can be used during clone wallet");
        IShadowWallet(_shadowWallet).initialize(_walletProxy, address(this), id, proofKind, proof, action);
    }

    function getValidator(uint256 proofKind) external view override returns (address) {
        require(address(validators[proofKind]) != address(0), "validator is not exist");
        return address(validators[proofKind]);
    }

    function renounceRole(bytes32 /*role*/, address /*account*/) public pure override {
        require(false, "not support");
    }
}