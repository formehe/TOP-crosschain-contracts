const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("NodesConstantReward", function () {
    let NodesGovernance, nodesGovernance, NodesConstantReward, nodesConstantReward;
    let owner, addr1, addr2;
    const DETECT_DURATION_TIME = 3600; // 1 hour
    const ROUND_DURATION_TIME = 360;  // 1 hour

    beforeEach(async function () {
        [owner, addr1, addr2, addr3, addr4, addr5, addr6] = await ethers.getSigners();
        const IDENTIFIERS = [addr1.address, addr2.address, addr3.address, addr4.address, addr5.address, addr6.address];
        const WALLETS = [addr1.address, addr2.address, addr3.address, addr4.address, addr5.address, addr6.address];

        // 部署 NodesGovernance 合约
        NodesGovernance = await ethers.getContractFactory("NodesGovernance");
        nodesGovernance = await NodesGovernance.deploy(IDENTIFIERS, WALLETS, DETECT_DURATION_TIME, ROUND_DURATION_TIME, owner.address);
        await nodesGovernance.deployed();

        // 部署 NodesConstantReward 合约
        NodesConstantReward = await ethers.getContractFactory("NodesConstantReward");
        nodesConstantReward = await NodesConstantReward.deploy(nodesGovernance.address);
        await nodesConstantReward.deployed();
    });

    describe("distributeRewards", function () {
        it("should revert if reward has already been distributed", async function () {
            await ethers.provider.send("evm_increaseTime", [DETECT_DURATION_TIME + 1]);
            await ethers.provider.send("evm_mine");
            await nodesGovernance.startNewValidationRound();
            {
                const VOTERS = [addr1, addr2, addr3, addr4, addr5, addr6];
                const currentRoundId = await nodesGovernance.currentRoundId();
                const verifiers = await nodesGovernance.getRoundVerifiers(currentRoundId);

                for (let k = 0; k < verifiers.length; k++) {
                    const verifier = verifiers[k];
                    const validators = await nodesGovernance.getValidatorsOfVerifier(currentRoundId, verifier);
                    const VOTERS = [addr1, addr2, addr3, addr4, addr5, addr6];
                    let voters = []
                    for (let j = 0; j < validators.length; j++)
                        for (let i = 0; i < VOTERS.length; i++) 
                            if (VOTERS[i].address == validators[j])
                                voters[j] = VOTERS[i]
                    
                    await nodesGovernance.connect(voters[0]).vote(currentRoundId, verifier, true);
                    await nodesGovernance.connect(voters[1]).vote(currentRoundId, verifier, true);
                    await nodesGovernance.connect(voters[2]).vote(currentRoundId, verifier, true);
                } 
            }

            let detectPeriodId = await nodesGovernance.currentDetectCircleId();

            await ethers.provider.send("evm_increaseTime", [DETECT_DURATION_TIME + 1]);
            await ethers.provider.send("evm_mine");
            await nodesGovernance.startNewValidationRound();

            await expect(nodesConstantReward.distributeRewards(detectPeriodId + 1, 0)).to.be.revertedWith("Invalid coins");
            await expect(nodesConstantReward.distributeRewards(detectPeriodId + 1, 120)).to.be.revertedWith("Reward settlement not continuous");

            await nodesConstantReward.distributeRewards(detectPeriodId, 120);
            await expect(nodesConstantReward.distributeRewards(detectPeriodId, 120)).to.be.revertedWith("Reward has been settlemented");
        });

        it("should correctly distribute rewards", async function () {
            await ethers.provider.send("evm_increaseTime", [DETECT_DURATION_TIME + 1]);
            await ethers.provider.send("evm_mine");
            await nodesGovernance.startNewValidationRound();
            const detectPeriodId = await nodesGovernance.currentDetectCircleId();

            for (let l = 0; l < DETECT_DURATION_TIME / ROUND_DURATION_TIME; l++)
            {
                const VOTERS = [addr1, addr2, addr3, addr4, addr5, addr6];
                const currentRoundId = await nodesGovernance.currentRoundId();
                const verifiers = await nodesGovernance.getRoundVerifiers(currentRoundId);
                for (let k = 0; k < verifiers.length; k++) {
                    const verifier = verifiers[k];
                    let validators = await nodesGovernance.getValidatorsOfVerifier(currentRoundId, verifier);
                    const VOTERS = [addr1, addr2, addr3, addr4, addr5, addr6];
                    let voters = []
                    for (let j = 0; j < validators.length; j++)
                        for (let i = 0; i < VOTERS.length; i++) 
                            if (VOTERS[i].address == validators[j])
                                voters[j] = VOTERS[i]
                    
                    await nodesGovernance.connect(voters[0]).vote(currentRoundId, verifier, true);
                    await nodesGovernance.connect(voters[1]).vote(currentRoundId, verifier, true);
                    await nodesGovernance.connect(voters[2]).vote(currentRoundId, verifier, true);
                }
                
                await ethers.provider.send("evm_increaseTime", [ROUND_DURATION_TIME + 1]);
                await ethers.provider.send("evm_mine");
                await nodesGovernance.startNewValidationRound();
            }

            await ethers.provider.send("evm_increaseTime", [ROUND_DURATION_TIME + 1]);
            await ethers.provider.send("evm_mine");
            await nodesConstantReward.distributeRewards(detectPeriodId, 120);
            const settlement = await nodesConstantReward.settlements(addr2.address);
            expect(settlement.pendingReward).to.equal(20);
        });

        it("should apply penalty if failed count exceeds limit", async function () {
            await ethers.provider.send("evm_increaseTime", [DETECT_DURATION_TIME + 1]);
            await ethers.provider.send("evm_mine");
            await nodesGovernance.startNewValidationRound();
            const detectPeriodId = await nodesGovernance.currentDetectCircleId();

            for (let l = 0; l < DETECT_DURATION_TIME / ROUND_DURATION_TIME; l++)
            {
                const VOTERS = [addr1, addr2, addr3, addr4, addr5, addr6];
                const currentRoundId = await nodesGovernance.currentRoundId();
                const verifiers = await nodesGovernance.getRoundVerifiers(currentRoundId);
                for (let k = 0; k < verifiers.length; k++) {
                    const verifier = verifiers[k];
                    let validators = await nodesGovernance.getValidatorsOfVerifier(currentRoundId, verifier);
                    const VOTERS = [addr1, addr2, addr3, addr4, addr5, addr6];
                    let voters = []
                    for (let j = 0; j < validators.length; j++)
                        for (let i = 0; i < VOTERS.length; i++) 
                            if (VOTERS[i].address == validators[j])
                                voters[j] = VOTERS[i]
                    if (verifier != addr2.address) {
                        await nodesGovernance.connect(voters[0]).vote(currentRoundId, verifier, true);
                        await nodesGovernance.connect(voters[1]).vote(currentRoundId, verifier, true);
                        await nodesGovernance.connect(voters[2]).vote(currentRoundId, verifier, true);
                    } else {
                        await nodesGovernance.connect(voters[0]).vote(currentRoundId, verifier, false);
                        await nodesGovernance.connect(voters[1]).vote(currentRoundId, verifier, false);
                        await nodesGovernance.connect(voters[2]).vote(currentRoundId, verifier, false);
                    }
                }
                
                await ethers.provider.send("evm_increaseTime", [ROUND_DURATION_TIME + 1]);
                await ethers.provider.send("evm_mine");
                await nodesGovernance.startNewValidationRound();
            }

            await ethers.provider.send("evm_increaseTime", [ROUND_DURATION_TIME + 1]);
            await ethers.provider.send("evm_mine");
            await nodesConstantReward.distributeRewards(detectPeriodId, 120);
            // const result = await nodesGovernance.stateOfNodes(detectPeriodId, addr2.address)
            // // console.log(result)
            const settlement = await nodesConstantReward.settlements(addr2.address);
            expect(settlement.pendingReward).to.equal(0);
        });
    });
});