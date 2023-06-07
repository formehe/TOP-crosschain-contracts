// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";
import "./lib/GenesisUtils.sol";
import "./interfaces/ICircuitValidator.sol";
import "./verifiers/ZKPVerifier.sol";
import "./wallet/IShadowWallet.sol";
import "hardhat/console.sol";

contract ZkEntry is ZKPVerifier{
    uint64 public constant TRANSFER_REQUEST_ID = 1;
    
    mapping(uint256 => address)  public idMappings;
    mapping(uint256 => bool)    public usedProofs;

    IShadowFactory public factory;

    constructor(IShadowFactory _factory) {
        _initialize(_factory);
    }

    function _initialize(
        IShadowFactory _factory
    ) internal override {
        factory = _factory;
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
            console.logAddress(wallet);
        } else {
            IShadowWallet(wallet).forwardCall(proxied, method);
            usedProofs[id] = true;
        }
    }
}