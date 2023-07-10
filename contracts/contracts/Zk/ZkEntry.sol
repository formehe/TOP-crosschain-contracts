// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "../common/AdminControlledUpgradeable.sol";
import "./interfaces/IValidator.sol";
import "./wallet/IShadowWallet.sol";
import "./factory/IShadowFactory.sol";

contract ZkEntry is AdminControlledUpgradeable{
    event Shadow_Wallet_Created(
        uint256 id,
        address wallet
    );

    event MaterialChanged(
        uint256 id,
        address wallet
    );

    uint256 constant UNPAUSED_ALL = 0;
    uint256 constant PAUSED_GRANT = 1 << 0;
    uint256 constant PAUSED_REVOKE = 1 << 1;
    uint256 constant PAUSED_CHANGE_MATERIAL = 1 << 2;
    uint256 constant PAUSED_EXECUTE = 1 << 3;
    uint256 constant PAUSED_NEW = 1 << 4;

    mapping(uint256 => address)  public idMappings;
    IShadowFactory public factory;

    function initialize(
        IShadowFactory _factory,
        address _owner
    ) external initializer {
        require(Address.isContract(address(_factory)), "invalid factory");
        require(_owner != address(0), "invalid owner");
        factory = _factory;

        AdminControlledUpgradeable._AdminControlledUpgradeable_init(msg.sender, UNPAUSED_ALL ^ 0xff);
        _setRoleAdmin(ADMIN_ROLE, OWNER_ROLE);

        _setRoleAdmin(CONTROLLED_ROLE, ADMIN_ROLE);
        _setRoleAdmin(BLACK_ROLE, ADMIN_ROLE);

        _grantRole(OWNER_ROLE,_owner);
        _grantRole(ADMIN_ROLE,msg.sender);
    }

    function newWallet(
        uint256        id,
        uint256        proofKind,
        bytes calldata proof,
        bytes calldata action
    ) external accessable_and_unpauseable(BLACK_ROLE, PAUSED_NEW) returns (address) {
        require(idMappings[id] == address(0), "id already exist");
        address wallet = factory.clone(address(this), id, proofKind, proof, action, msg.sender);
        idMappings[id] = wallet;
        emit Shadow_Wallet_Created(id, wallet);
        return wallet;
    }

    function grant(
        uint256        id,
        uint256        proofKind,
        bytes calldata proof,
        uint256        grantedProofKind,
        bytes calldata grantedProof,
        bytes calldata action
    ) external accessable_and_unpauseable(BLACK_ROLE, PAUSED_GRANT){
        address wallet = idMappings[id];
        require(wallet != address(0), "id not exist");
        IShadowWallet(wallet).grant(id, proofKind, proof, grantedProofKind, grantedProof, action, msg.sender);
    }

    function revoke(
        uint256        id,
        uint256        proofKind,
        bytes calldata proof,
        uint256        revokedProofKind,
        bytes calldata action
    ) external accessable_and_unpauseable(BLACK_ROLE, PAUSED_REVOKE){
        address wallet = idMappings[id];
        require(wallet != address(0), "id not exist");
        IShadowWallet(wallet).revoke(id, proofKind, proof, revokedProofKind, action, msg.sender);
    }

    function execute(
        uint256        id,        
        uint256        proofKind,
        bytes calldata proof,
        bytes calldata action
    ) external accessable_and_unpauseable(BLACK_ROLE, PAUSED_EXECUTE){
        address wallet = idMappings[id];
        require(wallet != address(0), "id not exist");
        IShadowWallet(wallet).execute(id, proofKind, proof, action, msg.sender);
    }

    function changeMaterial(
        uint256        id,
        uint256        proofKind,
        bytes calldata oldProof,
        bytes calldata proof,
        bytes calldata action
    ) external accessable_and_unpauseable(BLACK_ROLE, PAUSED_CHANGE_MATERIAL){
        address wallet = idMappings[id];
        require(wallet != address(0), "id not exist");
        IShadowWallet(wallet).changeMaterial(id, proofKind, oldProof, proof, action, msg.sender);
        emit MaterialChanged(id, wallet);
    }
}