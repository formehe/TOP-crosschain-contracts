const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("AIToken Contract", function () {
    let AIToken;
    let aIToken;
    let owner;
    let admin;
    let user;

    const initialSupply = ethers.utils.parseUnits("1000", 18); // 初始供应量
    const exchangeRate = 100; // 兑换比例

    beforeEach(async function () {
        [owner, admin, user, controller] = await ethers.getSigners();
        AIToken = await ethers.getContractFactory("AIToken");
        aIToken = await AIToken.deploy(initialSupply, exchangeRate, owner.address);
        await aIToken.deployed();
        await aIToken.connect(owner).grantRole("0xa8a2e59f1084c6f79901039dbbd994963a70b36ee6aff99b7e17b2ef4f0e395c", admin.address);
    });

    describe("Deployment", function () {
        it("should assign initial supply to the owner", async function () {
            const ownerBalance = await aIToken.balanceOf(owner.address);
            expect(ownerBalance).to.equal(initialSupply);
        });

        it("should set the correct exchange rate", async function () {
            expect(await aIToken.exchangeRate()).to.equal(exchangeRate);
        });

        it("should not allow zero address as owner", async function () {
            const AITokenWithZeroOwner = await ethers.getContractFactory("AIToken");
            await expect(AITokenWithZeroOwner.deploy(initialSupply, exchangeRate, ethers.constants.AddressZero)).to.be.revertedWith("Invalid owner");
        });
    });

    describe("Minting", function () {
        beforeEach(async function () {
            // Grant CONTROLLED_ROLE to the admin
            await aIToken.connect(admin).grantRole("0x8f2157482fb2324126e5fbc513e0fe919cfa878b0f89204823a63a35805d67de", admin.address);
        });

        it("should mint tokens correctly when called by CONTROLLED_ROLE", async function () {
            const fiatAmount = 10; // 10 法币
            // const expectedTokenAmount = fiatAmount * exchangeRate; // 预期铸造的 Token 数量

            await aIToken.connect(admin).mint(fiatAmount);
            const adminBalance = await aIToken.balanceOf(admin.address);
            expect(adminBalance).to.equal(fiatAmount);
        });

        it("should emit TokensMinted event on successful minting", async function () {
            const fiatAmount = 10;
            await expect(aIToken.connect(admin).mint(fiatAmount))
                .to.emit(aIToken, "TokensMinted")
                .withArgs(admin.address, fiatAmount);
        });

        it("should not allow non-CONTROLLED_ROLE to mint", async function () {
            const fiatAmount = 10;
            await expect(aIToken.connect(user).mint(fiatAmount)).to.be.reverted;
        });
    });

    describe("Burning", function () {
        beforeEach(async function () {
            await aIToken.connect(admin).grantRole("0x8f2157482fb2324126e5fbc513e0fe919cfa878b0f89204823a63a35805d67de", controller.address);
            await aIToken.connect(controller).mint(10); // 铸造一些 Token
        });

        it("should burn tokens correctly", async function () {
            const amountToBurn = 10;
            await aIToken.connect(controller).burn(amountToBurn);
            const adminBalance = await aIToken.balanceOf(controller.address);
            expect(adminBalance).to.equal(0);
        });

        it("should emit TokensBurned event on successful burning", async function () {
            const amountToBurn = 10;
            await expect(aIToken.connect(controller).burn(amountToBurn))
                .to.emit(aIToken, "TokensBurned")
                .withArgs(controller.address, amountToBurn);
        });

        it("should not allow burning more than balance", async function () {
            const amountToBurn = 20; // 超过余额
            await expect(aIToken.connect(controller).burn(amountToBurn)).to.be.revertedWith("Insufficient balance");
        });
    });

    describe("Setting Exchange Rate", function () {
        beforeEach(async function () {
            await aIToken.connect(admin).grantRole("0x8f2157482fb2324126e5fbc513e0fe919cfa878b0f89204823a63a35805d67de", admin.address);
        });

        it("should set a new exchange rate", async function () {
            const newRate = 200;
            await aIToken.connect(admin).setExchangeRate(newRate);
            expect(await aIToken.exchangeRate()).to.equal(newRate);
        });

        it("should not allow non-CONTROLLED_ROLE to set exchange rate", async function () {
            const newRate = 200;
            await expect(aIToken.connect(user).setExchangeRate(newRate)).to.be.reverted;
        });
    });
});