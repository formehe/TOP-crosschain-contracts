// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";
import "./lib/GenesisUtils.sol";
import "./interfaces/ICircuitValidator.sol";
import "./verifiers/ZKPVerifier.sol";
import "./wallet/IShadowWallet.sol";
import "hardhat/console.sol";

contract ZkEntry is ZKPVerifier{
    event Wallet_Created(
        uint256 id,
        address wallet
    );

    event Proof_Used(
        uint256 id
    );
    
    mapping(uint256 => address)  public idMappings;
    mapping(uint256 => bool)    public usedProofs;

    IShadowFactory public factory;
    address public state;

    constructor(IShadowFactory _factory, address _state) {
        require(Address.isContract(address(_factory)), "invalid factory");
        require(Address.isContract(_state), "invalid state");
        _initialize(_factory);
        state = _state;
    }

    function _initialize(
        IShadowFactory _factory
    ) internal override {
        factory = _factory;
    }

    function transitState(
        uint256 id,
        uint256 oldState,
        uint256 newState,
        bool isOldStateGenesis,
        uint256[2] calldata a,
        uint256[2][2] calldata b,
        uint256[2] calldata c
    ) external {
        bytes memory payload = abi.encodeWithSignature("transitState(uint256,uint256,uint256,bool,uint256[2],uint256[2][2],uint256[2])", 
            id, oldState, newState, isOldStateGenesis, a, b, c);
        (bool success,) = state.call(payload);
        require(success, "fail totransitstate");
        address wallet = idMappings[id];
        if (wallet == address(0)) {
            wallet = factory.clone();
            idMappings[id] = wallet;
            IShadowWallet(wallet).initialize(address(this));
            emit Wallet_Created(id, address(wallet));
        }
    }

    function _beforeProofSubmit(
        uint64, /* requestId */
        uint256[] calldata inputs,
        ICircuitValidator validator
    ) internal view override {
        uint256 id = inputs[validator.getChallengeInputIndex()];
        require(!usedProofs[id], "proof has been used");
    }

    function _afterProofSubmit(
        uint64 /*requestId*/,
        uint256[] calldata inputs,
        ICircuitValidator validator,
        address proxied,
        bytes calldata method
    ) internal override {
        uint256 id = inputs[validator.getChallengeInputIndex()];
        uint256 userId = inputs[validator.getUserIdInputIndex()];
        address wallet = idMappings[userId];
        if (wallet == address(0)) {
            wallet = factory.clone();
            idMappings[userId] = wallet;
            IShadowWallet(wallet).initialize(address(this));
            emit Wallet_Created(userId, address(wallet));
        } else {
            IShadowWallet(wallet).forwardCall(proxied, method);
            usedProofs[id] = true;
            emit Proof_Used(id);
        }
    }
}