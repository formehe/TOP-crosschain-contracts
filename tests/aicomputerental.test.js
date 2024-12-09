const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("AIComputeRental", function () {
  let AIComputeRental, aiComputeRental;
  let NodesRegistry, nodesRegistry;
  let owner, addr1, addr2;

  beforeEach(async function () {
    [owner, addr1, addr2, test] = await ethers.getSigners();

    NodesRegistry = await ethers.getContractFactory("NodesRegistryImpl");
    nodesRegistry = await NodesRegistry.deploy();
    await nodesRegistry.deployed();
    
    AIComputeRental = await ethers.getContractFactory("AIComputeRental");
    aiComputeRental = await AIComputeRental.deploy(nodesRegistry.address);
    await aiComputeRental.deployed();
    await nodesRegistry.nodesRegistryImpl_initialize([test.address],[test.address], [["A100", "V100"]], [[4, 2]], aiComputeRental.address)
  });

  it("The tender contract should be successfully published.", async function () {
    const gpuTypes = ["A100", "V100"];
    let prices = [100000000000000, 200000000000000];
    const quantities = [1, 2];
    const leaseDuration = 3600; // 1 hour
    const pledgePenaltyRate = 5;
    const extendInfo = "Test contract";

    const depositAmount = ethers.utils.parseEther("1");
    await expect(aiComputeRental.connect(addr1).publishTender(
      leaseDuration,
      101,
      gpuTypes,
      prices,
      quantities,
      extendInfo,
      { value: depositAmount }
    )).to.be.revertedWith("Ratio must less than 100")

    await expect(aiComputeRental.connect(addr1).publishTender(
        leaseDuration,
        pledgePenaltyRate,
        gpuTypes,
        prices,
        quantities,
        extendInfo,
        { value: depositAmount }
      )).to.be.revertedWith("Not enough deposit")
    
    prices = [10, 20];

    let contractId = await aiComputeRental.nextContractId();
    await expect(
      aiComputeRental.connect(addr1).publishTender(
        leaseDuration,
        pledgePenaltyRate,
        gpuTypes,
        prices,
        quantities,
        extendInfo,
        { value: depositAmount }
      )
    ).to.emit(aiComputeRental, "TenderPublished")
     .withArgs(contractId, addr1.address);

    const tender = await aiComputeRental.contracts(contractId);
    expect(tender.owner).to.equal(addr1.address);
    expect(tender.depositAmount).to.equal(depositAmount);
    expect(tender.isActive).to.be.true;
  });

  it("Successful auto-bidding", async function () {
    const gpuTypes = ["A100", "V100"];
    const prices = [10, 20];
    const quantities = [1, 2];
    const leaseDuration = 3600; // 1 hour
    const pledgePenaltyRate = 5;
    const extendInfo = "Test contract";

    const depositAmount = ethers.utils.parseEther("1");

    await expect(aiComputeRental.connect(addr1).autoBid(1000))
    .to.be.revertedWith("Contract is not active")

    await aiComputeRental.connect(addr1).publishTender(
      leaseDuration,
      pledgePenaltyRate,
      gpuTypes,
      prices,
      quantities,
      extendInfo,
      { value: depositAmount }
    );

    const expectedAwardedNodes = [
        {
            identifier: test.address,
            gpuType: "A100",
            used: 1
        },
        {
            identifier: test.address,
            gpuType: "V100",
            used: 2
        }
    ];

    let contractId = await aiComputeRental.nextContractId();

    await expect(aiComputeRental.connect(addr1).autoBid(contractId - 1))
    .to.emit(aiComputeRental, "LeaseAwarded");

    const filter = aiComputeRental.filters.LeaseAwarded();
    const events = await aiComputeRental.queryFilter(filter);
    const event = events[0];
    const actualAwardedNodes = event.args.awardedNodes.map((node) => ({
        identifier: node.identifier,
        gpuType: node.gpuType,
        used: node.used.toNumber(),
    }));

    expect(event.args.contractId).to.equal(contractId - 1);
    expect(actualAwardedNodes).to.deep.equal(expectedAwardedNodes);

    await expect(aiComputeRental.connect(addr2).autoBid(contractId - 1))
    .to.be.revertedWith("only owner can auto bid")

    await expect(aiComputeRental.connect(addr1).autoBid(contractId - 1))
    .to.be.revertedWith("Contract has been auto bid")

    await ethers.provider.send("evm_increaseTime", [leaseDuration + 1]);
    await ethers.provider.send("evm_mine");

    await expect(aiComputeRental.connect(addr1).autoBid(contractId - 1))
      .to.be.revertedWith("Contract expired")
  });

  it("Successful lease renewal", async function () {
    const gpuTypes = ["A100", "V100"];
    const prices = [10, 20];
    const quantities = [1, 2];
    const leaseDuration = 3600; // 1 hour
    const pledgePenaltyRate = 5;
    const extendInfo = "Test contract";

    const depositAmount = ethers.utils.parseEther("1");

    await aiComputeRental.connect(addr1).publishTender(
      leaseDuration,
      pledgePenaltyRate,
      gpuTypes,
      prices,
      quantities,
      extendInfo,
      { value: depositAmount }
    );

    const additionalDuration = 3600; // 1 hour
    const additionalDeposit = ethers.utils.parseEther("0.5");

    let contractId = await aiComputeRental.nextContractId();

    await expect(
      aiComputeRental.connect(addr1).renewLease(contractId - 1, additionalDuration, {
        value: additionalDeposit,
      })
    )
      .to.emit(aiComputeRental, "LeaseRenewed")
      .withArgs(contractId - 1, leaseDuration + additionalDuration);

    await expect(aiComputeRental.connect(addr2).renewLease(contractId - 1, additionalDuration))
      .to.be.revertedWith("Only the owner can renew")
  });

  it("Successful contract lease expiration", async function () {
    const gpuTypes = ["A100", "V100"];
    const prices = [10, 20];
    const quantities = [1, 2];
    const leaseDuration = 3600; // 1 hour
    const pledgePenaltyRate = 5;
    const extendInfo = "Test contract";

    const depositAmount = ethers.utils.parseEther("1");

    await aiComputeRental.connect(addr1).publishTender(
      leaseDuration,
      pledgePenaltyRate,
      gpuTypes,
      prices,
      quantities,
      extendInfo,
      { value: depositAmount }
    );

    let contractId = await aiComputeRental.nextContractId();
    await expect(aiComputeRental.connect(addr1).expireLease(contractId - 1))
        .to.be.revertedWith("Contract not expired yet")

    await ethers.provider.send("evm_increaseTime", [leaseDuration + 1]);
    await ethers.provider.send("evm_mine");

    await expect(aiComputeRental.connect(addr1).expireLease(contractId - 1))
      .to.emit(aiComputeRental, "LeaseExpired")
      .withArgs(contractId - 1);

    const tender = await aiComputeRental.contracts(contractId - 1);
    expect(tender.isActive).to.be.false;

    await expect(aiComputeRental.connect(addr1).expireLease(contractId - 1))
        .to.be.revertedWith("Contract already expired")
  });
});