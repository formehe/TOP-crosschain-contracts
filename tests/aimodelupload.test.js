const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("AIModelUpload Contract", function () {
    let AIModelUpload, aiModelUpload;
    let owner, user1;

    beforeEach(async function () {
        [owner, user1] = await ethers.getSigners();

        const AIModelUploadFactory = await ethers.getContractFactory("AIModelUpload");
        aiModelUpload = await AIModelUploadFactory.deploy();
        await aiModelUpload.deployed();
    });

    it("Should initialize contract with correct default values", async function () {
        const nextInstanceId = await aiModelUpload.nextInstanceId();
        const nextRecordId = await aiModelUpload.nextRecordId();
        expect(nextInstanceId).to.equal(1);
        expect(nextRecordId).to.equal(1);
    });

    it("Should record model upload and emit UploadRecorded event", async function () {
        const modelName = "TestModel";
        const modelVersion = "v1.0";
        const modelInfo = "Test model description";

        let nextRecordId = await aiModelUpload.nextInstanceId();

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

    it("Should create model instance and emit ModelInstanceCreated event", async function () {
        const modelName = "TestModel";
        const modelVersion = "v1.0";
        const modelInfo = "Test model description";

        await aiModelUpload.connect(user1).recordModelUpload(modelName, modelVersion, modelInfo);
        let nextInstanceId = await aiModelUpload.nextInstanceId();
        await expect(aiModelUpload.connect(user1).createModelInstance(modelName, modelVersion, "Model Instance 1"))
            .to.emit(aiModelUpload, "ModelInstanceCreated")
            .withArgs(nextInstanceId, modelName, modelVersion, "Model Instance 1");

        const instance = await aiModelUpload.modelInstances(1);

        expect(instance.modelName).to.equal(modelName);
        expect(instance.modelVersion).to.equal(modelVersion);

        await expect(aiModelUpload.connect(user1).createModelInstance(modelName, modelVersion, "Model Instance 1"))
            .to.be.revertedWith("Model instance is exist")

        nextInstanceId = await aiModelUpload.nextInstanceId();
        await expect(aiModelUpload.connect(user1).createModelInstance(modelName, modelVersion, "Model Instance 2"))
            .to.emit(aiModelUpload, "ModelInstanceCreated")
            .withArgs(nextInstanceId, modelName, modelVersion, "Model Instance 2");
    });

    it("Should not allow creating model instance for non-existent model", async function () {
        const modelName = "NonExistentModel";
        const modelVersion = "v1.0";
        
        await expect(
            aiModelUpload.connect(user1).createModelInstance(modelName, modelVersion, "Model Instance 1")
        ).to.be.revertedWith("Model is not existed");
    });
});