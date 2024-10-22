const { expect } = require("chai");
const { ethers } = require("hardhat");
const { Wallet } = require("ethers");

describe("NodesGovernance Contract", function () {
    let NodesGovernance;
    let nodesGovernance;
    let owner;

    const DETECT_DURATION_TIME = 3600; // 1 hour
    const ROUND_DURATION_TIME = 3600;  // 1 hour

    beforeEach(async function () {
        [owner, verifier, addr1, addr2, addr3, addr4, addr5, addr6] = await ethers.getSigners();
        
        let IDENTIFIERS = [addr1.address, addr2.address, addr3.address, addr4.address, addr5.address, addr6.address];
        let WALLETS = [addr1.address, addr2.address, addr3.address, addr4.address, addr5.address, addr6.address];
        
        
        // for (let j = 0; j < 210; j++) {
        //     const wallet = Wallet.createRandom(); // 从第二个索引开始
        //     IDENTIFIERS.push(wallet.address);
        //     WALLETS.push(wallet.address);
        // }

        // console.log(IDENTIFIERS.length)

        // 部署合约
        const NodesGovernanceFactory = await ethers.getContractFactory("NodesGovernance");
        nodesGovernance = await NodesGovernanceFactory.deploy(IDENTIFIERS, WALLETS, DETECT_DURATION_TIME, ROUND_DURATION_TIME, owner.address);
        await nodesGovernance.deployed();
    });

    it("should start a new validation round", async function () {
        await ethers.provider.send("evm_increaseTime", [DETECT_DURATION_TIME + 1]);
        await ethers.provider.send("evm_mine");
        await nodesGovernance.startNewValidationRound();

        const currentRoundId = await nodesGovernance.currentRoundId();
        expect(currentRoundId).to.equal(1);
    });

    it("should not start a new validation round if the previous round has not ended", async function () {
        await ethers.provider.send("evm_increaseTime", [DETECT_DURATION_TIME + 1]);
        await ethers.provider.send("evm_mine");
        await nodesGovernance.startNewValidationRound();
        await expect(nodesGovernance.startNewValidationRound()).to.be.revertedWith("Previous round is not ending");
    });

    it("should allow validators to vote", async function () {
        await ethers.provider.send("evm_increaseTime", [DETECT_DURATION_TIME + 1]);
        await ethers.provider.send("evm_mine");
        await nodesGovernance.startNewValidationRound();
        const currentRoundId = await nodesGovernance.currentRoundId();
        const verifiers = await nodesGovernance.getRoundVerifiers(currentRoundId);
        const verifier = verifiers[0]
        const validators = await nodesGovernance.getValidatorsOfVerifier(currentRoundId, verifier)
        const VOTERS = [addr1, addr2, addr3, addr4, addr5, addr6]
        let voter;
        
        for (let i = 0; i < VOTERS.length; i++) 
            if (VOTERS[i].address == validators[0]) 
                voter = VOTERS[i]

        // 模拟验证人投票
        await nodesGovernance.connect(voter).vote(currentRoundId, verifier, true);
        const voted = await nodesGovernance.votedPerVerifier(currentRoundId, verifier);

        expect(voted.yesVotes).to.equal(1);
        expect(voted.noVotes).to.equal(0);
    });

    it("should complete validation if majority votes yes", async function () {
        await ethers.provider.send("evm_increaseTime", [DETECT_DURATION_TIME + 1]);
        await ethers.provider.send("evm_mine");
        await nodesGovernance.startNewValidationRound();
        const currentRoundId = await nodesGovernance.currentRoundId();

        const verifiers = await nodesGovernance.getRoundVerifiers(currentRoundId);
        const verifier = verifiers[0]
        const validators = await nodesGovernance.getValidatorsOfVerifier(currentRoundId, verifiers[0]);
        const VOTERS = [addr1, addr2, addr3, addr4, addr5, addr6]
        let voters = []
        for (let j = 0; j < validators.length; j++)
            for (let i = 0; i < VOTERS.length; i++)
                if (VOTERS[i].address == validators[j])
                    voters[j] = VOTERS[i]

        // 模拟多名验证人投票
        await expect(nodesGovernance.connect(owner).vote(currentRoundId, verifier, true)).to.be.revertedWith("Invalid validator");
        await nodesGovernance.connect(voters[0]).vote(currentRoundId, verifier, true);
        await nodesGovernance.connect(voters[1]).vote(currentRoundId, verifier, true);
        await nodesGovernance.connect(voters[2]).vote(currentRoundId, verifier, false);
        
        let voted = await nodesGovernance.votedPerVerifier(currentRoundId, verifier);
        expect(voted.completed).to.equal(false);
        await nodesGovernance.connect(voters[3]).vote(currentRoundId, verifier, true);
        await expect(nodesGovernance.connect(voters[4]).vote(currentRoundId, verifier, true)).to.be.revertedWith("Validation already completed");

        voted = await nodesGovernance.votedPerVerifier(currentRoundId, verifier);
        expect(voted.completed).to.equal(true);
        expect(Number(voted.yesVotes)).to.be.greaterThan(Number(voted.noVotes));
    });

    it("should revert if validation time is exceeded", async function () {
        await ethers.provider.send("evm_increaseTime", [DETECT_DURATION_TIME + 1]);
        await ethers.provider.send("evm_mine");
        await nodesGovernance.startNewValidationRound();
        // 快进时间
        await ethers.provider.send("evm_increaseTime", [DETECT_DURATION_TIME + 1]);
        await ethers.provider.send("evm_mine");

        const currentRoundId = await nodesGovernance.currentRoundId();
        await expect(nodesGovernance.vote(currentRoundId, verifier.address, true)).to.be.revertedWith("Validation time exceeded");
    });

    it("should allow owner to settle a period", async function () {
        await ethers.provider.send("evm_increaseTime", [DETECT_DURATION_TIME + 1]);
        await ethers.provider.send("evm_mine");
        await nodesGovernance.startNewValidationRound();
        const detectPeriodId = await nodesGovernance.currentDetectCircleId();

        await ethers.provider.send("evm_increaseTime", [DETECT_DURATION_TIME + 1]);
        await ethers.provider.send("evm_mine");
        await nodesGovernance.startNewValidationRound();

        await expect(nodesGovernance.settlementOnePeriod(100)).to.be.revertedWith("Settlement for deteted period");
        await expect(nodesGovernance.settlementOnePeriod(0)).to.be.revertedWith("Detect period id is not exist");
        await nodesGovernance.settlementOnePeriod(detectPeriodId);
        const [states, totalQuotas] = await nodesGovernance.getOnePeriodSettlement(detectPeriodId);
        expect(states).to.be.an('array');
        expect(totalQuotas.toNumber()).to.be.a('number');
    });
});