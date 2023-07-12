const chai = require("chai");
const expect = chai.expect;
const abi = require('web3-eth-abi');
const { AddressZero } = require("ethers").constants
const hre = require("hardhat");
const { ethers, upgrades } = require("hardhat");
const { generateProof } = require("./helpers/zkEcdsaPoseidon")
const { keccak256 } = require('@ethersproject/keccak256')
const { poseidonContract } = require("circomlibjs")
// var EC = require('elliptic').ec;

describe("ZkEntry", function () {
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

    // oriEcdsaCon = await ethers.getContractFactory("VerifierEcdsa", deployer)
    // oriEcdsa = await oriEcdsaCon.deploy()
    // await oriEcdsa.deployed()
    // console.log("+++++++++++++VerifierEcdsa+++++++++++++++ ", oriEcdsa.address)

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

    zkEcdsaCon = await ethers.getContractFactory("ZkEcdsaValidator", {
        signer: deployer,
        libraries: {
          PoseidonUnit1L: poseidon1.address
        }
      }
    )

    zkEcdsa = await zkEcdsaCon.deploy()
    await zkEcdsa.deployed()
    await zkEcdsa.initialize(verifierEcdsa.address)
    console.log("+++++++++++++ZkEcdsaValidator+++++++++++++++ ", zkEcdsa.address)

    traditionalEcdsaCon = await ethers.getContractFactory("TraditionalEcdsaValidator")
    traditionalEcdsa = await traditionalEcdsaCon.deploy()
    await traditionalEcdsa.deployed()
    await traditionalEcdsa.initialize(AddressZero)
    console.log("+++++++++++++TraditionalEcdsaValidator+++++++++++++++ ", traditionalEcdsa.address)

    nullValidatorCon = await ethers.getContractFactory("NullValidator")
    nullValidator = await nullValidatorCon.deploy()
    await nullValidator.deployed()
    await nullValidator.initialize(AddressZero)
    console.log("+++++++++++++NullValidator+++++++++++++++ ", nullValidator.address)

    shadowWalletCon = await ethers.getContractFactory("ShadowWallet", deployer)
    shadowWallet = await shadowWalletCon.deploy()
    await shadowWallet.deployed()
    console.log("+++++++++++++shadowWallet+++++++++++++++ ", shadowWallet.address)

    shadowWalletFactoryCon = await ethers.getContractFactory("ShadowWalletFactory", deployer)
    shadowWalletFactory = await shadowWalletFactoryCon.deploy()
    await shadowWalletFactory.deployed()
    console.log("+++++++++++++shadowWalletFactory+++++++++++++++ ", shadowWalletFactory.address)
    
    await expect(shadowWalletFactory.initialize(AddressZero, zkEcdsa.address, admin.address)).to.be.revertedWith("invalid template")
    await expect(shadowWalletFactory.initialize(shadowWallet.address, AddressZero, admin.address)).to.be.revertedWith("invalid validator")
    await expect(shadowWalletFactory.initialize(shadowWallet.address, zkEcdsa.address, AddressZero)).to.be.revertedWith("invalid owner")
    await expect(shadowWalletFactory.initialize(shadowWallet.address, zkEcdsa.address, admin.address)).to.be.revertedWith("only root proof kind can be used during initailizing")
    await shadowWalletFactory.initialize(shadowWallet.address, traditionalEcdsa.address, admin.address)
    await expect(shadowWalletFactory.bindValidator(AddressZero)).to.be.revertedWith("reverted")
    await expect(shadowWalletFactory.connect(user).bindValidator(zkEcdsa.address)).to.be.revertedWith("role")
    await shadowWalletFactory.bindValidator(zkEcdsa.address)
    await shadowWalletFactory.bindValidator(nullValidator.address)
    
    zkPVerifierCon = await ethers.getContractFactory("ZkEntry", deployer)
    zkPVerifier = await zkPVerifierCon.deploy()
    await zkPVerifier.deployed()
    console.log("+++++++++++++ZkEntry+++++++++++++++ ", zkPVerifier.address)
    await expect(zkPVerifier.initialize(AddressZero, admin.address)).to.be.revertedWith("invalid factory")
    await expect(zkPVerifier.initialize(shadowWalletFactory.address, AddressZero)).to.be.revertedWith("invalid owner")
    await zkPVerifier.initialize(shadowWalletFactory.address, admin.address)
    await zkPVerifier.adminPause(0x0)

    erc20TokenCon = await ethers.getContractFactory("ERC20TokenSample", deployer)
    erc20Token = await erc20TokenCon.deploy()
    await erc20Token.deployed()
    console.log("+++++++++++++erc20Token+++++++++++++++ ", erc20Token.address)
    privKey = BigInt(
      "0xf5b552f608f5b552f608f5b552f6082ff5b552f608f5b552f608f5b552f6082f"
    );

    privKey1 = BigInt(
      "0xf5b552f609f5b552f608f5b552f6082ff5b552f608f5b552f608f5b552f6082f"
    );
    
    // ec = new EC('secp256k1');

    // key = ec.genKeyPair();
    // verifyAccount = new ethers.Wallet("0x" + key.getPrivate('hex'))

    // key1 = ec.genKeyPair();
    // verifyAccount1 = new ethers.Wallet("0x" + key1.getPrivate('hex'))
  })

  it('ZkEntry', async () => {
    let transferCalldata = erc20Token.interface.encodeFunctionData('transfer', [user.address, 128])
    let msg = abi.encodeParameters(['uint256', 'uint256', 'address', 'bytes'], [122, 0, erc20Token.address, transferCalldata])
    let msgHash = keccak256(msg)
    var {publicSignals, proof} = await generateProof(msgHash, privKey)
    console.log("====proof and signal====")
    console.log(proof)
    console.log(publicSignals)

    let encodedProof = abi.encodeParameters(['uint256[]', 'uint256[2]', 'uint256[2][2]', 'uint256[2]'], 
      [
        publicSignals.map((p)=>p.toString()), 
        proof.pi_a.slice(0, 2), 
        [
          [proof.pi_b[0][1].toString(), proof.pi_b[0][0].toString()],
          [proof.pi_b[1][1].toString(), proof.pi_b[1][0].toString()]
        ],
        proof.pi_c.slice(0, 2)
      ]
    )
    await expect(shadowWallet.initialize(
      AddressZero,
      AddressZero,
      122,
      "0x37106196440789755adfccc3a57770fecef1eaca423ca7d75f34dab84d344684",
      encodedProof,
      msg,
      user1.address
    )).to.be.revertedWith("invalid caller")

    await expect(shadowWallet.initialize(
      shadowWalletFactory.address,
      AddressZero,
      122,
      "0x37106196440789755adfccc3a57770fecef1eaca423ca7d75f34dab84d344684",
      encodedProof,
      msg,
      user1.address
    )).to.be.revertedWith("invalid factory")

    await shadowWallet.initialize(
      zkPVerifier.address,
      shadowWalletFactory.address,
      122,
      "0x37106196440789755adfccc3a57770fecef1eaca423ca7d75f34dab84d344684",
      encodedProof,
      msg,
      user1.address
    )

    transferCalldata = erc20Token.interface.encodeFunctionData('transfer', [user.address, 128])
    msg = abi.encodeParameters(['uint256', 'uint256', 'address', 'bytes'], [130, 0, erc20Token.address, transferCalldata])
    msgHash = keccak256(msg)
    signature = await user1.signMessage(ethers.utils.arrayify(msgHash))
    traditionalProof = abi.encodeParameters(['address', 'uint8', 'bytes32', 'bytes32'], 
       [user1.address, "0x"+ signature.toString(16).substr(130,2), "0x" + signature.toString(16).substr(2,64), "0x" + signature.toString(16).substr(66,64)])
    
    await expect(zkPVerifier.newWallet(
        130,
        "0x37106196440789755adfccc3a57770fecef1eaca423ca7d75f34dab84d344684",
        encodedProof,
        msg
    )).to.be.revertedWith("only root proof kind can be used during clone wallet")

    await zkPVerifier.connect(user1).newWallet(
        130,
        "0x2daa737e13c50c4bbce0e98ee727347a0b510c39a5766854fc1e579342d095aa",
        traditionalProof,
        msg
    )

    transferCalldata = erc20Token.interface.encodeFunctionData('transfer', [user.address, 128])
    msg = abi.encodeParameters(['uint256', 'uint256', 'address', 'bytes'], [123, 0, erc20Token.address, transferCalldata])
    msgHash = keccak256(msg)
    signature = await user1.signMessage(ethers.utils.arrayify(msgHash))
    traditionalProof = abi.encodeParameters(['address', 'uint8', 'bytes32', 'bytes32'], 
       [user1.address, "0x"+ signature.toString(16).substr(130,2), "0x" + signature.toString(16).substr(2,64), "0x" + signature.toString(16).substr(66,64)])

    tx = await zkPVerifier.connect(user1).newWallet(
        123,
        "0x2daa737e13c50c4bbce0e98ee727347a0b510c39a5766854fc1e579342d095aa",
        traditionalProof,
        msg
    )
    
    const rc = await tx.wait()
    const event = await rc.events.find(event=>event.event === "Shadow_Wallet_Created")
    const result = abi.decodeParameters(['uint256', 'address'], event.data)
    await erc20Token.connect(deployer).transfer(result[1], 10000000)
    await expect(zkPVerifier.newWallet(
      123,
      "0x2daa737e13c50c4bbce0e98ee727347a0b510c39a5766854fc1e579342d095aa",
      traditionalProof,
      msg
    )).to.be.revertedWith("id already exist")

    //=======grant======================
    transferCalldata = erc20Token.interface.encodeFunctionData('transfer', [user.address, 128])
    msg = abi.encodeParameters(['uint256', 'uint256', 'address', 'bytes'], [123, 0, erc20Token.address, transferCalldata])
    msgHash = keccak256(msg)
    var {publicSignals, proof} = await generateProof(msgHash, privKey)
    signature = await user1.signMessage(ethers.utils.arrayify(msgHash))
    traditionalProof = abi.encodeParameters(['address', 'uint8', 'bytes32', 'bytes32'], 
       [user1.address, "0x"+ signature.toString(16).substr(130,2), "0x" + signature.toString(16).substr(2,64), "0x" + signature.toString(16).substr(66,64)])
    encodedProof = abi.encodeParameters(['uint256[]', 'uint256[2]', 'uint256[2][2]', 'uint256[2]'], 
    [
       publicSignals.map((p)=>p.toString()), 
       proof.pi_a.slice(0, 2), 
       [
         [proof.pi_b[0][1].toString(), proof.pi_b[0][0].toString()],
         [proof.pi_b[1][1].toString(), proof.pi_b[1][0].toString()]
       ],
       proof.pi_c.slice(0, 2)
    ])

    await expect(zkPVerifier.connect(user1).grant(
      123,
      "0x2daa737e13c50c4bbce0e98ee727347a0b510c39a5766854fc1e579342d095aa",
      traditionalProof,
      "0x37106196440789755adfccc3a57770fecef1eaca423ca7d75f34dab84d344684",
      encodedProof,
      msg
    )).to.be.revertedWith("nonce uncorrect")

    await expect(zkPVerifier.grant(
      123,
      "0x37106196440789755adfccc3a57770fecef1eaca423ca7d75f34dab84d344684",
      encodedProof,
      "0x37106196440789755adfccc3a57770fecef1eaca423ca7d75f34dab84d344684",
      encodedProof,
      msg
    )).to.be.revertedWith("proof kind is equal")

    await expect(zkPVerifier.grant(
      123,
      "0x37106196440789755adfccc3a57770fecef1eaca423ca7d75f34dab84d344684",
      encodedProof,
      "0x2daa737e13c50c4bbce0e98ee727347a0b510c39a5766854fc1e579342d095aa",
      traditionalProof,
      msg
    )).to.be.revertedWith("proof kind has not been granted")

    await expect(zkPVerifier.connect(user1).grant(
      123,
      "0x2daa737e13c50c4bbce0e98ee727347a0b510c39a5766854fc1e579342d095aa",
      traditionalProof,
      "0x37806196440789755adfccc3a57770fecef1eaca423ca7d75f34dab84d344684",
      encodedProof,
      msg
    )).to.be.revertedWith("validator is not exist")

    transferCalldata = erc20Token.interface.encodeFunctionData('transfer', [user.address, 128])
    msg = abi.encodeParameters(['uint256', 'uint256', 'address', 'bytes'], [123, 1, erc20Token.address, transferCalldata])
    msgHash = keccak256(msg)
    var {publicSignals, proof} = await generateProof(msgHash, privKey)
    signature = await user1.signMessage(ethers.utils.arrayify(msgHash))
    traditionalProof = abi.encodeParameters(['address', 'uint8', 'bytes32', 'bytes32'], 
       [user1.address, "0x"+ signature.toString(16).substr(130,2), "0x" + signature.toString(16).substr(2,64), "0x" + signature.toString(16).substr(66,64)])
    encodedProof = abi.encodeParameters(['uint256[]', 'uint256[2]', 'uint256[2][2]', 'uint256[2]'], 
    [
       publicSignals.map((p)=>p.toString()), 
       proof.pi_a.slice(0, 2), 
       [
         [proof.pi_b[0][1].toString(), proof.pi_b[0][0].toString()],
         [proof.pi_b[1][1].toString(), proof.pi_b[1][0].toString()]
       ],
       proof.pi_c.slice(0, 2)
    ])
    
    await zkPVerifier.connect(user1).grant(
      123,
      "0x2daa737e13c50c4bbce0e98ee727347a0b510c39a5766854fc1e579342d095aa",
      traditionalProof,
      "0x37106196440789755adfccc3a57770fecef1eaca423ca7d75f34dab84d344684",
      encodedProof,
      msg
    )

    await expect(zkPVerifier.connect(user1).grant(
      123,
      "0x2daa737e13c50c4bbce0e98ee727347a0b510c39a5766854fc1e579342d095aa",
      traditionalProof,
      "0x37106196440789755adfccc3a57770fecef1eaca423ca7d75f34dab84d344684",
      encodedProof,
      msg
    )).to.be.revertedWith("granted proof kind has been granted")
    
    //=======execute======================
    transferCalldata = erc20Token.interface.encodeFunctionData('transfer', [user.address, 128])
    msg = abi.encodeParameters(['uint256', 'uint256', 'address', 'bytes'], [123, 0, erc20Token.address, transferCalldata])
    msgHash = keccak256(msg)
    var {publicSignals, proof} = await generateProof(msgHash, privKey)
    encodedProof = abi.encodeParameters(['uint256[]', 'uint256[2]', 'uint256[2][2]', 'uint256[2]'], 
    [
       publicSignals.map((p)=>p.toString()), 
       proof.pi_a.slice(0, 2), 
       [
         [proof.pi_b[0][1].toString(), proof.pi_b[0][0].toString()],
         [proof.pi_b[1][1].toString(), proof.pi_b[1][0].toString()]
       ],
       proof.pi_c.slice(0, 2)
    ])

    await expect(zkPVerifier.execute(
      123,
      "0x37106196440789755adfccc3a57770fecef1eaca423ca7d75f34dab84d344684",
      encodedProof, 
      msg
    )).to.be.revertedWith("nonce uncorrect")

    transferCalldata = erc20Token.interface.encodeFunctionData('transfer', [user.address, 128])
    msg = abi.encodeParameters(['uint256', 'uint256', 'address', 'bytes'], [124, 0, erc20Token.address, transferCalldata])
    msgHash = keccak256(msg)
    var {publicSignals, proof} = await generateProof(msgHash, privKey)
    encodedProof = abi.encodeParameters(['uint256[]', 'uint256[2]', 'uint256[2][2]', 'uint256[2]'], 
    [
       publicSignals.map((p)=>p.toString()), 
       proof.pi_a.slice(0, 2), 
       [
         [proof.pi_b[0][1].toString(), proof.pi_b[0][0].toString()],
         [proof.pi_b[1][1].toString(), proof.pi_b[1][0].toString()]
       ],
       proof.pi_c.slice(0, 2)
    ])
    await expect(zkPVerifier.execute(
      123,
      "0x37106196440789755adfccc3a57770fecef1eaca423ca7d75f34dab84d344684",
      encodedProof, 
      msg
    )).to.be.revertedWith("invalid user")

    await expect(zkPVerifier.execute(
      124,
      "0x37106196440789755adfccc3a57770fecef1eaca423ca7d75f34dab84d344684",
      encodedProof, 
      msg
    )).to.be.revertedWith("id not exist")

    transferCalldata = erc20Token.interface.encodeFunctionData('transfer', [user.address, 128])
    msg = abi.encodeParameters(['uint256', 'uint256', 'address', 'bytes'], [123, 2, erc20Token.address, transferCalldata])
    msgHash = keccak256(msg)
    var {publicSignals, proof} = await generateProof(msgHash, privKey)
    encodedProof = abi.encodeParameters(['uint256[]', 'uint256[2]', 'uint256[2][2]', 'uint256[2]'], 
    [
       publicSignals.map((p)=>p.toString()), 
       proof.pi_a.slice(0, 2), 
       [
         [proof.pi_b[0][1].toString(), proof.pi_b[0][0].toString()],
         [proof.pi_b[1][1].toString(), proof.pi_b[1][0].toString()]
       ],
       proof.pi_c.slice(0, 2)
    ])
    await zkPVerifier.execute(
      123,
      "0x37106196440789755adfccc3a57770fecef1eaca423ca7d75f34dab84d344684",
      encodedProof, 
      msg
    )

    await expect(zkPVerifier.execute(
      123,
      "0x37106196440789755adfccc3a57770fecef1eaca423ca7d75f34dab84d344684",
      encodedProof,  
      msg
    )).to.be.revertedWith("nonce uncorrect")

    transferCalldata = erc20Token.interface.encodeFunctionData('transfer', [user.address, 128])
    msg = abi.encodeParameters(['uint256', 'uint256', 'address', 'bytes'], [123, 3, erc20Token.address, transferCalldata])
    msgHash = keccak256(msg)
    var {publicSignals, proof} = await generateProof(msgHash, privKey1)
    encodedProof = abi.encodeParameters(['uint256[]', 'uint256[2]', 'uint256[2][2]', 'uint256[2]'], 
    [
       publicSignals.map((p)=>p.toString()), 
       proof.pi_a.slice(0, 2), 
       [
         [proof.pi_b[0][1].toString(), proof.pi_b[0][0].toString()],
         [proof.pi_b[1][1].toString(), proof.pi_b[1][0].toString()]
       ],
       proof.pi_c.slice(0, 2)
    ])
    await expect(zkPVerifier.execute(
      123,
      "0x37106196440789755adfccc3a57770fecef1eaca423ca7d75f34dab84d344684",
      encodedProof,
      msg
    )).to.be.revertedWith("invalid material")

    // //======change material=======
    transferCalldata = erc20Token.interface.encodeFunctionData('transfer', [user.address, 128])
    msg = abi.encodeParameters(['uint256', 'uint256', 'address', 'bytes'], [123, 3, erc20Token.address, transferCalldata])
    msgHash = keccak256(msg)
    var {publicSignals, proof} = await generateProof(msgHash, privKey1)
    let publicSignals1 = publicSignals
    let tempPublicSignal
    let proof1 = proof
    var {publicSignals, proof} = await generateProof(msgHash, privKey)
    
    tempPublicSignal = publicSignals1[0]
    publicSignals1[0] = 17
    encodedProof = abi.encodeParameters(['uint256[]', 'uint256[2]', 'uint256[2][2]', 'uint256[2]'], 
    [
       publicSignals.map((p)=>p.toString()), 
       proof.pi_a.slice(0, 2), 
       [
         [proof.pi_b[0][1].toString(), proof.pi_b[0][0].toString()],
         [proof.pi_b[1][1].toString(), proof.pi_b[1][0].toString()]
       ],
       proof.pi_c.slice(0, 2)
    ])

    let encodedProof1 = abi.encodeParameters(['uint256[]', 'uint256[2]', 'uint256[2][2]', 'uint256[2]'], 
    [
       publicSignals1.map((p)=>p.toString()), 
       proof1.pi_a.slice(0, 2), 
       [
         [proof1.pi_b[0][1].toString(), proof1.pi_b[0][0].toString()],
         [proof1.pi_b[1][1].toString(), proof1.pi_b[1][0].toString()]
       ],
       proof1.pi_c.slice(0, 2)
    ])
    await expect(zkPVerifier.changeMaterial(
      123,
      "0x37106196440789755adfccc3a57770fecef1eaca423ca7d75f34dab84d344684",
      encodedProof,
      encodedProof1,
      msg
    )).to.be.revertedWith("proof is not valid")

    publicSignals1[0] = tempPublicSignal
    tempPublicSignal = publicSignals1[1]
    publicSignals1[1] = 17
    encodedProof1 = abi.encodeParameters(['uint256[]', 'uint256[2]', 'uint256[2][2]', 'uint256[2]'], 
    [
       publicSignals1.map((p)=>p.toString()), 
       proof1.pi_a.slice(0, 2), 
       [
         [proof1.pi_b[0][1].toString(), proof1.pi_b[0][0].toString()],
         [proof1.pi_b[1][1].toString(), proof1.pi_b[1][0].toString()]
       ],
       proof1.pi_c.slice(0, 2)
    ])
    await expect(zkPVerifier.changeMaterial(
      123,
      "0x37106196440789755adfccc3a57770fecef1eaca423ca7d75f34dab84d344684",
      encodedProof,
      encodedProof1,
      msg
    )).to.be.revertedWith("proof is not valid")

    publicSignals1[1] = tempPublicSignal
    tempPublicSignal = publicSignals1[2]
    publicSignals1[2] = 17
    encodedProof1 = abi.encodeParameters(['uint256[]', 'uint256[2]', 'uint256[2][2]', 'uint256[2]'], 
    [
       publicSignals1.map((p)=>p.toString()), 
       proof1.pi_a.slice(0, 2), 
       [
         [proof1.pi_b[0][1].toString(), proof1.pi_b[0][0].toString()],
         [proof1.pi_b[1][1].toString(), proof1.pi_b[1][0].toString()]
       ],
       proof1.pi_c.slice(0, 2)
    ])
    await expect(zkPVerifier.changeMaterial(
      123,
      "0x37106196440789755adfccc3a57770fecef1eaca423ca7d75f34dab84d344684",
      encodedProof,
      encodedProof1,
      msg
    )).to.be.revertedWith("invalid hash")

    publicSignals1[2] = tempPublicSignal
    encodedProof1 = abi.encodeParameters(['uint256[]', 'uint256[2]', 'uint256[2][2]', 'uint256[2]'], 
    [
       publicSignals1.map((p)=>p.toString()), 
       proof1.pi_a.slice(0, 2), 
       [
         [proof1.pi_b[0][1].toString(), proof1.pi_b[0][0].toString()],
         [proof1.pi_b[1][1].toString(), proof1.pi_b[1][0].toString()]
       ],
       proof1.pi_c.slice(0, 2)
    ])
    await expect(zkPVerifier.changeMaterial(
      123,
      "0x37106196440789755adfccc3a57770fecef1eaca423ca7d75f34dab84d344684",
      encodedProof1,
      encodedProof1,
      msg
    )).to.be.revertedWith("invalid material")

    await zkPVerifier.changeMaterial(
      123,
      "0x37106196440789755adfccc3a57770fecef1eaca423ca7d75f34dab84d344684",
      encodedProof,
      encodedProof1,
      msg
    )
    
    /* traditional ecdsa verify */
    transferCalldata = erc20Token.interface.encodeFunctionData('transfer', [user.address, 128])
    msg = abi.encodeParameters(['uint256', 'uint256', 'address', 'bytes'], [123, 4, erc20Token.address, transferCalldata])
    msgHash = keccak256(msg)
    signature = await user1.signMessage(ethers.utils.arrayify(msgHash))
    traditionalProof = abi.encodeParameters(['address', 'uint8', 'bytes32', 'bytes32'], 
       [admin.address, "0x"+ signature.toString(16).substr(130,2), "0x" + signature.toString(16).substr(2,64), "0x" + signature.toString(16).substr(66,64)])
    await expect(zkPVerifier.connect(user1).execute(
      123,
      "0x2daa737e13c50c4bbce0e98ee727347a0b510c39a5766854fc1e579342d095aa",
      traditionalProof,
      msg
    )).to.be.revertedWith("proof is not valid")

    signature1 = await user2.signMessage(ethers.utils.arrayify(msgHash))
    traditionalProof = abi.encodeParameters(['address', 'uint8', 'bytes32', 'bytes32'], 
       [user2.address, "0x"+ signature1.toString(16).substr(130,2), "0x" + signature1.toString(16).substr(2,64), "0x" + signature1.toString(16).substr(66,64)])
    await expect(zkPVerifier.connect(user2).execute(
      123,
      "0x2daa737e13c50c4bbce0e98ee727347a0b510c39a5766854fc1e579342d095aa",
      traditionalProof,
      msg
    )).to.be.revertedWith("invalid material")

    traditionalProof = abi.encodeParameters(['address', 'uint8', 'bytes32', 'bytes32'], 
       [user1.address, "0x"+ signature.toString(16).substr(130,2), "0x" + signature.toString(16).substr(2,64), "0x" + signature.toString(16).substr(66,64)])
    await zkPVerifier.connect(user1).execute(
      123,
      "0x2daa737e13c50c4bbce0e98ee727347a0b510c39a5766854fc1e579342d095aa",
      traditionalProof,
      msg
    )

    await expect(zkPVerifier.connect(user1).execute(
      123,
      "0x2daa737e13c50c4bbce0e98ee727347a0b510c39a5766854fc1e579342d095aa",
      traditionalProof,
      msg
    )).to.be.revertedWith("nonce uncorrect")

    //revoke
    transferCalldata = erc20Token.interface.encodeFunctionData('transfer', [user.address, 128])
    msg = abi.encodeParameters(['uint256', 'uint256', 'address', 'bytes'], [123, 5, erc20Token.address, transferCalldata])
    msgHash = keccak256(msg)
    signature = await user1.signMessage(ethers.utils.arrayify(msgHash))
    traditionalProof = abi.encodeParameters(['address', 'uint8', 'bytes32', 'bytes32'], 
       [admin.address, "0x"+ signature.toString(16).substr(130,2), "0x" + signature.toString(16).substr(2,64), "0x" + signature.toString(16).substr(66,64)])
    await expect(zkPVerifier.connect(user1).revoke(
      123,
      "0x2daa737e13c50c4bbce0e98ee727347a0b510c39a5766854fc1e579342d095aa",
      traditionalProof,
      "0x2daa737e13c50c4bbce0e98ee727347a0b510c39a5766854fc1e579342d095aa",
      msg
    )).to.be.revertedWith("proof kind is equal")

    await expect(zkPVerifier.connect(user1).revoke(
      123,
      "0x2eaa737e13c50c4bbce0e98ee727347a0b510c39a5766854fc1e579342d095aa",
      traditionalProof,
      "0x37106196440789755adfccc3a57770fecef1eaca423ca7d75f34dab84d344684",
      msg
    )).to.be.revertedWith("proof kind has not been granted")

    await expect(zkPVerifier.connect(user1).revoke(
      123,
      "0x2daa737e13c50c4bbce0e98ee727347a0b510c39a5766854fc1e579342d095aa",
      traditionalProof,
      "0x3f106196440789755adfccc3a57770fecef1eaca423ca7d75f34dab84d344684",
      msg
    )).to.be.revertedWith("granted proof kind has been revoked")

    await expect(zkPVerifier.connect(user1).revoke(
      123,
      "0x2daa737e13c50c4bbce0e98ee727347a0b510c39a5766854fc1e579342d095aa",
      traditionalProof,
      "0x37106196440789755adfccc3a57770fecef1eaca423ca7d75f34dab84d344684",
      msg
    )).to.be.revertedWith("proof is not valid")
    
    signature1 = await user2.signMessage(ethers.utils.arrayify(msgHash))
    traditionalProof = abi.encodeParameters(['address', 'uint8', 'bytes32', 'bytes32'], 
      [user2.address, "0x"+ signature1.toString(16).substr(130,2), "0x" + signature1.toString(16).substr(2,64), "0x" + signature1.toString(16).substr(66,64)])
    await expect(zkPVerifier.connect(user2).revoke(
      123,
      "0x2daa737e13c50c4bbce0e98ee727347a0b510c39a5766854fc1e579342d095aa",
      traditionalProof,
      "0x37106196440789755adfccc3a57770fecef1eaca423ca7d75f34dab84d344684",
      msg
    )).to.be.revertedWith("invalid material")

    traditionalProof = abi.encodeParameters(['address', 'uint8', 'bytes32', 'bytes32'], 
    [user1.address, "0x"+ signature.toString(16).substr(130,2), "0x" + signature.toString(16).substr(2,64), "0x" + signature.toString(16).substr(66,64)])

    nullProof = abi.encodeParameters(['address'], [admin.address])
    await zkPVerifier.connect(user1).grant(
      123,
      "0x2daa737e13c50c4bbce0e98ee727347a0b510c39a5766854fc1e579342d095aa",
      traditionalProof,
      "0xb62a4cd0de3357c8b9b8da3e7098ae042a0cb5aa226dafdf1d4871c8aeff8609",
      nullProof,
      msg
    )
    
    // transferCalldata = erc20Token.interface.encodeFunctionData('transfer', [user.address, 128])
    // msg = abi.encodeParameters(['uint256', 'uint256', 'address', 'bytes'], [123, 6, erc20Token.address, transferCalldata])
    await expect(zkPVerifier.execute(
      123,
      "0xb62a4cd0de3357c8b9b8da3e7098ae042a0cb5aa226dafdf1d4871c8aeff8609",
      nullProof, 
      msg
    )).to.be.revertedWith("proof is not valid")

    await expect(zkPVerifier.connect(admin).execute(
      123,
      "0xb62a4cd0de3357c8b9b8da3e7098ae042a0cb5aa226dafdf1d4871c8aeff8609",
      nullProof, 
      msg
    )).to.be.revertedWith("nonce")

    transferCalldata = erc20Token.interface.encodeFunctionData('transfer', [user.address, 128])
    msg = abi.encodeParameters(['uint256', 'uint256', 'address', 'bytes'], [123, 6, erc20Token.address, transferCalldata])
    await zkPVerifier.connect(admin).execute(
      123,
      "0xb62a4cd0de3357c8b9b8da3e7098ae042a0cb5aa226dafdf1d4871c8aeff8609",
      nullProof, 
      msg
    )
    
    transferCalldata = erc20Token.interface.encodeFunctionData('transfer', [user.address, 128])
    msg = abi.encodeParameters(['uint256', 'uint256', 'address', 'bytes'], [123, 7, erc20Token.address, transferCalldata])
    msgHash = keccak256(msg)
    signature = await user1.signMessage(ethers.utils.arrayify(msgHash))
    traditionalProof = abi.encodeParameters(['address', 'uint8', 'bytes32', 'bytes32'], 
      [user1.address, "0x"+ signature.toString(16).substr(130,2), "0x" + signature.toString(16).substr(2,64), "0x" + signature.toString(16).substr(66,64)])
    await zkPVerifier.connect(user1).revoke(
      123,
      "0x2daa737e13c50c4bbce0e98ee727347a0b510c39a5766854fc1e579342d095aa",
      traditionalProof,
      "0xb62a4cd0de3357c8b9b8da3e7098ae042a0cb5aa226dafdf1d4871c8aeff8609",
      msg
    )

    transferCalldata = erc20Token.interface.encodeFunctionData('transfer', [user.address, 128])
    msg = abi.encodeParameters(['uint256', 'uint256', 'address', 'bytes'], [123, 8, erc20Token.address, transferCalldata])
    await expect(zkPVerifier.connect(admin).execute(
      123,
      "0xb62a4cd0de3357c8b9b8da3e7098ae042a0cb5aa226dafdf1d4871c8aeff8609",
      nullProof, 
      msg
    )).to.be.revertedWith("proof kind has not been granted")

    transferCalldata = erc20Token.interface.encodeFunctionData('transfer', [user.address, 128])
    msg = abi.encodeParameters(['uint256', 'uint256', 'address', 'bytes'], [123, 8, erc20Token.address, transferCalldata])
    msgHash = keccak256(msg)
    var {publicSignals, proof} = await generateProof(msgHash, privKey1)
    encodedProof = abi.encodeParameters(['uint256[]', 'uint256[2]', 'uint256[2][2]', 'uint256[2]'], 
    [
       publicSignals.map((p)=>p.toString()), 
       proof.pi_a.slice(0, 2), 
       [
         [proof.pi_b[0][1].toString(), proof.pi_b[0][0].toString()],
         [proof.pi_b[1][1].toString(), proof.pi_b[1][0].toString()]
       ],
       proof.pi_c.slice(0, 2)
    ])
    await zkPVerifier.grant(
      123,
      "0x37106196440789755adfccc3a57770fecef1eaca423ca7d75f34dab84d344684",
      encodedProof,
      "0xb62a4cd0de3357c8b9b8da3e7098ae042a0cb5aa226dafdf1d4871c8aeff8609",
      nullProof,
      msg
    )
    
    transferCalldata = erc20Token.interface.encodeFunctionData('transfer', [user.address, 128])
    msg = abi.encodeParameters(['uint256', 'uint256', 'address', 'bytes'], [123, 9, erc20Token.address, transferCalldata])
    msgHash = keccak256(msg)
    var {publicSignals, proof} = await generateProof(msgHash, privKey1)
    encodedProof = abi.encodeParameters(['uint256[]', 'uint256[2]', 'uint256[2][2]', 'uint256[2]'], 
    [
       publicSignals.map((p)=>p.toString()), 
       proof.pi_a.slice(0, 2), 
       [
         [proof.pi_b[0][1].toString(), proof.pi_b[0][0].toString()],
         [proof.pi_b[1][1].toString(), proof.pi_b[1][0].toString()]
       ],
       proof.pi_c.slice(0, 2)
    ])
    await expect(zkPVerifier.grant(
      123,
      "0xb62a4cd0de3357c8b9b8da3e7098ae042a0cb5aa226dafdf1d4871c8aeff8609",
      nullProof,
      "0x37106196440789755adfccc3a57770fecef1eaca423ca7d75f34dab84d344684",
      encodedProof,
      msg
    )).to.be.revertedWith("granted proof kind has been granted")

    transferCalldata = erc20Token.interface.encodeFunctionData('transfer', [user.address, 128])
    msg = abi.encodeParameters(['uint256', 'uint256', 'address', 'bytes'], [123, 9, erc20Token.address, transferCalldata])
    await zkPVerifier.connect(admin).execute(
      123,
      "0xb62a4cd0de3357c8b9b8da3e7098ae042a0cb5aa226dafdf1d4871c8aeff8609",
      nullProof, 
      msg
    )

    transferCalldata = erc20Token.interface.encodeFunctionData('transfer', [user.address, 128])
    msg = abi.encodeParameters(['uint256', 'uint256', 'address', 'bytes'], [123, 10, erc20Token.address, transferCalldata])
    msgHash = keccak256(msg)
    signature = await user1.signMessage(ethers.utils.arrayify(msgHash))
    traditionalProof = abi.encodeParameters(['address', 'uint8', 'bytes32', 'bytes32'], 
      [user1.address, "0x"+ signature.toString(16).substr(130,2), "0x" + signature.toString(16).substr(2,64), "0x" + signature.toString(16).substr(66,64)])
    await zkPVerifier.connect(user1).revoke(
        123,
        "0x2daa737e13c50c4bbce0e98ee727347a0b510c39a5766854fc1e579342d095aa",
        traditionalProof,
        "0x37106196440789755adfccc3a57770fecef1eaca423ca7d75f34dab84d344684",
        msg
    )

    transferCalldata = erc20Token.interface.encodeFunctionData('transfer', [user.address, 128])
    msg = abi.encodeParameters(['uint256', 'uint256', 'address', 'bytes'], [123, 11, erc20Token.address, transferCalldata])
    msgHash = keccak256(msg)
    var {publicSignals, proof} = await generateProof(msgHash, privKey1)
    encodedProof = abi.encodeParameters(['uint256[]', 'uint256[2]', 'uint256[2][2]', 'uint256[2]'], 
    [
       publicSignals.map((p)=>p.toString()), 
       proof.pi_a.slice(0, 2), 
       [
         [proof.pi_b[0][1].toString(), proof.pi_b[0][0].toString()],
         [proof.pi_b[1][1].toString(), proof.pi_b[1][0].toString()]
       ],
       proof.pi_c.slice(0, 2)
    ])
    
    await expect(zkPVerifier.execute(
      123,
      "0xb62a4cd0de3357c8b9b8da3e7098ae042a0cb5aa226dafdf1d4871c8aeff8609",
      encodedProof, 
      msg
    )).to.be.revertedWith("proof kind has not been granted")

    transferCalldata = erc20Token.interface.encodeFunctionData('transfer', [user.address, 128])
    msg = abi.encodeParameters(['uint256', 'uint256', 'address', 'bytes'], [123, 11, erc20Token.address, transferCalldata])
    await expect(zkPVerifier.connect(admin).execute(
      123,
      "0xb62a4cd0de3357c8b9b8da3e7098ae042a0cb5aa226dafdf1d4871c8aeff8609",
      nullProof, 
      msg
    )).to.be.revertedWith("proof kind has not been granted")
  })
})