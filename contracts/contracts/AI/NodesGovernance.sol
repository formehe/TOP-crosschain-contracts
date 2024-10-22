// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../common/AdminControlledUpgradeable.sol";
import "./ShareDataType.sol";
import "./NodesRegistry.sol";

contract NodesGovernance is NodesRegistry{
    uint256 public detectDurationTime;
    uint256 public roundDurationTime;

    enum VoteType {None, Active, Against, For}

    struct VerifierVoted {
        address verifier;   // 被验证节点
        uint128 yesVotes;   // 通过投票次数
        uint128 noVotes;    // 不通过投票次数
        bool    completed;  // 验证是否完成
    }

    struct ValidatorVote {
        mapping(address => VoteType) validators;
    }

    struct RoundRange {
        uint256 startId;
        uint256 endId;
        uint256 startTime;
        uint256 endTime;
    }

    struct ValidationRound {
        address[]     verifierSets; // 验证集
        uint256       numOfNodes;
        uint256       expectedCompletionTime; // 验证期望完成时间
    }

    mapping(uint256 => mapping(address => ValidatorVote)) internal votesPerValidator; // 验证者投票信息
    mapping(uint256 => mapping(address => address[])) public validatorsPerVerifier; // 验证者集合
    mapping(uint256 => mapping(address => VerifierVoted)) public votedPerVerifier; // 存储轮次信息
    mapping(uint256 => ValidationRound) public verifierPerRound; // 存储轮次信息

    mapping(uint256 => RoundRange) public detectPeriods;
    mapping(uint256 => mapping(address => NodeState)) internal stateOfNodes;
    mapping(uint256 => address[]) internal nodesPerPeriod;
    mapping(uint256 => uint256) internal quotaPerPeriod;

    uint256 public currentDetectCircleId;
    uint256 public currentDetectCricleStartTime;
    uint256 public currentRoundId; // 当前轮次ID
    uint256 public currentRoundStartTime;
    uint256 public constant VALIDATOR_PER_VERIFIER = 5; // 每个被验证节点需要的验证节点数
    uint256 public constant MIN_VERIFIER = 5; // 被验证节点数

    event ValidationStarted(uint256 roundId, uint256 expectedCompletionTime, address verifier, address[] validators);
    event ValidationResult(uint256 roundId, address validator, bool result);
    event SettlementResult(NodeState[] states, uint256 totalQuota);

    constructor(
        address[]  memory  _identifiers, 
        address[] memory _walletAccounts, 
        uint256          _detectDurationTime,
        uint256          _roundDuratimeTime,
        address          _owner
    ) NodesRegistry(_identifiers, _walletAccounts, _owner){
        require(_owner != address(0), "Invalid owner");
        require(_identifiers.length > MIN_VERIFIER, "Must larger than 5");
        currentRoundStartTime = block.timestamp;

        detectDurationTime = _detectDurationTime;
        roundDurationTime = _roundDuratimeTime;
    }

    function _pickVerifierValidators(
        uint256 detectId, 
        uint256 roundId, 
        uint256 expectFinishTime
    ) internal {
        uint256 numOfVerifiers = 0;
        RoundRange storage range = detectPeriods[detectId];
        for (uint256 i = 0; numOfVerifiers < MIN_VERIFIER; i++) {
            bytes memory randomVerifier = abi.encodePacked(block.timestamp, blockhash(block.number - 1), i);
            uint256 verifierIndex = uint256(keccak256(randomVerifier)) % length();
            address verifier = at(verifierIndex).identifier;
            if ((at(verifierIndex).unRegistrationTime != 0) || 
                (at(verifierIndex).registrationTime > range.startTime)) {
                continue;
            }

            if (validatorsPerVerifier[roundId][verifier].length != 0) {
                continue;
            }

            numOfVerifiers++;

            verifierPerRound[roundId].expectedCompletionTime = expectFinishTime;
            verifierPerRound[roundId].verifierSets.push(verifier);
            verifierPerRound[roundId].numOfNodes = length();
            votedPerVerifier[roundId][verifier] = VerifierVoted({
                verifier: verifier,
                yesVotes: 0,
                noVotes: 0,
                completed: false
            });

            uint256 numOfValidators = 0;
            for (uint256 j = 0; numOfValidators < VALIDATOR_PER_VERIFIER; j++) {
                bytes memory randomValidator = abi.encodePacked(randomVerifier, j);
                uint256 validatorIndex = uint256(keccak256(randomValidator)) % length();
                address validator = at(validatorIndex).identifier;
                if (at(validatorIndex).unRegistrationTime != 0) {
                    continue;
                }
                
                ValidatorVote storage validatorVote = votesPerValidator[roundId][verifier];

                if ((validator != verifier) && (validatorVote.validators[validator] == VoteType.None)) {
                    validatorVote.validators[validator] = VoteType.Active;
                    validatorsPerVerifier[roundId][verifier].push(validator);
                    numOfValidators++;
                }
            }

            emit ValidationStarted(roundId, expectFinishTime, verifier, validatorsPerVerifier[roundId][verifier]);
        }
    }

    function _lenOfAvailableNodes(
        uint256 detectId
    ) internal view returns(uint256 count) {
        RoundRange storage range = detectPeriods[detectId];
        for (uint256 i = 0; i < length(); i++) {
            if ((at(i).unRegistrationTime != 0) || 
                (at(i).registrationTime > range.startTime)) {
                continue;
            }

            count++;
        }

        return count;
    }

    // 开始新一轮验证
    function startNewValidationRound(
    ) external onlyRole(CONTROLLED_ROLE) returns (uint256 detectId, uint256 roundId){
        uint256 currentTime = block.timestamp;
        require((currentTime - currentRoundStartTime) > roundDurationTime, "Previous round is not ending");

        currentRoundId++;
        currentRoundStartTime = currentTime;
        if ((currentTime - currentDetectCricleStartTime) > detectDurationTime) {
            currentDetectCircleId++;
            currentDetectCricleStartTime = currentTime;
            detectPeriods[currentDetectCircleId] = RoundRange(currentRoundId, currentRoundId, currentTime, currentTime);
        } else {
            detectPeriods[currentDetectCircleId].endId = currentRoundId;
            detectPeriods[currentDetectCircleId].endTime = currentTime;
        }

        verifierPerRound[currentRoundId].expectedCompletionTime = currentTime + roundDurationTime;
        verifierPerRound[currentRoundId].numOfNodes = _lenOfAvailableNodes(currentDetectCircleId);
        _pickVerifierValidators(currentDetectCircleId, currentRoundId, currentTime + roundDurationTime);
        return (currentDetectCircleId, currentRoundId);
    }

    // 验证节点投票
    function vote(
        uint256 roundId,
        address verifier,
        bool result
    ) external {
        ValidationRound storage round = verifierPerRound[roundId];
        require(round.expectedCompletionTime >= block.timestamp, "Validation time exceeded");
        ValidatorVote storage validatorVote = votesPerValidator[roundId][verifier];
        require(validatorVote.validators[msg.sender] == VoteType.Active, "Invalid validator");

        VerifierVoted storage voted = votedPerVerifier[roundId][verifier];
        require(!voted.completed, "Validation already completed");

        // 更新投票结果
        if (result) {
            voted.yesVotes++;
            validatorVote.validators[msg.sender] = VoteType.For;
        } else {
            voted.noVotes++;
            validatorVote.validators[msg.sender] = VoteType.Against;
        }

        uint256 len = validatorsPerVerifier[roundId][verifier].length;

        if (((voted.yesVotes + voted.noVotes) == len) 
            && (voted.yesVotes == voted.noVotes)) {
            voted.completed = true;
            emit ValidationResult(roundId, msg.sender, false);
            return;
        }

        // 检查是否达到多数通过
        if (voted.yesVotes > (len / 2)) {
            voted.completed = true;
            emit ValidationResult(roundId, msg.sender, true);
        } else if (voted.noVotes > (len / 2)) {
            voted.completed = true;
            emit ValidationResult(roundId, msg.sender, false);
        }
    }

    function getRoundVerifiers(
        uint256 roundId
    ) public view returns (address[] memory verifiers) {
        return verifierPerRound[roundId].verifierSets;
    }

    function getValidatorsOfVerifier(
        uint256 roundId,
        address verifier
    ) public view returns (address[] memory validators) {
        return validatorsPerVerifier[roundId][verifier];
    }

    function settlementOnePeriod(
        uint256 detectPeroidId
    ) public returns (NodeState[] memory states, uint256 totalQuotas) {
        require(detectPeroidId < currentDetectCircleId, "Settlement for deteted period");
        RoundRange storage range = detectPeriods[detectPeroidId];

        require(range.startId != 0, "Detect period id is not exist");
        address[] storage nodes = nodesPerPeriod[detectPeroidId];
        require(nodes.length == 0, "Period has been settelemented");
        uint256 roundsInPeroid = range.endId - range.startId + 1;
        uint256 noVotes;
        
        for (uint256 i = 0; i < length(); i++){
            address identifier = at(i).identifier;
            address wallet = at(i).wallet;
            if ((at(i).unRegistrationTime != 0) || (at(i).registrationTime > range.startTime)) {
                continue;
            }

            nodes.push(identifier);
            stateOfNodes[detectPeroidId][identifier] = NodeState(
                0, 0, uint128(roundsInPeroid), wallet, identifier);
        }

        for (uint256 i = range.startId; i <= range.endId; i++) {
            ValidationRound storage validationRound = verifierPerRound[i];
            totalQuotas = totalQuotas + validationRound.numOfNodes;
            for (uint256 j = 0; j < validationRound.verifierSets.length; j++) {
                address verifier = validationRound.verifierSets[j];
                VerifierVoted storage voted = votedPerVerifier[i][verifier];
                if (voted.verifier == address(0)) {
                    continue;
                }

                NodeState storage state = stateOfNodes[detectPeroidId][verifier];

                if (!voted.completed) {
                    noVotes++;
                    state.failedCnt++;
                    continue;
                }

                if (voted.yesVotes <= voted.noVotes) {
                    noVotes++;
                    state.failedCnt++;
                    continue;
                }

                state.successfulCnt++;
            }
        }

        quotaPerPeriod[detectPeroidId] = totalQuotas;
        states = new NodeState[](nodes.length);
        for (uint256 i = 0; i < nodes.length; i++){
            address identifier = nodes[i];
            NodeState storage state = stateOfNodes[detectPeroidId][identifier];
            if (state.identifier != address(0)) {
                states[i] = stateOfNodes[detectPeroidId][identifier];
            }
        }

        emit SettlementResult(states, totalQuotas);
        return (states, totalQuotas);
    }

    function getOnePeriodSettlement(
        uint256 detectPeroidId
    ) public view returns (NodeState[] memory states, uint256 totalQuotas) {
        address[] storage nodes = nodesPerPeriod[detectPeroidId];
        states = new NodeState[](nodes.length);
        for (uint256 i = 0; i < nodes.length; i++){
            address identifier = nodes[i];
            NodeState storage state = stateOfNodes[detectPeroidId][identifier];
            if (state.identifier != address(0)) {
                states[i] = stateOfNodes[detectPeroidId][identifier];
            }
        }

        return (states, quotaPerPeriod[detectPeroidId]);
    }
}