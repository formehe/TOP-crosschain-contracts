const hre = require("hardhat");

async function main() {
    const NodesRegistry = await ethers.getContractFactory("NodesGovernance");
    nodesRegistry = await NodesRegistry.deploy();
    await nodesRegistry.deployed();

    console.log("Node registry is :", nodesRegistry.address)
    console.log("Transaction hash :", nodesRegistry.deployTransaction.hash)

    AIWorkload = await ethers.getContractFactory("AIWorkload");
    aiWorkload = await AIWorkload.deploy(nodesRegistry.address);
    await aiWorkload.deployed();

    console.log("AI Work is :", aiWorkload.address)
    console.log("Transaction hash :", aiWorkload.deployTransaction.hash)

    const AIModelUploadFactory = await ethers.getContractFactory("AIModels");
    aiModelUpload = await AIModelUploadFactory.deploy(nodesRegistry.address);
    await aiModelUpload.deployed();
    console.log("AI model is :", aiModelUpload.address)
    console.log("Transaction hash :", aiModelUpload.deployTransaction.hash)

    // await nodesRegistry.nodesGovernance_initialize(IDENTIFIERS, ALIAS_IDENTIFIERS, WALLETS, gpuTypes, gpuNums, addr1.address, ROUND_DURATION_TIME)
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});