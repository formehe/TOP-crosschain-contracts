// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

struct Signature{
    bytes32 r;
    bytes32 s;
    uint8 v;
}

struct CrossDaoTx{
    address     from;
    uint8       governorType;
    uint256     fromChainID;
    uint256     toChainID;
    uint256     termID;
    uint256     nonce;
    address     target;
    bytes       action;
    bytes32     descriptionHash;
    bytes[]     signs;
}

struct CrossDaoGovernance{
    address     from;
    uint8       governorType;
    uint256     fromChainID;
    uint256     toChainID; // uint256(-1) means apply governance to all chain
    uint256     newTermID;
    address[]   voters;
    bytes32     descriptionHash;
    bytes[]     signs;
}

struct CrossDaoAmendment{
    address from;
    uint8   governorType;
    uint256 fromChainID;
    uint256 toChainID;
    uint256 termID;
    uint256 nonce;
    bytes32 descriptionHash;
    bytes[] signs;
}

struct CrossDaoBridge{
    address from;
    uint8   governorType;
    bytes   proposalInfo;
    bytes[] signs;
}

enum ProposalType {
    Governor,
    Common,
    Amendment
}

enum ProposalState {
    Pending,
    Active,
    Canceled,
    Defeated,
    Succeeded,
    Queued,
    Expired,
    Executed
}

enum VoteType {
    Against,
    For,
    Abstain
}

library CrossDaoCommon {
    event CrossDaoTxEvent(
        uint8   governorType,
        uint256 fromChainID,
        uint256 toChainID,
        uint256 termID,
        uint256 nonce,
        address target,
        bytes   action,
        bytes32 descriptionHash
    );

    event CrossDaoGovernanceEvent(
        uint8   governorType,
        address from,
        uint256 fromChainID,
        uint256 toChainID,
        uint256 newTermID,
        address[] voters,
        bytes32 descriptionHash
    );

    event CrossDaoAmendmentEvent(
        uint8   governorType,
        address from,
        uint256 fromChainID,
        uint256 toChainID,
        uint256 termID,
        uint256 nonce,
        bytes32 descriptionHash
    );

    event CrossDaoProposalCreated(
        uint256 proposalId,
        address proposer,
        uint256 fromChainID,
        uint256 toChainID
    );

    event CrossDaoVoteCast(
        address indexed voter,
        uint256 proposalId,
        uint8 support,
        uint256 weight
    );

    event CrossDaoBridgeEvent(
        address from,
        uint8   governorType,
        bytes   proposalInfo,
        bytes[] signs
    );

    bytes32 constant public CrossDaoBridgeEventID = 0x2fe0d86de96779121839da89b9a502c4e2acca9804079f713cc0585d0e028051;

    function decodeCrossDaoAmendment(bytes memory data) internal pure returns (CrossDaoAmendment memory dao) {
        (dao.governorType, dao.fromChainID, dao.toChainID, dao.termID, dao.nonce, dao.descriptionHash)
            = abi.decode(data,(uint8,uint256,uint256,uint256,uint256,bytes32));
    }

    function decodeCrossDaoTx(bytes memory data) internal pure returns (CrossDaoTx memory dao) {
        (dao.governorType, dao.fromChainID, dao.toChainID, dao.termID, dao.nonce, dao.target, dao.action, dao.descriptionHash)
            = abi.decode(data,(uint8,uint256,uint256,uint256,uint256,address,bytes,bytes32));
    }

    function decodeCrossDaoGovernance(bytes memory data) internal pure returns (CrossDaoGovernance memory dao) {
        (dao.governorType, dao.fromChainID, dao.toChainID, dao.newTermID, dao.voters, dao.descriptionHash) 
            = abi.decode(data,(uint8,uint256,uint256,uint256,address[],bytes32));
    }

    function decodeCrossDaoBridge(bytes memory data) internal pure returns (CrossDaoBridge memory dao) {
        (dao.from, dao.governorType, dao.proposalInfo, dao.signs) 
            = abi.decode(data,(address,uint8,bytes,bytes[]));
    } 
}