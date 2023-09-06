// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./CrossDaoCommon.sol";

abstract contract ICrossGovernance{
    using CrossDaoCommon for bytes;
    using ECDSA for bytes32;

    event ProposalExecuted(
        uint256 proposalID,
        bytes   proposalInfo
    );

    function _decodeLog(bytes memory log) internal pure returns(address contractAddress, bytes32[] memory topics, bytes memory action) {
        (contractAddress, topics, action) = abi.decode(log, (address,bytes32[],bytes));
    }

    function _verify(bytes32 hash, bytes[] memory signs) internal view returns(bool) {
        for (uint256 i = 0; i < signs.length; i++) {
            (address _signer, ) = hash.tryRecover(signs[i]);
            require(_signer != address(0), "invalid signer");
            require(isVoterExist(_signer), "invalid voter");
        }
        return true;
    }

    function _checkCrossDaoHeader(uint256 fromChainID, uint256 toChainID, address fromAddress) internal virtual;
    
    function _changeNonce(uint256 newNonce, uint256 currentTerm) internal virtual;
    
    function _changeTerm(uint256 newTerm) internal virtual;

    function _changeVoters(address[] memory voters, uint256 newTerm) internal virtual;
    
    function isVoterExist(address voter) public view virtual returns (bool);

    function execute(bytes calldata log) public {
        (address contractAddress, bytes32[] memory topics, bytes memory action) = _decodeLog(log);
        require(topics.length == 1, "invalid num of topics");
        require(topics[0] == CrossDaoCommon.CrossDaoBridgeEventID, "invalid topic");
        
        CrossDaoBridge memory bridge = action.decodeCrossDaoBridge();
        require(bridge.from == contractAddress, "invalid from contract");
        uint256 proposalID = uint256(keccak256(bridge.proposalInfo));
        require(proposalID == bridge.proposalID, "invalid proposal");

        bytes32 signed = keccak256(abi.encode(bridge.from, proposalID, VoteType.For));
        require(_verify(signed, bridge.signs), "invalid signature");

        if (bridge.governorType == uint8(ProposalType.Governor)) {
            CrossDaoGovernance memory dao = bridge.proposalInfo.decodeCrossDaoGovernance();
            
            require(dao.governorType == bridge.governorType, "invalid governor type");
            _checkCrossDaoHeader(dao.fromChainID, dao.toChainID, bridge.from);
            _changeTerm(dao.newTermID);
            
            _changeVoters(dao.voters, dao.newTermID);
        } else if (bridge.governorType == uint8(ProposalType.Common)) {
            CrossDaoTx memory dao = bridge.proposalInfo.decodeCrossDaoTx();
            require(dao.governorType == bridge.governorType, "invalid governor type");
            _checkCrossDaoHeader(dao.fromChainID, dao.toChainID, bridge.from);
            _changeNonce(dao.nonce, dao.termID);

            string memory errorMessage = "call reverted without message";
            (bool success, bytes memory returnData) = address(dao.target).call(dao.action);
            Address.verifyCallResult(success, returnData, errorMessage);

        } else if (bridge.governorType == uint8(ProposalType.Amendment)) {
            CrossDaoAmendment memory dao = bridge.proposalInfo.decodeCrossDaoAmendment();
            require(dao.governorType == bridge.governorType, "invalid governor type");
            _checkCrossDaoHeader(dao.fromChainID, dao.toChainID, bridge.from);
            _changeNonce(dao.nonce, dao.termID);
        } else {
            revert("invalid governor type");
        }

        emit ProposalExecuted(proposalID, bridge.proposalInfo);
    }
}