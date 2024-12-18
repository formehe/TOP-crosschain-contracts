const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("AIWorkload", function () {
  let AIWorkload, aiWorkload;
  let NodesRegistry, nodesRegistry;
  let owner, reporter1, reporter2;
  const ROUND_DURATION_TIME = 3600;  // 1 hour

  beforeEach(async function () {
    [owner, reporter1, reporter2, addr1, addr2, addr3, addr4, addr5, addr6, addr7] = await ethers.getSigners();

    let IDENTIFIERS = [addr1.address, addr2.address, addr3.address, addr4.address, addr5.address, addr6.address];
    let WALLETS = [addr1.address, addr2.address, addr3.address, addr4.address, addr5.address, addr6.address];
    let ALIAS_IDENTIFIERS = ["11111111111111111", "21111111111111111", "31111111111111111", "41111111111111111","51111111111111111","61111111111111111"]
    const gpuTypes = [["A100", "V100"], ["A100", "V100"], ["A100", "V100"], ["A100", "V100"], ["A100", "V100"], ["A100", "V100"]];
    const gpuNums = [[2, 3], [2, 3], [2, 3], [2, 3], [2, 3], [2, 3]];

    // 部署合约
    const NodesRegistry = await ethers.getContractFactory("NodesGovernance");
    nodesRegistry = await NodesRegistry.deploy();
    await nodesRegistry.deployed();

    AIWorkload = await ethers.getContractFactory("AIWorkload");
    aiWorkload = await AIWorkload.deploy(nodesRegistry.address);
    await aiWorkload.deployed();

    await nodesRegistry.nodesGovernance_initialize(IDENTIFIERS, ALIAS_IDENTIFIERS, WALLETS, gpuTypes, gpuNums, addr1.address, ROUND_DURATION_TIME)
  });

  describe("Initialization", function () {
    it("Should initialize with correct registry address", async function () {
      expect(await aiWorkload.registry()).to.equal(nodesRegistry.address);
    });
  });

  describe("reportWorkload", function () {
    it("Should revert if worker address is invalid", async function () {
      await expect(
        aiWorkload.connect(reporter1).reportWorkload(ethers.constants.AddressZero, 100, 1, 1, 1, [])
      ).to.be.revertedWith("Invalid owner address");
    });

    it("Should revert if workload is zero", async function () {
      await expect(
        aiWorkload.connect(reporter1).reportWorkload(owner.address, 0, 1, 1, 1, [])
      ).to.be.revertedWith("Workload must be greater than zero");
    });

    it("Should Length of signatures must more than 3", async function () {
      const signatures = [];
      await expect(
        aiWorkload.connect(reporter1).reportWorkload(owner.address, 100, 1, 1, 1, signatures)
      ).to.be.revertedWith("Length of signatures must more than 3");
    });

    it("Should record workload and emit WorkloadReported event", async function () {
      const workload = 200;
      const content = ethers.utils.defaultAbiCoder.encode(["address", "uint256", "uint256", "uint256", "uint256"], [addr3.address, workload, 1, 1, 1])

      const signature1 = await addr1.signMessage(ethers.utils.arrayify(content));
      const signature2 = await addr2.signMessage(ethers.utils.arrayify(content));
      const signature3 = await addr3.signMessage(ethers.utils.arrayify(content));

      const signatures = [
        { r: signature1.slice(0, 66), s: "0x" + signature1.slice(66, 130), v: parseInt(signature1.slice(130, 132), 16)},
        { r: signature2.slice(0, 66), s: "0x" + signature2.slice(66, 130), v: parseInt(signature2.slice(130, 132), 16)},
        { r: signature3.slice(0, 66), s: "0x" + signature3.slice(66, 130), v: parseInt(signature3.slice(130, 132), 16)},
      ];

      const tx = await aiWorkload.connect(addr1).reportWorkload(addr3.address, workload, 1, 1, 1, signatures);

      const timestamp = (await ethers.provider.getBlock("latest")).timestamp;
      await expect(tx)
        .to.emit(aiWorkload, "WorkloadReported")
        .withArgs(1,addr1.address, addr3.address, 1, workload, 1);

      const totalWorkload = await aiWorkload.getTotalWorkload(addr3.address);
      expect(totalWorkload).to.equal(workload);
    });

    it("should fail if epochId is out of order", async function () {
      let workload = 200;
      let epochId = 3
      let content = ethers.utils.defaultAbiCoder.encode(["address", "uint256", "uint256", "uint256", "uint256"], [addr3.address, workload, 1, 1, epochId])
      let signature1 = await addr1.signMessage(ethers.utils.arrayify(content));
      let signature2 = await addr2.signMessage(ethers.utils.arrayify(content));
      let signature3 = await addr3.signMessage(ethers.utils.arrayify(content));

      let signatures = [
        { r: signature1.slice(0, 66), s: "0x" + signature1.slice(66, 130), v: parseInt(signature1.slice(130, 132), 16) },
        { r: signature2.slice(0, 66), s: "0x" + signature2.slice(66, 130), v: parseInt(signature2.slice(130, 132), 16) },
        { r: signature3.slice(0, 66), s: "0x" + signature3.slice(66, 130), v: parseInt(signature3.slice(130, 132), 16) },
      ];
      await aiWorkload.connect(addr1).reportWorkload(addr3.address, workload, 1, 1, epochId, signatures);

      workload = 200;
      epochId = 2
      content = ethers.utils.defaultAbiCoder.encode(["address", "uint256", "uint256", "uint256", "uint256"], [addr3.address, workload, 1, 1, epochId])
      signature1 = await addr1.signMessage(ethers.utils.arrayify(content));
      signature2 = await addr2.signMessage(ethers.utils.arrayify(content));
      signature3 = await addr3.signMessage(ethers.utils.arrayify(content));

      signatures = [
        { r: signature1.slice(0, 66), s: "0x" + signature1.slice(66, 130), v: parseInt(signature1.slice(130, 132), 16) },
        { r: signature2.slice(0, 66), s: "0x" + signature2.slice(66, 130), v: parseInt(signature2.slice(130, 132), 16) },
        { r: signature3.slice(0, 66), s: "0x" + signature3.slice(66, 130), v: parseInt(signature3.slice(130, 132), 16) },
      ];
  
      await expect(
        aiWorkload.connect(addr1).reportWorkload(addr3.address, workload, 1, 1, epochId, signatures)
      ).to.be.revertedWith("Epoch out of order");
    });

    it("Should revert if agreement count does not exceed half", async function () {
      const workload = 200;
      const content = ethers.utils.defaultAbiCoder.encode(["address", "uint256", "uint256", "uint256", "uint256"], [owner.address, workload, 1, 1, 1])

      const signature1 = await reporter1.signMessage(ethers.utils.arrayify(content));
      const signature2 = await reporter2.signMessage(ethers.utils.arrayify(content));
      const signature3 = await owner.signMessage(ethers.utils.arrayify(content));

      const signatures = [
        { r: signature1.slice(0, 66), s: "0x" + signature1.slice(66, 130), v: parseInt(signature1.slice(130, 132), 16) },
        { r: signature2.slice(0, 66), s: "0x" + signature2.slice(66, 130), v: parseInt(signature2.slice(130, 132), 16) },
        { r: signature3.slice(0, 66), s: "0x" + signature3.slice(66, 130), v: parseInt(signature3.slice(130, 132), 16) },
      ];

      await expect(
        aiWorkload.connect(reporter1).reportWorkload(owner.address, workload, 1, 1, 1, signatures)
      ).to.be.revertedWith("Invalid signature");
    });

    it("Should revert duplicate signer", async function () {
      const workload = 200;
      let content = ethers.utils.defaultAbiCoder.encode(["address", "uint256", "uint256", "uint256", "uint256"], [addr3.address, workload, 1, 1, 1])

      let signature1 = await addr1.signMessage(ethers.utils.arrayify(content));
      let signature2 = await addr2.signMessage(ethers.utils.arrayify(content));

      let signatures = [
        { r: signature1.slice(0, 66), s: "0x" + signature1.slice(66, 130), v: parseInt(signature1.slice(130, 132), 16)},
        { r: signature2.slice(0, 66), s: "0x" + signature2.slice(66, 130), v: parseInt(signature2.slice(130, 132), 16)},
        { r: signature1.slice(0, 66), s: "0x" + signature1.slice(66, 130), v: parseInt(signature1.slice(130, 132), 16)},
      ];

      await expect(aiWorkload.connect(addr1).reportWorkload(addr3.address, workload, 1, 1, 1, signatures))
        .to.be.revertedWith("Invalid signature")

      content = ethers.utils.defaultAbiCoder.encode(["address", "uint256", "uint256", "uint256", "uint256"], [addr1.address, workload, 1, 1, 1])

      signature1 = await addr1.signMessage(ethers.utils.arrayify(content));
      signature2 = await addr2.signMessage(ethers.utils.arrayify(content));

      signatures = [
        { r: signature1.slice(0, 66), s: "0x" + signature1.slice(66, 130), v: parseInt(signature1.slice(130, 132), 16)},
        { r: signature2.slice(0, 66), s: "0x" + signature2.slice(66, 130), v: parseInt(signature2.slice(130, 132), 16)},
        { r: signature1.slice(0, 66), s: "0x" + signature1.slice(66, 130), v: parseInt(signature1.slice(130, 132), 16)},
      ];
      
      await expect(aiWorkload.connect(reporter1).reportWorkload(addr1.address, workload, 1, 1, 1, signatures))
        .to.be.revertedWith("Invalid signature")
      
      await aiWorkload.connect(addr2).reportWorkload(addr1.address, workload, 1, 1, 1, signatures)
    });
  });

  describe("getRecentWorkload", function () {
    it("Should calculate recent workload correctly", async function () {
      let content = ethers.utils.defaultAbiCoder.encode(["address", "uint256", "uint256", "uint256", "uint256"], [addr3.address, 100, 1, 1, 1])

      let signature1 = await addr1.signMessage(ethers.utils.arrayify(content));
      let signature2 = await addr2.signMessage(ethers.utils.arrayify(content));
      let signature3 = await addr3.signMessage(ethers.utils.arrayify(content));

      let signatures = [
        { r: signature1.slice(0, 66), s: "0x" + signature1.slice(66, 130), v: parseInt(signature1.slice(130, 132), 16)},
        { r: signature2.slice(0, 66), s: "0x" + signature2.slice(66, 130), v: parseInt(signature2.slice(130, 132), 16)},
        { r: signature3.slice(0, 66), s: "0x" + signature3.slice(66, 130), v: parseInt(signature3.slice(130, 132), 16)},
      ];

      await aiWorkload.connect(addr1).reportWorkload(addr3.address, 100, 1, 1, 1, signatures);

      await ethers.provider.send("evm_increaseTime", [60 * 60 * 24]); // Advance 1 day
      await ethers.provider.send("evm_mine");

      // const timestamp2 = (await ethers.provider.getBlock("latest")).timestamp;
      content = ethers.utils.defaultAbiCoder.encode(["address", "uint256", "uint256", "uint256", "uint256"], [addr3.address, 200, 1, 1, 2])

      signature1 = await addr1.signMessage(ethers.utils.arrayify(content));
      signature2 = await addr2.signMessage(ethers.utils.arrayify(content));
      signature3 = await addr3.signMessage(ethers.utils.arrayify(content));

      signatures = [
        { r: signature1.slice(0, 66), s: "0x" + signature1.slice(66, 130), v: parseInt(signature1.slice(130, 132), 16)},
        { r: signature2.slice(0, 66), s: "0x" + signature2.slice(66, 130), v: parseInt(signature2.slice(130, 132), 16)},
        { r: signature3.slice(0, 66), s: "0x" + signature3.slice(66, 130), v: parseInt(signature3.slice(130, 132), 16)},
      ];
      await aiWorkload.connect(addr1).reportWorkload(addr3.address, 200, 1, 1, 2, signatures);

      const recentWorkload = await aiWorkload.getTotalWorkload(addr3.address);
      expect(recentWorkload).to.equal(300);
    });
  });
});