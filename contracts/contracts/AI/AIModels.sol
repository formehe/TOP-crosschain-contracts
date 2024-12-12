// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./NodesRegistry.sol";

contract AIModels {
    struct UploadRecord {
        uint256 recordId;
        string  modelName;
        string  modelVersion;
        address uploader;
        string  extendInfo;
    }

    NodesRegistry public registry;
    mapping(string => uint256) public modelRecordIds;
    mapping(uint256 => UploadRecord) public uploadRecords;
    uint256 public nextRecordId = 1;

    mapping(uint256 => address[]) public modelDistribution;
    mapping(address => uint256[]) public nodeDeployment;

    event UploadRecorded(uint256 indexed recordId, address indexed uploader, string modelName, string modelVersion, string modelInfo);
    event ModelDeployed(address indexed node, uint256 indexed recordId);
    event ModelRemoved(address indexed node, uint256 indexed recordId);

    constructor(address _registry) {
        require(_registry != address(0), "Invalid registry address");
        registry = NodesRegistry(_registry);
    }

    function recordModelUpload(
        string calldata modelName,
        string calldata modelVersion,
        string calldata modelInfo
    ) external returns(uint256 recordId) {
        string memory model = _modelId(modelName, modelVersion);
        require(modelRecordIds[model] == 0, "Model exist");

        uploadRecords[nextRecordId] = UploadRecord({
            recordId: nextRecordId,
            modelName: modelName,
            modelVersion: modelVersion,
            uploader: msg.sender,
            extendInfo: modelInfo
        });

        modelRecordIds[model] = nextRecordId;

        emit UploadRecorded(nextRecordId, msg.sender, modelName, modelVersion, modelInfo);
        recordId = nextRecordId;
        nextRecordId++;
    }

    function reportDeployment(
        uint256 recordId
    ) external {
        require(registry.check(msg.sender), "Node is not active");
        UploadRecord storage record = uploadRecords[recordId];
        require(record.recordId != 0, "Model is not exist");
        
        _addFromModelDistribution(recordId, msg.sender);
        _addFromNodeDeployment(recordId, msg.sender);

        emit ModelDeployed(msg.sender, recordId);
    }

    function removeDeployment(
        uint256 recordId
    ) external {
        _removeFromModelDistribution(recordId, msg.sender);
        _removeFromNodeDeployment(recordId, msg.sender);

        emit ModelRemoved(msg.sender, recordId);
    }

    function getModelDistribution(
        uint256 recordId
    ) external view returns (address[] memory) {
        return modelDistribution[recordId];
    }

    function getNodeDeployment(
        address node
    ) external view returns (uint256[] memory) {
        return nodeDeployment[node];
    }

    function _addFromModelDistribution(
        uint256 recordId, 
        address node
    ) internal {
        address[] storage nodes = modelDistribution[recordId];
        for (uint256 i = 0; i < nodes.length; i++) {
            if (nodes[i] == node) {
                revert("Model distribution already exist");
            }
        }

        modelDistribution[recordId].push(msg.sender);
    }

    function _removeFromModelDistribution(
        uint256 recordId,
        address node
    ) internal {
        address[] storage nodes = modelDistribution[recordId];
        for (uint256 i = 0; i < nodes.length; i++) {
            if (nodes[i] == node) {
                nodes[i] = nodes[nodes.length - 1];
                nodes.pop();
                break;
            }
        }
    }

    function _addFromNodeDeployment(
        uint256 recordId,
        address node
    ) internal {
        uint256[] storage models = nodeDeployment[node];
        for (uint256 i = 0; i < models.length; i++) {
            if (models[i] == recordId) {
                revert("Node deployment already exist");
            }
        }

        nodeDeployment[msg.sender].push(recordId);
    }

    function _removeFromNodeDeployment(
        uint256 recordId,
        address node
    ) internal {
        uint256[] storage models = nodeDeployment[node];
        for (uint256 i = 0; i < models.length; i++) {
            if (models[i] == recordId) {
                models[i] = models[models.length - 1];
                models.pop();
                break;
            }
        }
    }

    function _modelId(
        string memory modelName, 
        string memory modelVersion
    ) internal pure returns(string memory) {
        return string(abi.encodePacked(modelName, "/", modelVersion));
    }
}