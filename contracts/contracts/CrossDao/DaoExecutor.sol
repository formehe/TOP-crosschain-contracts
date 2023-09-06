// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "./ICrossGovernance.sol";

contract DaoExecutor is ICrossGovernance, Initializable{
    using ECDSA for bytes32;

    mapping(uint256 => mapping(address => bool)) private terms;
    uint256 private peerChainID;
    address private peerDao;
    uint256 private term;
    uint256 private nonce;
    
    function initialize(address[] calldata _voters, uint256 _peerChainID, address _peerDao) external initializer {
        _changeTerm(1);
        _addVoters(_voters, 1);

        require(_peerDao != address(0), "invalid dao address");
        peerDao = _peerDao;
        peerChainID = _peerChainID;
    }

    function _checkCrossDaoHeader(uint256 fromChainID, uint256 toChainID, address fromAddress) internal override{
        require(fromChainID == peerChainID, "invalid from chain id");
        require(toChainID == block.chainid, "invalid to chain id");
        require(fromAddress == peerDao, "invalid peer dao");
    }

    function _changeNonce(uint256 newNonce, uint256 currentTerm) internal override {
        require(currentTerm == term, "invalid term");
        require(newNonce - nonce == 1, "invalid nonce");
        nonce = newNonce;
    }

    function _changeTerm(uint256 newTerm) internal override{
        require(newTerm - term == 1, "invalid new term");
        term = newTerm;
    }

    function _addVoters(address[] memory _voters, uint256 newTerm) internal override{
        mapping(address => bool) storage termVoters = terms[newTerm];
        for (uint256 i = 0; i < _voters.length; i++) {
            require(_voters[i] != address(0), "invalid voter");
            termVoters[_voters[i]] = true;
        }
    }

    function isVoterExist(address voter) public view override returns (bool) {
        return terms[term][voter];
    }
}