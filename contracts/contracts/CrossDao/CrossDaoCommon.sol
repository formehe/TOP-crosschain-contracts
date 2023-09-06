// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

struct Signature{
    bytes32 r;
    bytes32 s;
    uint8 v;
}

struct CrossDaoTx{
    uint8       governorType;
    uint256     fromChainID;
    uint256     toChainID;
    uint256     termID;
    uint256     nonce;
    address     target;
    bytes       action;
    bytes32     descriptionHash;
}

struct CrossDaoGovernance{
    uint8       governorType;
    uint256     fromChainID;
    uint256     toChainID; // uint256(-1) means apply governance to all chain
    uint256     newTermID;
    address[]   voters;
    bytes32     descriptionHash;
}

struct CrossDaoAmendment{
    uint8   governorType;
    uint256 fromChainID;
    uint256 toChainID;
    uint256 termID;
    uint256 nonce;
    bytes32 descriptionHash;
}

struct CrossDaoBridge{
    address from;
    uint256 proposalID;
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
    event CrossDaoProposalCreated(
        uint256 proposalId,
        address proposer,
        uint8   governorType,
        bytes   action
    );

    event CrossDaoVoteCast(
        address indexed voter,
        uint256 proposalId,
        uint8 support,
        uint256 weight
    );

    event CrossDaoBridgeEvent(
        address from,
        uint256 proposalID,
        uint8   governorType,
        bytes   proposalInfo,
        bytes[] signs
    );

    bytes32 constant public CrossDaoBridgeEventID = 0x5a7d7afefe941f9424d2ec716afee6eada95b6e28820a13ecbcb183d226d6cac;

    function decodeCrossDaoAmendment(bytes memory data) internal pure returns (CrossDaoAmendment memory dao) {
        (dao.governorType, dao.fromChainID, dao.toChainID, dao.termID, dao.nonce, dao.descriptionHash)
            = abi.decode(data,(uint8,uint256,uint256,uint256,uint256,bytes32));
    }

    function encodeCrossDaoAmendment(
        uint8   governorType,
        uint256 fromChainID,
        uint256 toChainID,
        uint256 termID,
        uint256 nonce,
        bytes32 descriptionHash
    ) internal pure returns (bytes memory dao) {
        return abi.encode(governorType, fromChainID, toChainID, termID, nonce, descriptionHash);
    }

    function decodeCrossDaoTx(bytes memory data) internal pure returns (CrossDaoTx memory dao) {
        (dao.governorType, dao.fromChainID, dao.toChainID, dao.termID, dao.nonce, dao.target, dao.action, dao.descriptionHash)
            = abi.decode(data,(uint8,uint256,uint256,uint256,uint256,address,bytes,bytes32));
    }

    function encodeCrossDaoTx(
        uint8   governorType,
        uint256 fromChainID,
        uint256 toChainID,
        uint256 termID,
        uint256 nonce,
        address remoteTarget,
        bytes memory action,
        bytes32 descriptionHash
    ) internal pure returns (bytes memory dao) {
        return abi.encode(governorType, fromChainID, toChainID, termID, nonce, remoteTarget, action, descriptionHash);
    }

    function decodeCrossDaoGovernance(bytes memory data) internal pure returns (CrossDaoGovernance memory dao) {
        (dao.governorType, dao.fromChainID, dao.toChainID, dao.newTermID, dao.voters, dao.descriptionHash) 
            = abi.decode(data,(uint8,uint256,uint256,uint256,address[],bytes32));
    }

    function encodeCrossDaoGovernance(
        uint8   governorType,
        uint256 fromChainID,
        uint256 toChainID,
        uint256 termID,
        address[] memory voters,
        bytes32 descriptionHash
    ) internal pure returns (bytes memory dao) {
        return abi.encode(governorType, fromChainID, toChainID, termID, voters, descriptionHash);
    }

    function decodeCrossDaoBridge(bytes memory data) internal pure returns (CrossDaoBridge memory dao) {
        (dao.from, dao.proposalID, dao.governorType, dao.proposalInfo, dao.signs) 
            = abi.decode(data,(address,uint256,uint8,bytes,bytes[]));
    }
}