const { expect } = require("chai");
const { ethers } = require("hardhat");
describe("AIModels Contract", function () {
    let aiModelUpload;
    let owner, user1;

    const ROUND_DURATION_TIME = 3600;  // 1 hour

    beforeEach(async function () {
        [owner, user1, addr1, addr2, addr3, addr4, addr5, addr6, addr7] = await ethers.getSigners();

        let IDENTIFIERS = [addr1.address, addr2.address, addr3.address, addr4.address, addr5.address, addr6.address];
        let WALLETS = [addr1.address, addr2.address, addr3.address, addr4.address, addr5.address, addr6.address];
        let ALIAS_IDENTIFIERS = ["11111111111111111", "21111111111111111", "31111111111111111", "41111111111111111","51111111111111111","61111111111111111"]
        const gpuTypes = [["A100", "V100"], ["A100", "V100"], ["A100", "V100"], ["A100", "V100"], ["A100", "V100"], ["A100", "V100"]];
        const gpuNums = [[2, 3], [2, 3], [2, 3], [2, 3], [2, 3], [2, 3]];

        // 部署合约
        const NodesGovernanceFactory = await ethers.getContractFactory("NodesGovernance");
        nodesGovernance = await NodesGovernanceFactory.deploy();
        await nodesGovernance.deployed();
        
        const AIModelUploadFactory = await ethers.getContractFactory("AIModels");
        aiModelUpload = await AIModelUploadFactory.deploy(nodesGovernance.address);
        await aiModelUpload.deployed();

        await nodesGovernance.nodesGovernance_initialize(IDENTIFIERS, ALIAS_IDENTIFIERS, WALLETS, gpuTypes, gpuNums, aiModelUpload.address, ROUND_DURATION_TIME)
    });

    it("Should initialize contract with correct default values", async function () {
        const nextRecordId = await aiModelUpload.nextRecordId();
        expect(nextRecordId).to.equal(1);
    });

    it("Should record model upload and emit UploadRecorded event", async function () {
        const modelName = "TestModel";
        const modelVersion = "v1.0";
        const modelInfo = "Test model description";

        let nextRecordId = await aiModelUpload.nextRecordId();

        await expect(aiModelUpload.connect(user1).recordModelUpload(modelName, modelVersion, modelInfo))
            .to.emit(aiModelUpload, "UploadRecorded")
            .withArgs(nextRecordId, user1.address, modelName, modelVersion, modelInfo);

        const recordId = await aiModelUpload.modelRecordIds(`${modelName}/${modelVersion}`);
        const uploadRecord = await aiModelUpload.uploadRecords(recordId);

        expect(uploadRecord.recordId).to.equal(nextRecordId);
        expect(uploadRecord.modelName).to.equal(modelName);
        expect(uploadRecord.modelVersion).to.equal(modelVersion);
        expect(uploadRecord.uploader).to.equal(user1.address);
        expect(uploadRecord.extendInfo).to.equal(modelInfo);
    });

    it("Should not allow recording duplicate model upload", async function () {
        const modelName = "TestModel";
        const modelVersion = "v1.0";
        const modelInfo = "Test model description";

        await aiModelUpload.connect(user1).recordModelUpload(modelName, modelVersion, modelInfo);

        await expect(
            aiModelUpload.connect(user1).recordModelUpload(modelName, modelVersion, modelInfo)
        ).to.be.revertedWith("Model exist");
    });

    it("should allow a node to report a deployment", async function () {
        const modelName = "ModelB";
        const modelVersion = "1.0";
        const modelInfo = "Version 1.0";
        
        const recordId = await aiModelUpload.nextRecordId();
        await aiModelUpload.connect(user1).recordModelUpload(modelName, modelVersion, modelInfo);
    
        await aiModelUpload.connect(addr1).reportDeployment(recordId);
    
        const distribution = await aiModelUpload.getModelDistribution(recordId);
        expect(distribution).to.include(addr1.address);
    
        const deployment = await aiModelUpload.getNodeDeployment(addr1.address);
        expect(deployment.map(d => d.toNumber())).to.include(recordId.toNumber());
    });

    it("should allow a node to remove a deployment", async function () {
        const modelName = "ModelC";
        const modelVersion = "1.0";
        const modelInfo = "Version 1.0";

        const recordId = await aiModelUpload.nextRecordId();
        await aiModelUpload.connect(user1).recordModelUpload(modelName, modelVersion, modelInfo);

        await aiModelUpload.connect(addr1).reportDeployment(recordId);

        await aiModelUpload.connect(addr1).removeDeployment(recordId);

        const distribution = await aiModelUpload.getModelDistribution(recordId);
        expect(distribution).to.not.include(addr1.address);

        const deployment = await aiModelUpload.getNodeDeployment(addr1.address);
        expect(deployment.map(d => d.toNumber())).to.not.include(recordId.toNumber());
    });

    it("should reject deployment report from unregistered node", async function () {
        const modelName = "ModelD";
        const modelVersion = "1.0";
        const modelInfo = "Version 1.0";

        const recordId = await aiModelUpload.nextRecordId();
        await aiModelUpload.connect(user1).recordModelUpload(modelName, modelVersion, modelInfo);

        await nodesGovernance.connect(addr7).registerNode(addr7.address, "71111111111111111", ["A100", "V100"], [3, 2]);
        await expect(aiModelUpload.connect(addr7).reportDeployment(recordId)).to.be.revertedWith(
            "Node is not active"
        );

        const currentRoundId = await nodesGovernance.currentRoundId();
        const candidates = await nodesGovernance.getRoundCandidates(currentRoundId);
        const candidate = candidates[0]
        const validators = await nodesGovernance.getValidatorsOfCandidate(currentRoundId, candidate);
        const VOTERS = [addr1, addr2, addr3, addr4, addr5, addr6]
        let voters = []
        for (let j = 0; j < validators.length; j++)
            for (let i = 0; i < VOTERS.length; i++)
                if (VOTERS[i].address == validators[j])
                    voters[j] = VOTERS[i]

        // 模拟多名验证人投票
        await nodesGovernance.connect(voters[0]).vote(currentRoundId, candidate, true);
        await nodesGovernance.connect(voters[1]).vote(currentRoundId, candidate, true);
        await nodesGovernance.connect(voters[2]).vote(currentRoundId, candidate, false);
        await nodesGovernance.connect(voters[3]).vote(currentRoundId, candidate, true);
        await aiModelUpload.connect(addr7).reportDeployment(recordId)
    });

    it("should reject duplicate model deployments", async function () {
        const modelName = "ModelF";
        const modelVersion = "1.0";
        const modelInfo = "Version 1.0";

        const recordId = await aiModelUpload.nextRecordId();
        await aiModelUpload.connect(user1).recordModelUpload(modelName, modelVersion, modelInfo);

        await aiModelUpload.connect(addr1).reportDeployment(recordId);

        await expect(aiModelUpload.connect(addr1).reportDeployment(recordId)).to.be.revertedWith(
            "Model distribution already exist"
        );
    });
});