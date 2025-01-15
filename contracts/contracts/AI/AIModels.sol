// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./NodesRegistry.sol";

contract AIModels {
    struct ModelEvaluation {
        uint256 parameter;
    }

    NodesRegistry public registry;
    mapping(string => uint256) public modelIds;
    mapping(uint256 => UploadModel) public uploadModels;

    mapping(uint256 => ModelEvaluation) public modelEvaluations;

    mapping(address => uint256) public modelUploadStakes;
    mapping(address => uint256) public modelUsedStakes;
    uint256 public nextModelId = 1;

    mapping(uint256 => address[]) public modelDistribution;
    mapping(address => uint256[]) public nodeDeployment;

    event UploadModeled(uint256 indexed modelId, address indexed uploader, string modelName, string modelVersion, string modelInfo);
    event ModelDeployed(address indexed node, uint256 indexed modelId);
    event ModelRemoved(address indexed node, uint256 indexed modelId);
    event ModelUploadStaked(address indexed uploader, uint256 indexed stake);
    event ModelUsedStaked(address indexed modelUser, uint256 indexed stake);
    event ModelUploadUnstaked(address indexed uploader, uint256 indexed stake);
    event ModelUsedUnstaked(address indexed modelUser, uint256 indexed stake);

    constructor(address _registry) {
        require(_registry != address(0), "Invalid quantity of registry address");
        registry = NodesRegistry(_registry);
    }

    function stakeModelUpload() payable external{
        require(msg.value != 0, "Invalid quantity of model upload stake");
        modelUploadStakes[msg.sender] += msg.value;
        emit ModelUploadStaked(msg.sender, msg.value);
    }

    function stakeModelUsed() payable external{
        require(msg.value != 0, "Invalid model used stake");
        modelUsedStakes[msg.sender] += msg.value;
        emit ModelUsedStaked(msg.sender, msg.value);
    }

    function recordModelUpload(
        string calldata modelName,
        string calldata modelVersion,
        string calldata modelInfo
    ) external returns(uint256 modelId) {
        string memory model = _modelId(modelName, modelVersion);
        require(modelIds[model] == 0, "Model exist");

        uploadModels[nextModelId] = UploadModel({
            modelId: nextModelId,
            modelName: modelName,
            modelVersion: modelVersion,
            uploader: msg.sender,
            extendInfo: modelInfo,
            timestamp : block.timestamp
        });

        modelIds[model] = nextModelId;

        emit UploadModeled(nextModelId, msg.sender, modelName, modelVersion, modelInfo);
        modelId = nextModelId;
        nextModelId++;
    }

    function reportDeployment(
        uint256 modelId
    ) external {
        require(registry.check(msg.sender), "Node is not active");
        UploadModel storage record = uploadModels[modelId];
        require(record.modelId != 0, "Model is not exist");
        
        _addFromModelDistribution(modelId, msg.sender);
        _addFromNodeDeployment(modelId, msg.sender);

        emit ModelDeployed(msg.sender, modelId);
    }

    function removeDeployment(
        uint256 modelId
    ) external {
        _removeFromModelDistribution(modelId, msg.sender);
        _removeFromNodeDeployment(modelId, msg.sender);

        emit ModelRemoved(msg.sender, modelId);
    }

    function getModelDistribution(
        uint256 modelId
    ) external view returns (address[] memory) {
        return modelDistribution[modelId];
    }

    function getNodeDeployment(
        address node
    ) external view returns (uint256[] memory) {
        return nodeDeployment[node];
    }

    function _addFromModelDistribution(
        uint256 modelId, 
        address node
    ) internal {
        address[] storage nodes = modelDistribution[modelId];
        for (uint256 i = 0; i < nodes.length; i++) {
            if (nodes[i] == node) {
                revert("Model distribution already exist");
            }
        }

        modelDistribution[modelId].push(msg.sender);
    }

    function _removeFromModelDistribution(
        uint256 modelId,
        address node
    ) internal {
        address[] storage nodes = modelDistribution[modelId];
        for (uint256 i = 0; i < nodes.length; i++) {
            if (nodes[i] == node) {
                nodes[i] = nodes[nodes.length - 1];
                nodes.pop();
                break;
            }
        }
    }

    function _addFromNodeDeployment(
        uint256 modelId,
        address node
    ) internal {
        uint256[] storage models = nodeDeployment[node];
        for (uint256 i = 0; i < models.length; i++) {
            if (models[i] == modelId) {
                revert("Node deployment already exist");
            }
        }

        nodeDeployment[msg.sender].push(modelId);
    }

    function _removeFromNodeDeployment(
        uint256 modelId,
        address node
    ) internal {
        uint256[] storage models = nodeDeployment[node];
        for (uint256 i = 0; i < models.length; i++) {
            if (models[i] == modelId) {
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