// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./interfaces/IValidator.sol";
import "./wallet/IShadowWallet.sol";
import "./factory/IShadowFactory.sol";

contract ZkEntry is Initializable{
    event Shadow_Wallet_Created(
        uint256 id,
        address wallet
    );

    event MaterialChanged(
        uint256 id,
        address wallet
    );

    mapping(uint256 => address)  public idMappings;
    IShadowFactory public factory;

    function initialize(
        IShadowFactory _factory
    ) external initializer {
        require(Address.isContract(address(_factory)), "invalid factory");
        factory = _factory;
    }

    function newWallet(
        uint256        id,
        uint256        proofKind,
        bytes calldata proof,
        bytes calldata action
    ) external returns (address) {
        require(idMappings[id] == address(0), "id already exist");
        address wallet = factory.clone(address(this), id, proofKind, proof, action);
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
    ) external {
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
    ) external {
        address wallet = idMappings[id];
        require(wallet != address(0), "id not exist");
        IShadowWallet(wallet).revoke(id, proofKind, proof, revokedProofKind, action, msg.sender);
    }

    function execute(
        uint256        id,        
        uint256        proofKind,
        bytes calldata proof,
        bytes calldata action
    ) external {
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
    ) external {
        address wallet = idMappings[id];
        require(wallet != address(0), "id not exist");
        IShadowWallet(wallet).changeMaterial(id, proofKind, oldProof, proof, action, msg.sender);
        emit MaterialChanged(id, wallet);
    }
}