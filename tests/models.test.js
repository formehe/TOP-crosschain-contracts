const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Models Contract", function () {
    let Models;
    let models;
    let AI_TOKEN;
    let aiToken;
    let owner;
    let addr1;
    let addr2;

    const initialSupply = ethers.utils.parseEther("1000"); // AI Token 初始供应量

    beforeEach(async function () {
        [owner, addr1, addr2] = await ethers.getSigners();

        // 部署一个 ERC20 Token 作为 AI Token
        const AIToken = await ethers.getContractFactory("AIToken");
        aiToken = await AIToken.deploy(initialSupply, 100, owner.address); // 模拟 AI Token 合约
        await aiToken.deployed();

        Models = await ethers.getContractFactory("MockModels");
        models = await Models.deploy(aiToken.address, owner.address);
        await models.deployed();
    });

    describe("Deployment", function () {
        it("Should set the correct AI Token address", async function () {
            expect(await models.aiToken()).to.equal(aiToken.address);
        });
    });

    describe("Model Uploading", function () {
        it("Should record model upload and transfer reward", async function () {
            const parameters = [1, 2, 3];
            const reward = await models.calculateUploadReward(parameters);
            await aiToken.mint(reward); // Mint reward to Models contract
            
            await aiToken.approve(models.address, reward);
            await models.recordModelUpload(addr1.address, parameters, "ModelA", "v1.0", "Info about ModelA");
            const record = await models.uploadRecords(1); // 获取记录单号为0的上传记录
            
            expect(record.uploader).to.equal(addr1.address);
            expect(record.modelName).to.equal("ModelA");
            expect(record.modelVersion).to.equal("v1.0");
            expect(await aiToken.balanceOf(addr1.address)).to.equal(reward);
        });

        it("Should revert if the model already exists", async function () {
            const parameters = [1, 2, 3];
            const reward = await models.calculateUploadReward(parameters);
            await aiToken.mint(reward); // Mint reward to Models contract
            await aiToken.approve(models.address, reward);
            await models.recordModelUpload(addr1.address, parameters, "ModelA", "v1.0", "Info about ModelA");

            await expect(models.recordModelUpload(addr1.address, parameters, "ModelA", "v1.0", "Info about ModelA"))
                .to.be.revertedWith("Model exist");
        });
    });

    describe("Creating Model Instances", function () {
        it("Should create a model instance", async function () {
            const parameters = [1, 2, 3];

            const reward = await models.calculateUploadReward(parameters);
            await aiToken.mint(reward); // Mint reward to Models contract
            await aiToken.approve(models.address, reward);
            await models.recordModelUpload(addr1.address, parameters, "ModelA", "v1.0", "Info about ModelA");
            await models.createModelInstance("ModelA", "v1.0");
            
            const instance = await models.modelInstances(1);
            expect(instance.modelName).to.equal("ModelA");
            expect(instance.modelVersion).to.equal("v1.0");
        });

        it("Should revert if the model does not exist", async function () {
            await expect(models.createModelInstance("ModelB", "v1.0"))
                .to.be.revertedWith("Model is not existed");
        });
    });

    describe("Creating Rewards", function () {
        beforeEach(async function () {
            const parameters = [1, 2, 3];
            const reward = await models.calculateUploadReward(parameters);
            await aiToken.mint(reward); // Mint reward to Models contract
            await aiToken.approve(models.address, reward);
            await models.recordModelUpload(addr1.address, parameters, "ModelA", "v1.0", "Info about ModelA");
            await models.createModelInstance("ModelA", "v1.0");
            await aiToken.connect(addr1).burn(reward);
        });

        it("Should create a reward and transfer tokens to participants", async function () {
            const rewardParameters = [1, 2];
            const rewardAmount = await models.calculateUsingReward(rewardParameters);
            const participants = [addr1.address];
            const rewards = [rewardParameters];
            let reward = rewardAmount            
            for (let i = 0; i < rewards.length; i++)
                reward = Number(reward) + Number(await models.calculateUsingReward(rewards[i]));
            await aiToken.mint(reward); // Mint reward to Models contract
            await aiToken.approve(models.address, reward);

            await models.createReward(1, 1, rewardParameters, participants, rewards);
            expect(await aiToken.balanceOf(addr1.address)).to.equal(reward);
        });

        it("Should revert if participants and rewards length mismatch", async function () {
            const participants = [addr1.address];
            const rewards = [[1,2],[1,2]];

            await expect(models.createReward(1, 1, [], participants, rewards))
                .to.be.revertedWith("Participants and rewards length mismatch");
                await expect(models.createReward(100, 1, [], [], []))
                .to.be.revertedWith("Model instance is not existed");
        });

        it("Should revert if reward has already been transferred", async function () {
            const rewardParameters = [1, 2];
            const rewardAmount = await models.calculateUsingReward(rewardParameters);
            const participants = [addr1.address];
            const rewards = [rewardParameters];
            let reward = rewardAmount            
            for (let i = 0; i < rewards.length; i++)
                reward = Number(reward) + Number(await models.calculateUsingReward(rewards[i]));
            await aiToken.mint(reward); // Mint reward to Models contract
            await aiToken.approve(models.address, reward);

            await models.createReward(1, 1, rewardParameters, participants, rewards);
            await expect(models.createReward(1, 1, rewardParameters, participants, rewards))
                .to.be.revertedWith("Reward has been transfered");
        });
    });
});