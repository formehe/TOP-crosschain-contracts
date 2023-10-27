const chai = require("chai");
const expect = chai.expect;
const Web3 = require('web3');

var utils = require('ethers').utils;
const { AddressZero } = require("ethers").constants
const { BigNumber } = require('ethers')

const BN = require('bn.js');
chai.use(require('chai-bn')(BN));

const hre = require("hardhat");
const { ethers, upgrades } = require("hardhat");


describe("Rooms", function () {
    beforeEach(async function () {
        [deployer, admin, miner, user, user1, ,user2, user3, redeemaccount] = await hre.ethers.getSigners()
        owner = deployer
        console.log("deployer account:", deployer.address)
        console.log("owner account:", owner.address)
        console.log("admin account:", admin.address)
        console.log("team account:", miner.address)
        console.log("user account:", user.address)
        console.log("user1 account:", user1.address)
        console.log("user2 account:", user2.address)
        console.log("user3 account:", user3.address)
        console.log("redeemaccount account:", redeemaccount.address)

        shareCon = await ethers.getContractFactory("Share", deployer)
        shareToken = await shareCon.deploy()
        await shareToken.deployed()
        console.log("+++++++++++++Share+++++++++++++++ ", shareToken.address)

        await expect(shareToken.initialize(AddressZero, 100)).to.be.revertedWith("Invalid owner")
        await shareToken.initialize(admin.address, 100)

        roomsCon = await ethers.getContractFactory("Rooms", deployer)
        await expect(roomsCon.deploy("test room", "test room", shareToken.address, AddressZero)).to.be.revertedWith("Invalid owner")
        await expect(roomsCon.deploy("test room", "test room", AddressZero, owner.address)).to.be.revertedWith("Invalid share token address")
        roomsNft = await roomsCon.deploy("", "", shareToken.address, owner.address)
        await roomsNft.deployed()
        console.log("+++++++++++++Rooms+++++++++++++++ ", roomsNft.address)
        roomsNft1 = await roomsCon.deploy("test room", "test room", shareToken.address, user1.address)
        await roomsNft1.deployed()
    })

    it('Rooms', async () => {
        await expect(roomsNft.connect(user3).mint(user.address, user1.address, 100, 100)).to.be.revertedWith("No permit")
        await expect(roomsNft.mint(AddressZero, user1.address, 100, 100)).to.be.revertedWith("Invalid room owner or share owner")
        await expect(roomsNft.mint(user.address, AddressZero, 100, 100)).to.be.revertedWith("Invalid room owner or share owner")
        await roomsNft.mint(user.address, user1.address, 100000, 100)
        await expect(roomsNft.mint(user.address, user1.address, 100000, 100)).to.be.revertedWith("already minted")
        
        for ( i = 1 ; i < 1000; i++) {
            await roomsNft.mint(user.address, user1.address, i, 100)
        }

        for ( i = 1 ; i < 1000; i++) {
            await roomsNft1.connect(user1).mint(user.address, user1.address, i, 100)
        }
    })
})