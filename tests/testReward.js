const chai = require("chai");
const expect = chai.expect;

var utils = require('ethers').utils;
const { AddressZero } = require("ethers").constants

const hre = require("hardhat");
const { ethers, upgrades } = require("hardhat");

describe("Reward", function () {

    beforeEach(async function () {
        //准备必要账户
        [deployer, admin, miner, user, user1, redeemaccount] = await hre.ethers.getSigners()
        owner = deployer
        console.log("deployer account:", deployer.address)
        console.log("owner account:", owner.address)
        console.log("admin account:", admin.address)
        console.log("team account:", miner.address)
        console.log("user account:", user.address)
        console.log("redeemaccount account:", redeemaccount.address)

        //deploy RewardDistribution
        rewardDistributionCon = await ethers.getContractFactory("RewardDistribution", admin)
        rewardDistribution = await rewardDistributionCon.deploy()
        await rewardDistribution.deployed()
        console.log("+++++++++++++RewardDistribution+++++++++++++++ ", rewardDistribution.address)

        rewardDistributionProxyCon = await ethers.getContractFactory("ERC1967Proxy", admin)
        rewardDistributionProxy = await rewardDistributionProxyCon.deploy(rewardDistribution.address, '0x')
        await rewardDistributionProxy.deployed()
        console.log("+++++++++++++ERC1967Proxy+++++++++++++++ ", rewardDistributionProxy.address)

        rewardDisbutionProxied = await rewardDistributionCon.attach(rewardDistributionProxy.address)
        
        //deploy ERC20
        rewardCon = await ethers.getContractFactory("Reward", admin)
        reward = await rewardCon.deploy("Reward", "Reward", 10000000000000, rewardDisbutionProxied.address)
        await reward.deployed()
        console.log("+++++++++++++Reward+++++++++++++++ ", reward.address)

        await rewardDisbutionProxied.initialize(reward.address, miner.address, owner.address, 4)
        await rewardDisbutionProxied.connect(admin).adminPause(0x0)
    })

    it('bind work prover', async () => {
        await expect(rewardDisbutionProxied.bindWorkProver([], [user1.address])).to.be.revertedWith('is missing role')
        await rewardDisbutionProxied.connect(miner).bindWorkProver([], [user1.address, user.address])
        await expect(rewardDisbutionProxied.connect(miner).bindWorkProver([AddressZero], [user1.address])).to.be.revertedWith('invalid address')
        await expect(rewardDisbutionProxied.connect(miner).bindWorkProver([user1.address], [AddressZero])).to.be.revertedWith('invalid address')
        await expect(rewardDisbutionProxied.connect(miner).bindWorkProver([owner.address], [user1.address])).to.be.revertedWith('address is not existed')
        await expect(rewardDisbutionProxied.connect(miner).bindWorkProver([user.address], [user1.address])).to.be.revertedWith('address is existed')
    })

    it('claim', async () => {
        await rewardDisbutionProxied.connect(miner).bindWorkProver([], [user1.address, user.address])
        await expect(rewardDisbutionProxied.claim(0, owner.address, 100)).to.be.revertedWith('not prover')
        await expect(rewardDisbutionProxied.connect(user).claim(0, AddressZero, 100)).to.be.revertedWith('invalid address')
        await expect(rewardDisbutionProxied.connect(user).claim(0, owner.address, 0)).to.be.revertedWith('work load can not be zero')
        await rewardDisbutionProxied.connect(user).claim(0, owner.address, 100)
        await expect(rewardDisbutionProxied.connect(user).claim(0, owner.address, 100)).to.be.revertedWith('proof has been used')
    })

    it('upgrade', async () => {
        rewardDistribution1 = await rewardDistributionCon.deploy()
        await rewardDistribution1.deployed()
        console.log("+++++++++++++RewardDistribution+++++++++++++++ ", rewardDistribution1.address)

        await expect(rewardDisbutionProxied.upgradeTo(rewardDistribution1.address)).to.be.revertedWith('is missing role')
        await expect(rewardDistribution.connect(owner).upgradeTo(rewardDistribution1.address)).to.be.revertedWith('Function must be called through delegatecall')
        await rewardDisbutionProxied.connect(owner).upgradeTo(rewardDistribution1.address)
    })
})