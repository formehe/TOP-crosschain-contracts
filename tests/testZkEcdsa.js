const chai = require("chai");
const expect = chai.expect;
const abi = require('web3-eth-abi');
const { AddressZero } = require("ethers").constants
const hre = require("hardhat");
const { ethers, upgrades } = require("hardhat");
const { generateProof } = require("./helpers/zkEcdsaPoseidon")
const { keccak256 } = require('@ethersproject/keccak256')
const { poseidonContract } = require("circomlibjs")

describe("ZKEntry", function () {
  beforeEach(async function () {
      //准备必要账户
      [deployer, admin, miner, user, user1, ,user2, user3, redeemaccount] = await hre.ethers.getSigners()

      console.log("deployer account:", deployer.address)
      console.log("admin account:", admin.address)
      console.log("team account:", miner.address)
      console.log("user account:", user.address)
      console.log("user1 account:", user1.address)
      console.log("user2 account:", user2.address)
      console.log("user3 account:", user3.address)
      console.log("redeemaccount account:", redeemaccount.address)

      oriEcdsaCon = await ethers.getContractFactory("VerifierEcdsa", deployer)
      oriEcdsa = await oriEcdsaCon.deploy()
      await oriEcdsa.deployed()
      console.log("+++++++++++++VerifierEcdsa+++++++++++++++ ", oriEcdsa.address)

      verifierEcdsaCon = await ethers.getContractFactory("VerifierEcdsaWrapper", deployer)
      verifierEcdsa = await verifierEcdsaCon.deploy()
      await verifierEcdsa.deployed()
      console.log("+++++++++++++verifierEcdsaWrapper+++++++++++++++ ", verifierEcdsa.address)

      const abi = poseidonContract.generateABI(1)
      const code = poseidonContract.createCode(1)
      poseidon1 = new ethers.ContractFactory(abi, code, deployer);
      poseidon1 = await poseidon1.deploy()
      await poseidon1.deployed()
      console.log("+++++++++++++poseidon1+++++++++++++++ ", poseidon1.address) 

      credentialEcdsaCon = await ethers.getContractFactory("CredentialEcdsaValidator", {
          signer: deployer,
          libraries: {
            PoseidonUnit1L: poseidon1.address
          }
        }
      )

      credentialEcdsa = await credentialEcdsaCon.deploy()
      await credentialEcdsa.deployed()
      await credentialEcdsa.initialize(verifierEcdsa.address)
      console.log("+++++++++++++credentialEcdsaValidator+++++++++++++++ ", credentialEcdsa.address)

      shadowWalletCon = await ethers.getContractFactory("ShadowWallet", deployer)
      shadowWallet = await shadowWalletCon.deploy()
      await shadowWallet.deployed()
      console.log("+++++++++++++shadowWallet+++++++++++++++ ", shadowWallet.address)

      shadowWalletFactoryCon = await ethers.getContractFactory("ShadowWalletFactory", deployer)
      shadowWalletFactory = await shadowWalletFactoryCon.deploy()
      await shadowWalletFactory.deployed()
      console.log("+++++++++++++shadowWalletFactory+++++++++++++++ ", shadowWalletFactory.address)
      
      await expect(shadowWalletFactory.initialize(AddressZero, credentialEcdsa.address)).to.be.revertedWith("invalid template")
      await expect(shadowWalletFactory.initialize(shadowWallet.address, AddressZero)).to.be.revertedWith("invalid validator")
      await shadowWalletFactory.initialize(shadowWallet.address, credentialEcdsa.address)
      
      zkPVerifierCon = await ethers.getContractFactory("ZkEntry", deployer)
      zkPVerifier = await zkPVerifierCon.deploy()
      await zkPVerifier.deployed()
      console.log("+++++++++++++ZkEntry+++++++++++++++ ", zkPVerifier.address)
      await zkPVerifier.initialize(shadowWalletFactory.address)

      erc20TokenCon = await ethers.getContractFactory("ERC20TokenSample", deployer)
      erc20Token = await erc20TokenCon.deploy()
      await erc20Token.deployed()
      console.log("+++++++++++++erc20Token+++++++++++++++ ", erc20Token.address)
  })

  it('ZKEntry', async () => {
    const privKey = BigInt(
      "0xf5b552f608f5b552f608f5b552f6082ff5b552f608f5b552f608f5b552f6082f"
    );

    const privKey1 = BigInt(
      "0xf5b552f609f5b552f608f5b552f6082ff5b552f608f5b552f608f5b552f6082f"
    );
    let transferCalldata = erc20Token.interface.encodeFunctionData('transfer', [user.address, 128])
    let msg = abi.encodeParameters(['uint256', 'uint256', 'address', 'bytes'], [122, 0, erc20Token.address, transferCalldata])
    let msgHash = keccak256(msg)
    var {publicSignals, proof} = await generateProof(msgHash, privKey)
    console.log("====proof and signal====")
    console.log(proof)
    console.log(publicSignals)

    await expect(shadowWallet.initialize(
      AddressZero,
      AddressZero,
      122,
      publicSignals.map((p)=>p.toString()), 
      proof.pi_a.slice(0, 2), 
      [
        [proof.pi_b[0][1].toString(), proof.pi_b[0][0].toString()],
        [proof.pi_b[1][1].toString(), proof.pi_b[1][0].toString()]
      ],
      proof.pi_c.slice(0, 2), 
      msg
    )).to.be.revertedWith("invalid caller")

    await expect(shadowWallet.initialize(
      shadowWalletFactory.address,
      AddressZero,
      122,
      publicSignals.map((p)=>p.toString()), 
      proof.pi_a.slice(0, 2), 
      [
        [proof.pi_b[0][1].toString(), proof.pi_b[0][0].toString()],
        [proof.pi_b[1][1].toString(), proof.pi_b[1][0].toString()]
      ],
      proof.pi_c.slice(0, 2), 
      msg
    )).to.be.revertedWith("invalid factory")

    await shadowWallet.initialize(
      zkPVerifier.address,
      shadowWalletFactory.address,
      122,
      publicSignals.map((p)=>p.toString()), 
      proof.pi_a.slice(0, 2), 
      [
        [proof.pi_b[0][1].toString(), proof.pi_b[0][0].toString()],
        [proof.pi_b[1][1].toString(), proof.pi_b[1][0].toString()]
      ],
      proof.pi_c.slice(0, 2), 
      msg
    )

    transferCalldata = erc20Token.interface.encodeFunctionData('transfer', [user.address, 128])
    msg = abi.encodeParameters(['uint256', 'uint256', 'address', 'bytes'], [130, 0, erc20Token.address, transferCalldata])
    msgHash = keccak256(msg)
    var {publicSignals, proof} = await generateProof(msgHash, privKey)

    await zkPVerifier.newWallet(
      130,
      publicSignals.map((p)=>p.toString()), 
      proof.pi_a.slice(0, 2), 
      [
        [proof.pi_b[0][1].toString(), proof.pi_b[0][0].toString()],
        [proof.pi_b[1][1].toString(), proof.pi_b[1][0].toString()]
      ],
      proof.pi_c.slice(0, 2), 
      msg
    )
    
    transferCalldata = erc20Token.interface.encodeFunctionData('transfer', [user.address, 128])
    msg = abi.encodeParameters(['uint256', 'uint256', 'address', 'bytes'], [123, 0, erc20Token.address, transferCalldata])
    msgHash = keccak256(msg)
    var {publicSignals, proof} = await generateProof(msgHash, privKey)

    tx = await zkPVerifier.newWallet(
      123,
      publicSignals.map((p)=>p.toString()), 
      proof.pi_a.slice(0, 2), 
      [
        [proof.pi_b[0][1].toString(), proof.pi_b[0][0].toString()],
        [proof.pi_b[1][1].toString(), proof.pi_b[1][0].toString()]
      ],
      proof.pi_c.slice(0, 2), 
      msg
    )
        
    await expect(zkPVerifier.newWallet(
      123,
      publicSignals.map((p)=>p.toString()), 
      proof.pi_a.slice(0, 2), 
      [
        [proof.pi_b[0][1].toString(), proof.pi_b[0][0].toString()],
        [proof.pi_b[1][1].toString(), proof.pi_b[1][0].toString()]
      ],
      proof.pi_c.slice(0, 2), 
      msg
    )).to.be.revertedWith("id already exist")

    const rc = await tx.wait()
    const event = await rc.events.find(event=>event.event === "Shadow_Wallet_Created")
    const result = abi.decodeParameters(['uint256', 'address'], event.data)
    await erc20Token.connect(deployer).transfer(result[1], 10000000)
    
    //=======execute======================
    transferCalldata = erc20Token.interface.encodeFunctionData('transfer', [user.address, 128])
    msg = abi.encodeParameters(['uint256', 'uint256', 'address', 'bytes'], [123, 0, erc20Token.address, transferCalldata])
    msgHash = keccak256(msg)
    var {publicSignals, proof} = await generateProof(msgHash, privKey)

    await expect(zkPVerifier.execute(
      123,
      publicSignals.map((p)=>p.toString()), 
      proof.pi_a.slice(0, 2), 
      [
        [proof.pi_b[0][1].toString(), proof.pi_b[0][0].toString()],
        [proof.pi_b[1][1].toString(), proof.pi_b[1][0].toString()]
      ],
      proof.pi_c.slice(0, 2), 
      msg
    )).to.be.revertedWith("nonce uncorrect")

    transferCalldata = erc20Token.interface.encodeFunctionData('transfer', [user.address, 128])
    msg = abi.encodeParameters(['uint256', 'uint256', 'address', 'bytes'], [124, 0, erc20Token.address, transferCalldata])
    msgHash = keccak256(msg)
    var {publicSignals, proof} = await generateProof(msgHash, privKey)

    await expect(zkPVerifier.execute(
      123,
      publicSignals.map((p)=>p.toString()), 
      proof.pi_a.slice(0, 2), 
      [
        [proof.pi_b[0][1].toString(), proof.pi_b[0][0].toString()],
        [proof.pi_b[1][1].toString(), proof.pi_b[1][0].toString()]
      ],
      proof.pi_c.slice(0, 2), 
      msg
    )).to.be.revertedWith("invalid user")

    await expect(zkPVerifier.execute(
      124,
      publicSignals.map((p)=>p.toString()), 
      proof.pi_a.slice(0, 2), 
      [
        [proof.pi_b[0][1].toString(), proof.pi_b[0][0].toString()],
        [proof.pi_b[1][1].toString(), proof.pi_b[1][0].toString()]
      ],
      proof.pi_c.slice(0, 2), 
      msg
    )).to.be.revertedWith("id not exist")

    transferCalldata = erc20Token.interface.encodeFunctionData('transfer', [user.address, 128])
    msg = abi.encodeParameters(['uint256', 'uint256', 'address', 'bytes'], [123, 1, erc20Token.address, transferCalldata])
    msgHash = keccak256(msg)
    var {publicSignals, proof} = await generateProof(msgHash, privKey)

    await zkPVerifier.execute(
      123,
      publicSignals.map((p)=>p.toString()), 
      proof.pi_a.slice(0, 2), 
      [
        [proof.pi_b[0][1].toString(), proof.pi_b[0][0].toString()],
        [proof.pi_b[1][1].toString(), proof.pi_b[1][0].toString()]
      ],
      proof.pi_c.slice(0, 2), 
      msg
    )

    await expect(zkPVerifier.execute(
      123,
      publicSignals.map((p)=>p.toString()), 
      proof.pi_a.slice(0, 2), 
      [
        [proof.pi_b[0][1].toString(), proof.pi_b[0][0].toString()],
        [proof.pi_b[1][1].toString(), proof.pi_b[1][0].toString()]
      ],
      proof.pi_c.slice(0, 2), 
      msg
    )).to.be.revertedWith("nonce uncorrect")

    transferCalldata = erc20Token.interface.encodeFunctionData('transfer', [user.address, 128])
    msg = abi.encodeParameters(['uint256', 'uint256', 'address', 'bytes'], [123, 2, erc20Token.address, transferCalldata])
    msgHash = keccak256(msg)
    var {publicSignals, proof} = await generateProof(msgHash, privKey1)

    await expect(zkPVerifier.execute(
      123,
      publicSignals.map((p)=>p.toString()), 
      proof.pi_a.slice(0, 2), 
      [
        [proof.pi_b[0][1].toString(), proof.pi_b[0][0].toString()],
        [proof.pi_b[1][1].toString(), proof.pi_b[1][0].toString()]
      ],
      proof.pi_c.slice(0, 2), 
      msg
    )).to.be.revertedWith("invalid material")

    //======change material=======
    transferCalldata = erc20Token.interface.encodeFunctionData('transfer', [user.address, 128])
    msg = abi.encodeParameters(['uint256', 'uint256', 'address', 'bytes'], [123, 2, erc20Token.address, transferCalldata])
    msgHash = keccak256(msg)
    var {publicSignals, proof} = await generateProof(msgHash, privKey1)
    let publicSignals1 = publicSignals
    let tempPublicSignal
    let proof1 = proof
    var {publicSignals, proof} = await generateProof(msgHash, privKey)
    
    tempPublicSignal = publicSignals1[0]
    publicSignals1[0] = 17

    await expect(zkPVerifier.changeMaterial(
      123,
      publicSignals.map((p)=>p.toString()), 
      proof.pi_a.slice(0, 2), 
      [
        [proof.pi_b[0][1].toString(), proof.pi_b[0][0].toString()],
        [proof.pi_b[1][1].toString(), proof.pi_b[1][0].toString()]
      ],
      proof.pi_c.slice(0, 2), 
      publicSignals1.map((p)=>p.toString()), 
      proof1.pi_a.slice(0, 2), 
      [
        [proof1.pi_b[0][1].toString(), proof1.pi_b[0][0].toString()],
        [proof1.pi_b[1][1].toString(), proof1.pi_b[1][0].toString()]
      ],
      proof1.pi_c.slice(0, 2), 
      msg
    )).to.be.revertedWith("proof is not valid")

    publicSignals1[0] = tempPublicSignal
    tempPublicSignal = publicSignals1[1]
    publicSignals1[1] = 17

    await expect(zkPVerifier.changeMaterial(
      123,
      publicSignals.map((p)=>p.toString()), 
      proof.pi_a.slice(0, 2), 
      [
        [proof.pi_b[0][1].toString(), proof.pi_b[0][0].toString()],
        [proof.pi_b[1][1].toString(), proof.pi_b[1][0].toString()]
      ],
      proof.pi_c.slice(0, 2), 
      publicSignals1.map((p)=>p.toString()), 
      proof1.pi_a.slice(0, 2), 
      [
        [proof1.pi_b[0][1].toString(), proof1.pi_b[0][0].toString()],
        [proof1.pi_b[1][1].toString(), proof1.pi_b[1][0].toString()]
      ],
      proof1.pi_c.slice(0, 2), 
      msg
    )).to.be.revertedWith("proof is not valid")

    publicSignals1[1] = tempPublicSignal
    tempPublicSignal = publicSignals1[2]
    publicSignals1[2] = 17

    await expect(zkPVerifier.changeMaterial(
      123,
      publicSignals.map((p)=>p.toString()), 
      proof.pi_a.slice(0, 2), 
      [
        [proof.pi_b[0][1].toString(), proof.pi_b[0][0].toString()],
        [proof.pi_b[1][1].toString(), proof.pi_b[1][0].toString()]
      ],
      proof.pi_c.slice(0, 2), 
      publicSignals1.map((p)=>p.toString()), 
      proof1.pi_a.slice(0, 2), 
      [
        [proof1.pi_b[0][1].toString(), proof1.pi_b[0][0].toString()],
        [proof1.pi_b[1][1].toString(), proof1.pi_b[1][0].toString()]
      ],
      proof1.pi_c.slice(0, 2), 
      msg
    )).to.be.revertedWith("invalid hash")

    publicSignals1[2] = tempPublicSignal
    await expect(zkPVerifier.changeMaterial(
      123,
      publicSignals1.map((p)=>p.toString()), 
      proof1.pi_a.slice(0, 2), 
      [
        [proof1.pi_b[0][1].toString(), proof1.pi_b[0][0].toString()],
        [proof1.pi_b[1][1].toString(), proof1.pi_b[1][0].toString()]
      ],
      proof1.pi_c.slice(0, 2), 
      publicSignals1.map((p)=>p.toString()), 
      proof1.pi_a.slice(0, 2), 
      [
        [proof1.pi_b[0][1].toString(), proof1.pi_b[0][0].toString()],
        [proof1.pi_b[1][1].toString(), proof1.pi_b[1][0].toString()]
      ],
      proof1.pi_c.slice(0, 2), 
      msg
    )).to.be.revertedWith("invalid material")

    await zkPVerifier.changeMaterial(
      123,
      publicSignals.map((p)=>p.toString()), 
      proof.pi_a.slice(0, 2), 
      [
        [proof.pi_b[0][1].toString(), proof.pi_b[0][0].toString()],
        [proof.pi_b[1][1].toString(), proof.pi_b[1][0].toString()]
      ],
      proof.pi_c.slice(0, 2), 
      publicSignals1.map((p)=>p.toString()), 
      proof1.pi_a.slice(0, 2), 
      [
        [proof1.pi_b[0][1].toString(), proof1.pi_b[0][0].toString()],
        [proof1.pi_b[1][1].toString(), proof1.pi_b[1][0].toString()]
      ],
      proof1.pi_c.slice(0, 2), 
      msg
    )
  })
})