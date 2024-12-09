// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";
import "./NodesRegistry.sol";
import "./ShareDataType.sol";
contract AIComputeRental {
    struct GPURequirement {
        uint256 pricePerUnit; // unit is :wei
        uint256 requiredQuantity;
    }

    struct TenderContract {
        uint256 contractId;
        address owner;         // owner of contract
        uint256 depositAmount;
        uint256 leaseDuration; // uint is:s
        uint256 pledgePenaltyRate;
        mapping(string => GPURequirement) gpuRequirements;
        string[] types;
        uint256 leaseStart;
        uint256 leaseEndTime;
        bool    isActive;
        string  extendInfo;
    }

    uint256 public nextContractId = 1;
    uint256 public penaltyRatio = 10;

    NodesRegistry internal registry;
    mapping(uint256 => TenderContract) public contracts;
    mapping(uint256 => NodeComputeUsed[]) public leasedNodes; // 合同绑定的算力节点

    event TenderPublished(uint256 contractId, address indexed owner);
    event LeaseAwarded(uint256 contractId, NodeComputeUsed[] awardedNodes);
    event LeaseRenewed(uint256 contractId, uint256 newLeaseDuration);
    event LeaseExpired(uint256 contractId);

    constructor(address _registry) {
        require(Address.isContract(_registry), "Invalid registry address");
        registry = NodesRegistry(_registry);
    }

    function publishTender(
        uint256 leaseDuration,
        uint256 pledgePenaltyRate,
        string[] calldata gpuTypes,
        uint256[] calldata prices,
        uint256[] calldata quantities,
        string  calldata extendInfo
    ) payable external returns(uint256 contractId){
        require(prices.length == gpuTypes.length && prices.length == quantities.length, "Invalid GPU data");
        require(pledgePenaltyRate <= 100, "Ratio must less than 100");
        TenderContract storage newContract = contracts[nextContractId];
        newContract.contractId = nextContractId;
        newContract.owner = msg.sender;
        newContract.depositAmount = msg.value;
        newContract.leaseDuration = leaseDuration;
        newContract.pledgePenaltyRate = pledgePenaltyRate;
        newContract.isActive = true;
        newContract.leaseEndTime = block.timestamp + leaseDuration;
        newContract.extendInfo = extendInfo;

        for (uint256 i = 0; i < gpuTypes.length; i++) {
            newContract.gpuRequirements[gpuTypes[i]] = GPURequirement({
                pricePerUnit: prices[i],
                requiredQuantity: quantities[i]
            });

            newContract.types.push(gpuTypes[i]);
        }

        uint256 totalCost = calculateNodeCost(newContract.types, newContract.gpuRequirements) * leaseDuration;
        require(msg.value >= totalCost, "Not enough deposit");

        emit TenderPublished(nextContractId, msg.sender);
        contractId = nextContractId;
        nextContractId++;
    }

    function autoBid(
        uint256 contractId
    ) external {
        TenderContract storage tender = contracts[contractId];
        require(tender.isActive, "Contract is not active");
        require(block.timestamp < tender.leaseEndTime, "Contract expired");
        require(msg.sender == tender.owner, "only owner can auto bid");
        NodeComputeUsed[] storage selectedNodes = leasedNodes[contractId];
        require(selectedNodes.length == 0, "Contract has been auto bid");

        string[] memory gpuTypes = new string[](tender.types.length);
        uint256[] memory quantities = new uint256[](tender.types.length);
        for (uint256 i = 0; i < tender.types.length; i++) {
            string memory gpuType = tender.types[i];
            gpuTypes[i] = gpuType;
            quantities[i] = tender.gpuRequirements[gpuType].requiredQuantity;
        }

        // random allocation
        bytes memory random = abi.encodePacked(block.timestamp, blockhash(block.number - 1));
        uint256 startIndex = uint256(keccak256(random)) % registry.length();
        (NodeComputeUsed[] memory nodes, uint256 len) = registry.allocGPU(startIndex, gpuTypes, quantities);
        for (uint256 i = 0; i < len; i++) {
            selectedNodes.push(nodes[i]);
        }

        emit LeaseAwarded(contractId, selectedNodes);
    }

    function renewLease(
        uint256 contractId,
        uint256 additionalDuration
    ) payable external {
        TenderContract storage tender = contracts[contractId];
        require(tender.isActive, "Contract is not active");
        require(msg.sender == tender.owner, "Only the owner can renew");

        uint256 additionalCost = calculateNodeCost(tender.types, tender.gpuRequirements) * (tender.leaseDuration + additionalDuration);
        require((tender.depositAmount + msg.value) >= additionalCost, "Insufficient deposit");

        tender.leaseDuration += additionalDuration;
        tender.leaseEndTime  += additionalDuration;
        tender.depositAmount += msg.value;

        emit LeaseRenewed(contractId, tender.leaseDuration);
    }

    function expireLease(
        uint256 contractId
    ) external {
        TenderContract storage tender = contracts[contractId];
        require(block.timestamp >= tender.leaseEndTime, "Contract not expired yet");
        require(tender.isActive, "Contract already expired");

        tender.isActive = false;
        NodeComputeUsed[] storage nodes = leasedNodes[contractId];
        registry.freeGPU(nodes);

        emit LeaseExpired(contractId);
    }

    function calculateNodeCost(
        string[] storage gpuTypes,
        mapping(string => GPURequirement) storage gpuRequirements
    ) internal view returns (uint256 totalCost) {
        for (uint256 i = 0; i < gpuTypes.length; i++) {
            GPURequirement storage req = gpuRequirements[gpuTypes[i]];
            totalCost += req.pricePerUnit * req.requiredQuantity;
        }
    }
}