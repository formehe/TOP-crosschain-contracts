// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/structs/BitMaps.sol";
import "../common/AdminControlledUpgradeable.sol";

contract Models is AdminControlledUpgradeable {
    using BitMaps for BitMaps.BitMap;
    IERC20 public aiToken; // AI Token 合约的地址

    struct UploadRecord {
        uint256 recordId; // 上传记录单号
        string  modelName; // 模型名字
        string  modelVersion; // 模型版本
        address uploader; // 模型上传者钱包地址
    }

    mapping(string => uint256) public modelRecordIds; // 模型和记录单号
    mapping(uint256 => UploadRecord) public uploadRecords; // 存储上传记录
    uint256 public nextRecordId; // 下一个记录 ID

    struct ModelInstance {
        string modelName;    // 模型名字
        string modelVersion; // 模型版本
    }

    mapping(uint256 => ModelInstance) public modelInstances; // 存储模型实例
    BitMaps.BitMap internal _rewardRecords;
    uint256 public nextInstanceId; // 下一个模型实例ID

    event UploadRecorded(uint256 indexed recordId, address indexed uploader, uint256 reward, string modelInfo);
    event ModelInstanceCreated(uint256 indexed instanceId, string modelName, string modelVersion);
    event ModelUsingRewardTransfered(uint256 indexed rewardId, uint256 indexed instanceId, uint256[] parameters, uint256 reward);
    event RewardCreated(uint256 indexed rewardId, uint256 indexed instanceId, address[] participants, uint256[][] rewards);

    constructor(address _aiTokenAddress, address _owner) initializer{
        require(Address.isContract(_aiTokenAddress), "Invalid token address");
        require(_owner != address(0), "Invalid owner");
        aiToken = IERC20(_aiTokenAddress); // 初始化 AI Token 合约地址
        nextInstanceId = 1; // 从1开始
        nextRecordId = 1;
        require(_owner != address(0), "Invalid owner");
        _setRoleAdmin(ADMIN_ROLE, OWNER_ROLE);
        _setRoleAdmin(CONTROLLED_ROLE, ADMIN_ROLE);

        _grantRole(OWNER_ROLE, _owner);
        _grantRole(ADMIN_ROLE, msg.sender);

        AdminControlledUpgradeable._AdminControlledUpgradeable_init(msg.sender, 0xff);
    }

    // 记录模型上传并计算奖励
    function recordModelUpload(
        address uploader, 
        uint256[] memory parameters,
        string memory modelName,
        string memory modelVersion,
        string memory modelInfo
    ) external onlyRole(CONTROLLED_ROLE) {
        string memory model = _modelId(modelName, modelVersion);
        require(modelRecordIds[model] == 0, "Model exist");
        uint256 reward = _calculateUploadReward(parameters); // 计算奖励的 AI Token

        // 创建上传记录
        uploadRecords[nextRecordId] = UploadRecord({
            recordId: nextRecordId,
            modelName: modelName,
            modelVersion: modelVersion,
            uploader: uploader
        });

        modelRecordIds[model] = nextRecordId;

        // 将奖励的 AI Token 转移给模型上传者
        if (reward != 0 ) {
            require(aiToken.transferFrom(msg.sender, uploader, reward), "Transfer failed"); // 从 AI Token 合约转移奖励
        }
        emit UploadRecorded(nextRecordId, uploader, reward, modelInfo);
        nextRecordId++; // 更新下一个记录 ID
    }

    // 计算奖励的 AI Token（示例公式）
    function _calculateUploadReward(
        uint256[] memory parameters
    ) internal pure returns (uint256) {
        // 这里可以根据参数值实现复杂的计算逻辑
        // 示例：将参数值相加并乘以一个固定值
        uint256 total = 0;
        for (uint256 i = 0; i < parameters.length; i++) {
            total += parameters[i];
        }
        return total * 10; // 示例：假设每个参数值的总和乘以 10
    }

    // 创建模型实例
    function createModelInstance(
        string memory modelName, 
        string memory modelVersion
    ) external onlyRole(CONTROLLED_ROLE) {
        string memory model = _modelId(modelName, modelVersion);
        require(modelRecordIds[model] != 0, "Model is not existed");
        modelInstances[nextInstanceId] = ModelInstance({
            modelName: modelName,
            modelVersion: modelVersion
        });

        emit ModelInstanceCreated(nextInstanceId, modelName, modelVersion);
        nextInstanceId++; // 更新下一个模型实例ID
    }

    // 创建奖励记录
    function createReward(
        uint256 instanceId,
        uint256 rewardId,
        uint256[] memory parameters,
        address[] memory participants, 
        uint256[][] memory rewardsParameters
    ) external onlyRole(CONTROLLED_ROLE) {
        require(participants.length == rewardsParameters.length, "Participants and rewards length mismatch");
        ModelInstance storage instance = modelInstances[instanceId];
        require(bytes(instance.modelName).length != 0, "Model instance is not existed");
        require(!_rewardRecords.get(rewardId), "Reward has been transfered");

        string memory model = _modelId(instance.modelName, instance.modelVersion);
        uint256 reward = _calculateUsingReward(parameters);
        address uploader = uploadRecords[modelRecordIds[model]].uploader;

        _rewardRecords.set(rewardId);
        uint256 totalReward = reward;
        uint256[] memory rewards = new uint256[](rewardsParameters.length);
        for (uint256 i = 0; i < rewards.length; i++) {
            rewards[i] = _calculateUsingReward(rewardsParameters[i]);
            totalReward = totalReward + rewards[i];
        }

        require(aiToken.transferFrom(msg.sender, address(this), totalReward), "Token transfer failed"); // 从 AI Token 合约转移奖励

        require(aiToken.transfer(uploader, reward), "Token transfer failed"); // 从 AI Token 合约转移奖励
        emit ModelUsingRewardTransfered(rewardId, instanceId, parameters, reward);

        // 将 AI Token 转移给参与者
        for (uint256 i = 0; i < participants.length; i++) {
            require(aiToken.transfer(participants[i], rewards[i]), "Token transfer failed");
        }

        emit RewardCreated(rewardId, instanceId, participants, rewardsParameters);
    }

    function _calculateUsingReward(
        uint256[] memory parameters
    ) internal pure returns (uint256) {
        // 这里可以根据参数值实现复杂的计算逻辑
        // 示例：将参数值相加并乘以一个固定值
        uint256 total = 0;
        for (uint256 i = 0; i < parameters.length; i++) {
            total += parameters[i];
        }
        return total * 10; // 示例：假设每个参数值的总和乘以 10
    }

    function _modelId(
        string memory modelName, 
        string memory modelVersion
    ) internal pure returns(string memory) {
        return string(abi.encodePacked(modelName, "/", modelVersion));
    }
}