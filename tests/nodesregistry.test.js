const { expect } = require("chai");
const { ethers } = require("hardhat");
const { AddressZero } = require("ethers").constants

describe("NodesRegistry", function () {
    let NodesRegistry;
    let nodesRegistry;
    let owner;
    let addr1;
    let addr2;

    beforeEach(async function () {
        [owner, addr1, addr2, addr3] = await ethers.getSigners();

        const identifiers = [addr1.address, addr2.address];
        const wallets = [addr1.address, addr2.address];

        NodesRegistry = await ethers.getContractFactory("NodesRegistry");
        await expect(NodesRegistry.deploy(identifiers, wallets, AddressZero)).to.be.revertedWith("Invalid owner");
        nodesRegistry = await NodesRegistry.deploy(identifiers, wallets, owner.address);
        await nodesRegistry.deployed();
    });

    describe("owner", function () {
        it("not owner register node", async function () {
            await expect(nodesRegistry.connect(addr3).registerNode(addr3.address, addr3.address)).to.be.revertedWith("AccessControl:")
        });

        it("not owner deregister node", async function () {
            await expect(nodesRegistry.deregisterNode(AddressZero))
                .to.be.revertedWith("Invalid identify");
            await expect(nodesRegistry.connect(addr3).deregisterNode(addr1.address))
                .to.be.revertedWith("AccessControl:");
        });
    });


    describe("Node registration", function () {
        it("Should register a new node", async function () {
            await nodesRegistry.registerNode(addr3.address, addr3.address);
            await expect(nodesRegistry.registerNode(addr3.address, AddressZero)).to.be.revertedWith("Invalid wallet or identifier");
            const node = await nodesRegistry.get(addr3.address);
            expect(node.identifier).to.equal(addr3.address);
            expect(node.wallet).to.equal(addr3.address);
            expect(node.active).to.be.true;
        });

        it("Should not register a node with a zero address wallet", async function () {
            await expect(nodesRegistry.registerNode(addr1.address, ethers.constants.AddressZero))
                .to.be.revertedWith("Invalid wallet");
        });

        it("Should revert when trying to register an existing node with a different wallet", async function () {
            await expect(nodesRegistry.registerNode(addr1.address, addr2.address))
                .to.be.revertedWith("Identifier exist");
        });

        it("Should activate an existing node if registered again with the same wallet", async function () {
            await nodesRegistry.deregisterNode(addr1.address);
            await nodesRegistry.registerNode(addr1.address, addr1.address);
            const node = await nodesRegistry.get(addr1.address);
            expect(node.active).to.be.true;
        });
    });

    describe("Node deregistration", function () {
        it("Should deregister an active node", async function () {
            await nodesRegistry.deregisterNode(addr1.address);
            const node = await nodesRegistry.get(addr1.address);
            expect(node.active).to.be.false;
        });

        it("Should revert when trying to deregister a non-existent node", async function () {
            await expect(nodesRegistry.deregisterNode(addr3.address))
                .to.be.revertedWith("Identifier not exist");
        });

        it("Should revert when trying to deregister an already deregistered node", async function () {
            await nodesRegistry.deregisterNode(addr1.address);
            await expect(nodesRegistry.deregisterNode(addr1.address))
                .to.be.revertedWith("Identifier has been deregistered");
        });
    });

    describe("Node retrieval", function () {
        it("Should retrieve the correct node details", async function () {
            const node = await nodesRegistry.get(addr1.address);
            expect(node.identifier).to.equal(addr1.address);
            expect(node.wallet).to.equal(addr1.address);
            expect(node.active).to.be.true;
        });

        it("Should return the correct length of registered nodes", async function () {
            expect(await nodesRegistry.length()).to.equal(2);
            await nodesRegistry.deregisterNode(addr1.address);
            expect(await nodesRegistry.length()).to.equal(2); // Length should remain the same even if deregistered
        });
    });
});