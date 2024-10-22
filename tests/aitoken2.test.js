const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("AIToken2", function () {
    let AIToken;
    let aiToken;
    let owner;
    let addr1;
    let addr2;

    const initialSupply = ethers.utils.parseEther("1000"); // 1000 AIT
    const exchangeRate = 100; // 1 fiat = 100 AIT
    const rewardLockPeriod = 60; // 60 seconds

    beforeEach(async function () {
        [owner, addr1, addr2] = await ethers.getSigners();

        AIToken = await ethers.getContractFactory("AIToken2");
        aiToken = await AIToken.deploy(initialSupply, exchangeRate, rewardLockPeriod);
        await aiToken.deployed();
    });

    describe("Deployment", function () {
        it("Should set the correct initial supply", async function () {
            const ownerBalance = await aiToken.balanceOf(owner.address);
            expect(ownerBalance).to.equal(initialSupply);
        });

        it("Should set the correct exchange rate and reward lock period", async function () {
            expect(await aiToken.exchangeRate()).to.equal(exchangeRate);
            expect(await aiToken.rewardLockPeriod()).to.equal(rewardLockPeriod);
        });
    });

    describe("Token minting", function () {
        it("Should mint tokens correctly", async function () {
            await aiToken.mintTokens(1); // Mint tokens for 1 fiat
            const ownerBalance = await aiToken.balanceOf(owner.address);
            expect(ownerBalance).to.equal(initialSupply.add(exchangeRate)); // 100 AIT minted
        });

        it("Should only allow the owner to mint tokens", async function () {
            await expect(aiToken.connect(addr1).mintTokens(1)).to.be.revertedWith("Ownable: caller is not the owner");
        });
    });

    describe("Token burning", function () {
        it("Should burn tokens correctly", async function () {
            await aiToken.burnTokens(exchangeRate); // Burn 100 AIT
            const ownerBalance = await aiToken.balanceOf(owner.address);
            expect(ownerBalance).to.equal(initialSupply.sub(exchangeRate));
        });

        it("Should revert if the user has insufficient balance", async function () {
            await aiToken.burnTokens(initialSupply); // Try to burn more than the balance
            await expect(aiToken.burnTokens(initialSupply.add(1))).to.be.revertedWith("Insufficient balance");
        });
    });

    describe("Exchange rate", function () {
        it("Should set the new exchange rate correctly", async function () {
            await aiToken.setExchangeRate(200); // Change exchange rate
            expect(await aiToken.exchangeRate()).to.equal(200);
        });

        it("Should only allow the owner to set the exchange rate", async function () {
            await expect(aiToken.connect(addr1).setExchangeRate(200)).to.be.revertedWith("Ownable: caller is not the owner");
        });
    });

    describe("Online rewards", function () {
        beforeEach(async function () {
            // Distributing rewards to addr1
            await aiToken.distributeOnlineRewards(addr1.address, ethers.utils.parseEther("50")); // 50 AIT
            await ethers.provider.send("evm_increaseTime", [rewardLockPeriod + 1]); // Fast forward time
            await ethers.provider.send("evm_mine"); // Mine a block to update time
            await aiToken.connect(addr1).claimOnlineRewards();
            await aiToken.distributeOnlineRewards(addr1.address, ethers.utils.parseEther("50")); // 50 AIT
        });

        it("Should distribute online rewards correctly", async function () {
            const miner = await aiToken.miners(addr1.address);
            expect(miner.onlineRewards).to.equal(ethers.utils.parseEther("50"));
        });

        it("Should allow a miner to claim rewards after the lock period", async function () {

            await ethers.provider.send("evm_increaseTime", [rewardLockPeriod + 1]); // Fast forward time
            await ethers.provider.send("evm_mine"); // Mine a block to update time

            const miner1 = await aiToken.miners(addr1.address);
            await aiToken.connect(addr1).claimOnlineRewards();
            const miner = await aiToken.miners(addr1.address);
            expect(miner.onlineRewards).to.equal(0);
            expect(Number(miner.lastClaimedCycle)).to.greaterThan(Number(miner1.lastClaimedCycle)); // Assuming initial lastClaimedCycle was 0
        });

        it("Should revert if rewards are still locked", async function () {
            await expect(aiToken.connect(addr1).claimOnlineRewards()).to.be.revertedWith("Rewards are still locked");
        });

        it("Should revert if there are no rewards to claim", async function () {
            await ethers.provider.send("evm_increaseTime", [rewardLockPeriod + 1]); // Fast forward time
            await ethers.provider.send("evm_mine"); // Mine a block to update time

            await expect(aiToken.claimOnlineRewards()).to.be.revertedWith("No rewards to claim");
        });
    });
});