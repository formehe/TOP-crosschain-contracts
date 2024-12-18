// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./ShareDataType.sol";
import "./NodesRegistry.sol";
import "hardhat/console.sol";

contract AIWorkload {
    struct Workload {
        uint256 epochId;
        uint256 workload;
        uint256 timestamp;
        uint256 modelId;
        address reporter;
        address worker;
    }

    struct Session {
        uint256 lastEpochId;
        mapping(uint256 => Workload) workloads;
    }

    mapping(uint256 => Session) public sessions;
    NodesRegistry public registry;
    mapping(address => uint256) public totalWorkload;
    mapping(address => uint256) public totalWorkReports;

    event WorkloadReported(uint256 indexed sessionId, address indexed reporter, address worker, uint256 epochId, uint256 workload, uint256 modelId);

    constructor(address _registry) {
        require(_registry != address(0), "Invalid registry");
        registry = NodesRegistry(_registry);
    }

    function _isValidSignature(
        address worker,
        address reporter,
        bytes memory content,
        Signature[] calldata signatures
    ) internal view returns (bool){
        address[] memory signers = new address[](signatures.length);
        uint256 votes;
        bool containsReporter;
        bool containsWorker;

        for (uint256 i = 0; i < signatures.length; i++) {
            bool duplicate;
            bytes memory signatureBytes = abi.encodePacked(signatures[i].r, signatures[i].s, signatures[i].v);
            (address _address,) = ECDSA.tryRecover(ECDSA.toEthSignedMessageHash(content), signatureBytes);
            if (!registry.get(_address).active) {
                continue;
            }

            for (uint256 j = 0; j < votes; j++) {
                if(signers[j] == _address) {
                    duplicate = true;
                    break;
                }
            }

            if (duplicate) {
                continue;
            }

            if (_address == worker) {
                containsWorker = true;
            }

            if (_address == reporter) {
                containsReporter = true;
            }

            signers[votes] = _address;
            votes += 1;
        }

        if (votes < ((signatures.length + 1) / 2)
            || !containsWorker || !containsReporter) {
            return false;
        }

        return true;
    }

    function reportWorkload(
        address worker,
        uint256 workload,
        uint256 modelId,
        uint256 sessionId,
        uint256 epochId,
        Signature[] calldata signatures
    ) external {
        require(worker != address(0), "Invalid owner address");
        require(workload > 0, "Workload must be greater than zero");
        require(signatures.length >= 3, "Length of signatures must more than 3");

        bytes memory content = abi.encode(worker, workload, modelId, sessionId, epochId);
        require(_isValidSignature(worker, msg.sender, content, signatures), "Invalid signature");

        Session storage session = sessions[sessionId];

        require(epochId > session.lastEpochId, "Epoch out of order");
        session.workloads[epochId] = Workload({
            epochId: epochId,
            workload: workload,
            timestamp: block.timestamp,
            modelId: modelId,
            reporter: msg.sender,
            worker: worker
        });

        session.lastEpochId = epochId;
        totalWorkload[worker] += workload;
        totalWorkReports[msg.sender] += workload;
        emit WorkloadReported(sessionId, msg.sender, worker, epochId, workload, modelId);
    }

    function getNodeWorkload(uint256 sessionId, uint256 epochId) external view returns (Workload memory) {
        return sessions[sessionId].workloads[epochId];
    }

    function getLastEpoch(uint256 sessionId) external view returns (uint256) {
        return sessions[sessionId].lastEpochId;
    }

    function getTotalWorkload(
        address node
    ) external view returns (uint256) {
        return totalWorkload[node];
    }

    function getTotalWorkReport(
        address node
    ) external view returns (uint256) {
        return totalWorkReports[node];
    }
}