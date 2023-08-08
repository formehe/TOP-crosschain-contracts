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
        const rewardDistributionCon = await ethers.getContractFactory("RewardDistribution", admin)
        rewardDistribution = await rewardDistributionCon.deploy()
        await rewardDistribution.deployed()
        console.log("+++++++++++++RewardDistribution+++++++++++++++ ", rewardDistribution.address)

        // const rewardDistributionProxy = await upgrades.deployProxy(rewardDistributionCon, {kind:'uups'})
        // await rewardDistributionProxy.waitForDeployment()
        // console.log("=================")
        // rewardDistributionProxyCon = await ethers.getContractFactory("ERC1967Proxy", admin)
        // rewardDistributionProxy = await rewardDistributionProxyCon.deploy(rewardDistribution.address, '0x')
        // await rewardDistributionProxy.deployed()
        // console.log("+++++++++++++ERC1967Proxy+++++++++++++++ ", rewardDistributionProxy.address)
        
        //deploy ERC20
        rewardCon = await ethers.getContractFactory("Reward", admin)
        reward = await rewardCon.deploy("Reward", "Reward", 10000000000000, rewardDistribution.address)
        await reward.deployed()
        console.log("+++++++++++++Reward+++++++++++++++ ", reward.address)

        await rewardDistribution.initialize(reward.address, miner.address, owner.address)
        await rewardDistribution.connect(admin).adminPause(0x0)
    })

    it('bind work prover', async () => {
        await expect(rewardDistribution.bindWorkProver([], [user1.address])).to.be.revertedWith('is missing role')
        await rewardDistribution.connect(miner).bindWorkProver([], [user1.address, user.address])
        await expect(rewardDistribution.connect(miner).bindWorkProver([AddressZero], [user1.address])).to.be.revertedWith('invalid address')
        await expect(rewardDistribution.connect(miner).bindWorkProver([user1.address], [AddressZero])).to.be.revertedWith('invalid address')
        await expect(rewardDistribution.connect(miner).bindWorkProver([owner.address], [user1.address])).to.be.revertedWith('address is not existed')
        await expect(rewardDistribution.connect(miner).bindWorkProver([user.address], [user1.address])).to.be.revertedWith('address is existed')
    })

    it('claim', async () => {
        await rewardDistribution.connect(miner).bindWorkProver([], [user1.address, user.address])
        await expect(rewardDistribution.claim(0, owner.address, 100)).to.be.revertedWith('not prover')
        await expect(rewardDistribution.connect(user).claim(0, AddressZero, 100)).to.be.revertedWith('invalid address')
        await expect(rewardDistribution.connect(user).claim(0, owner.address, 0)).to.be.revertedWith('work load can not be zero')
        await rewardDistribution.connect(user).claim(0, owner.address, 100)
        await expect(rewardDistribution.connect(user).claim(0, owner.address, 100)).to.be.revertedWith('proof has been used')
    })
})