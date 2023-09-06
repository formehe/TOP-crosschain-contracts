// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/governance/utils/IVotes.sol";
import "@openzeppelin/contracts/utils/Timers.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./CrossDaoCommon.sol";

contract CrossMultiSignDao {
    using Counters       for Counters.Counter;
    using Timers         for Timers.Timestamp;
    using SafeCast       for uint256;
    using CrossDaoCommon for bytes;

    struct ProposalCore {
        Timers.Timestamp voteEnd;
        bool             executed;
        uint256          quorum;
        uint256          totalVotes;
    }

    struct Receipt {
        bool         hasVoted;
        uint8        support;
        uint96       votes;
    }

    struct ProposalDetails {
        uint8                       proposalType;
        address                     proposer;
        uint256                     toChainID;
        bytes                       proposal;
        uint256                     forVotes;
        uint256                     againstVotes;
        uint256                     abstainVotes;
        mapping(address => Receipt) receipts;
        Signature[]                 signatures;
    }

    // proposal detail
    mapping(uint256 => ProposalDetails) private _proposalDetails;
    // proposal vote info
    mapping(uint256 => ProposalCore)    private _proposals;
    // the smallest unused nonce of chain
    mapping(uint256 => Counters.Counter) private _nonces;
    // the term of voter
    Counters.Counter                     private currentTerm;
    IVotes                               private token;
    uint256                              private votingDelay;
    uint256                              private currentProposalId;

    modifier onlyGovernance() {
        require(msg.sender == _executor(), "Governor: onlyGovernance");
        _;
    }

    constructor(IVotes _tokenAddress, uint256 _votingDelay) {
        token = _tokenAddress;
        _nonces[block.chainid] = Counters.Counter(1);
        currentTerm = Counters.Counter(1);
        votingDelay = _votingDelay;
    }

    function bindNeighborChains(uint256[] calldata chainIDs) external {
        for (uint256 i = 0; i < chainIDs.length; i++) {
            require(_nonces[chainIDs[i]].current() == 0, "invalid nonce");
            _nonces[chainIDs[i]] = Counters.Counter(1);
        }
    }

    /**
     * @dev Returns an chainID nonce.
     */
    function nonces(uint256 chainID) public view  returns (uint256) {
        return _nonces[chainID].current();
    }

    function term() public view returns (uint256) {
        return currentTerm.current();
    }

    function idle() public view returns (bool) {
        if (currentProposalId == 0) {
            return true;
        }

        ProposalState status = state(currentProposalId);
        if ((ProposalState.Defeated == status) || 
            (ProposalState.Executed == status) || 
            (ProposalState.Expired == status)) {
            return true;
        }

        return false;
    }

    function proposeGovernance(
        uint256            fromChainID,
        uint256            toChainID,
        uint256            voteTerm,
        address[] calldata voters,
        bytes32            descriptionHash
    ) external returns (uint256) {
        require(idle(), "cross multisign is busy");

        require(_getVotes(msg.sender) > 0, "proposer must be voter");
        _checkCrossHeader(fromChainID, toChainID);
        require(voteTerm - term() == 1, "dependent term is invalid");

        bytes memory proposalInfo = CrossDaoCommon.encodeCrossDaoGovernance(uint8(ProposalType.Governor), 
                    fromChainID, toChainID, voteTerm, voters, descriptionHash);
        uint256 proposalID = uint256(keccak256(proposalInfo));

        ProposalDetails storage detail = _proposalDetails[proposalID];
        require(detail.proposer == address(0), "proposal id is existed");

        detail.proposer = msg.sender;
        detail.proposal = proposalInfo;
        detail.proposalType = uint8(ProposalType.Governor);
        detail.toChainID = toChainID;
        _propose(proposalID);
        emit CrossDaoCommon.CrossDaoProposalCreated(proposalID, msg.sender, uint8(ProposalType.Governor), proposalInfo);
        return proposalID;
    }

    function propose(
        uint256 fromChainID,
        uint256 toChainID,
        uint256 voteTerm,
        uint256 nonce,
        address remoteTarget,
        bytes calldata action,
        bytes32 descriptionHash
    ) external returns (uint256){
        require(idle(), "cross multisign is busy");
        
        require(_getVotes(msg.sender) > 0, "proposer must be voter");
        _checkCrossHeader(fromChainID, toChainID);
        require(voteTerm == term(), "dependent term is invalid");
        require(nonce == nonces(toChainID), "nonce is invalid");

        bytes memory proposalInfo = CrossDaoCommon.encodeCrossDaoTx(uint8(ProposalType.Common), 
                fromChainID, toChainID, voteTerm, nonce, remoteTarget, action, descriptionHash);
        uint256 proposalID = uint256(keccak256(proposalInfo));

        ProposalDetails storage detail = _proposalDetails[proposalID];
        require(detail.proposer == address(0), "proposal id is existed");

        detail.proposer = msg.sender;
        detail.proposal = proposalInfo;
        detail.proposalType = uint8(ProposalType.Common);
        detail.toChainID = toChainID;
        _propose(proposalID);
        emit CrossDaoCommon.CrossDaoProposalCreated(proposalID, msg.sender, uint8(ProposalType.Governor), proposalInfo);
        return proposalID;
    }

    function proposeAmendment(
        uint256 fromChainID,
        uint256 toChainID,
        uint256 voteTerm,
        uint256 nonce,
        bytes32 descriptionHash
    ) external returns (uint256) {
        require(idle(), "cross multisign is busy");

        require(_getVotes(msg.sender) > 0, "proposer must be voter");
        _checkCrossHeader(fromChainID, toChainID);

        require(voteTerm == term(), "dependent term is invalid");
        require(nonce <= nonces(toChainID), "nonce is be used");

        bytes memory proposalInfo = CrossDaoCommon.encodeCrossDaoAmendment(uint8(ProposalType.Amendment), 
                    fromChainID, toChainID, voteTerm, nonce, descriptionHash);
        uint256 proposalID = uint256(keccak256(proposalInfo));

        ProposalDetails storage detail = _proposalDetails[proposalID];
        require(detail.proposer == address(0), "proposal id is existed");

        detail.proposer = msg.sender;
        detail.proposal = proposalInfo;
        detail.proposalType = uint8(ProposalType.Amendment);
        detail.toChainID = toChainID;
        _propose(proposalID);
        emit CrossDaoCommon.CrossDaoProposalCreated(proposalID, msg.sender, uint8(ProposalType.Governor), proposalInfo);
        return proposalID;
    }
    
    function proposalDeadline(
        uint256 proposalId
    ) public view virtual returns (uint256) {
        return _proposals[proposalId].voteEnd.getDeadline();
    }

    function castVoteBySig(
        uint256 proposalId,
        uint8   support,
        uint8   v,
        bytes32 r, 
        bytes32 s
    ) external returns (uint256) {
        return _castVote(proposalId, v, r, s, support);
    }

    function execute(
        uint256 proposalId
    ) external {
        ProposalState status = state(proposalId);
        require(status == ProposalState.Succeeded, "proposal not success");
        _proposals[proposalId].executed = true; 

        ProposalDetails storage detail = _proposalDetails[proposalId];
        if (detail.proposalType == uint8(ProposalType.Governor)) {
            CrossDaoGovernance memory dao = detail.proposal.decodeCrossDaoGovernance();
            string memory errorMessage = "fail to change voter";            
            (bool success, bytes memory returnData) = address(token).call(abi.encodeWithSignature("changeVoters(address[])", dao.voters));
            Address.verifyCallResult(success, returnData, errorMessage);

            currentTerm.increment();
        } else {
            _nonces[detail.toChainID].increment();
        }

        emit CrossDaoCommon.CrossDaoBridgeEvent(address(this), proposalId, detail.proposalType, detail.proposal, _encodeSignatures(detail.signatures));
    }

    function state(uint256 proposalId) public view virtual returns (ProposalState) {
        ProposalCore storage proposal = _proposals[proposalId];

        if (proposal.executed) {
            return ProposalState.Executed;
        }

        uint256 deadline = proposalDeadline(proposalId);

        if (deadline == 0) {
            revert("unknown proposal id");
        }

        if (_quorumReached(proposalId)) {
            return ProposalState.Succeeded;
        }

        if (_quorumDefeated(proposalId)) {
            return ProposalState.Defeated;
        }

        if (deadline <= block.timestamp) {
            return ProposalState.Expired;
        }

        return ProposalState.Active;
    }

    function hasVoted(uint256 proposalId, address account) public view virtual returns (bool) {
        return _proposalDetails[proposalId].receipts[account].hasVoted;
    }

    function getReceipt(uint256 proposalId, address voter) public view virtual returns (Receipt memory) {
        return _proposalDetails[proposalId].receipts[voter];
    }

    function quorum(uint256 blockNumber) public view virtual returns (uint256) {
        return token.getPastTotalSupply(blockNumber) * 2 / 3;
    }

    function _setCurrentProposalID(uint256 proposalId) internal {
        currentProposalId = proposalId;
    }

    function _getVotes(address account) internal view returns (uint256) {
        return token.getPastVotes(account, block.number);
    }

    function _checkCrossHeader(
        uint256 fromChainID, 
        uint256 toChainID
    ) internal view {
        require(fromChainID == block.chainid, "from chainID must be my chainID");
        require(nonces(toChainID) != 0, "to chainID is not registered");
    }

    function _propose(
        uint256 proposalID
    ) internal virtual {
        ProposalCore storage proposal = _proposals[proposalID];
        require(proposal.voteEnd.isUnset(), "proposal already exists");

        _setCurrentProposalID(proposalID);
        uint64 deadline = block.timestamp.toUint64() + votingDelay.toUint64();
        proposal.voteEnd.setDeadline(deadline);
        proposal.quorum = quorum(block.number);
        proposal.totalVotes = token.getPastTotalSupply(block.number);
    }

    function _executor() internal view virtual returns (address) {
        return address(this);
    }

    function _castVote(
        uint256 proposalId,
        uint8   v,
        bytes32 r, 
        bytes32 s,
        uint8   support
    ) internal virtual returns (uint256) {
        require(state(proposalId) == ProposalState.Active, "vote is not active");
        address account = ECDSA.recover(
            keccak256(abi.encode(address(this), proposalId, support)),
            v,
            r,
            s
        );
        uint256 weight = _getVotes(account);
        _countVote(proposalId, account, v, r, s, support, weight);
        emit CrossDaoCommon.CrossDaoVoteCast(account, proposalId, support, weight);

        return weight;
    }

    function _countVote(
        uint256 proposalId,
        address account,
        uint8   v,
        bytes32 r, 
        bytes32 s,
        uint8   support,
        uint256 weight
    ) internal virtual {
        ProposalDetails storage details = _proposalDetails[proposalId];
        Receipt storage receipt = details.receipts[account];

        require(!receipt.hasVoted, "vote already cast");
        receipt.hasVoted = true;
        receipt.support = support;
        receipt.votes = SafeCast.toUint96(weight);

        if (support == uint8(VoteType.Against)) {
            details.againstVotes += weight;
        } else if (support == uint8(VoteType.For)) {
            details.forVotes += weight;
            details.signatures.push(Signature(r, s, v));
        } else if (support == uint8(VoteType.Abstain)) {
            details.abstainVotes += weight;
        } else {
            revert("invalid vote type");
        }
    }

    function _quorumReached(uint256 proposalId) internal view virtual returns (bool) {
        ProposalDetails storage details = _proposalDetails[proposalId];
        ProposalCore storage proposal = _proposals[proposalId];
        return proposal.quorum <= details.forVotes;
    }

    function _quorumDefeated(uint256 proposalId) internal view virtual returns (bool) {
        ProposalDetails storage details = _proposalDetails[proposalId];
        ProposalCore storage proposal = _proposals[proposalId];
        return ((details.againstVotes + details.abstainVotes + proposal.quorum) > proposal.totalVotes);
    }

    function _encodeSignatures(Signature[] memory signs) internal view virtual returns (bytes[] memory _bytesSigns) {
        for (uint256 i = 0; i < signs.length; i++) {
            _bytesSigns[i] = abi.encodePacked(signs[i].r, signs[i].s, signs[i].v);
        }
    }
}