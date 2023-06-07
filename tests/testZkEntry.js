const chai = require("chai");
const expect = chai.expect;
const Web3 = require('web3');
var utils_1 = require('ethers').utils;
const { AddressZero } = require("ethers").constants
const { BigNumber } = require('ethers')
const hre = require("hardhat");
const { ethers, upgrades } = require("hardhat");
const { proving } = require("@iden3/js-jwz");
const getCurveFromName = require("ffjavascript").getCurveFromName;
var base64 = require("rfc4648").base64url;
const {
  BjjProvider,
  CredentialStorage,
  CredentialWallet,
  defaultEthConnectionConfig,
  EthStateStorage,
  ICredentialWallet,
  IDataStorage,
  Identity,
  IdentityCreationOptions,
  IdentityStorage,
  IdentityWallet,
  IIdentityWallet,
  InMemoryDataSource,
  InMemoryMerkleTreeStorage,
  InMemoryPrivateKeyStore,
  KMS,
  KmsKeyType,
  Profile,
  W3CCredential,
  CredentialRequest,
  EthConnectionConfig,
  CircuitStorage,
  CircuitData,
  FSKeyLoader,
  CircuitId,
  IStateStorage,
  ProofService,
  ZeroKnowledgeProofRequest,
  PackageManager,
  AuthorizationRequestMessage,
  PROTOCOL_CONSTANTS,
  AuthHandler,
  AuthDataPrepareFunc,
  StateVerificationFunc,
  DataPrepareHandlerFunc,
  VerificationHandlerFunc,
  IPackageManager,
  VerificationParams,
  ProvingParams,
  ZKPPacker,
  PlainPacker,
  ICircuitStorage,
  core,
  ZKPRequestWithCredential,
  CredentialStatusType,
  HttpSchemaLoader,
  mt,
  AtomicQuerySigV2PubSignals,
  byteEncoder
} = require("@0xpolygonid/js-sdk");
const path = require("path");
const fs = require("fs");
const js_iden3_core_1 = require("@iden3/js-iden3-core");
const js_merkletree_1 = require("@iden3/js-merkletree");
const mt_1 = require("@0xpolygonid/js-sdk/dist/cjs/storage/entities/mt");
HttpSchemaLoader.prototype.load  = async function(url) {
  // const resp = await fetch(url);
  const uri = new URL(url)
  const my = uri.pathname.split("/")
  const filePath = path.join(__dirname, my[my.length-3], my[my.length-2], my[my.length-1])
  const readFile = require("util").promisify(fs.readFile)
  const resp = await readFile(filePath)
  return resp;
}
const rhsUrl = "https://rhs-staging.polygonid.me"
const rpcUrl = "http://127.0.0.1:8545"
const walletKey = "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80";
const circuitsFolder = "curcuit";

function initDataStorage(rpcUrl, contractAddress) {
    let conf = defaultEthConnectionConfig
    conf.contractAddress = contractAddress
    conf.url = rpcUrl
  
    var dataStorage = {
      credential: new CredentialStorage(new InMemoryDataSource()),
      identity: new IdentityStorage(
        new InMemoryDataSource(),
        new InMemoryDataSource()
      ),
      mt: new InMemoryMerkleTreeStorage(40),
  
      states: new EthStateStorage(conf)
    }
  
    return dataStorage
}

async function initIdentityWallet(dataStorage, credentialWallet) {
    const memoryKeyStore = new InMemoryPrivateKeyStore()
    const bjjProvider = new BjjProvider(KmsKeyType.BabyJubJub, memoryKeyStore)
    const kms = new KMS()
    kms.registerKeyProvider(KmsKeyType.BabyJubJub, bjjProvider)
  
    return new IdentityWallet(kms, dataStorage, credentialWallet)
}

async function initCredentialWallet(dataStorage) {
    credWallet = new CredentialWallet(dataStorage);
    return credWallet
}
  
async function initCircuitStorage() {
    const circuitStorage = new CircuitStorage(new InMemoryDataSource())
  
    const loader = new FSKeyLoader(path.join(__dirname, circuitsFolder))
  
    await circuitStorage.saveCircuitData(CircuitId.AuthV2, {
      circuitId: CircuitId.AuthV2,
      wasm: await loader.load(path.join(CircuitId.AuthV2.toString(), "circuit.wasm")),
      provingKey: await loader.load(
        path.join(CircuitId.AuthV2.toString(), "circuit_final.zkey")
      ),
      verificationKey: await loader.load(
        path.join(CircuitId.AuthV2.toString(), "verification_key.json")
      )
    })
  
    await circuitStorage.saveCircuitData(CircuitId.AtomicQuerySigV2, {
      circuitId: CircuitId.AtomicQuerySigV2,
      wasm: await loader.load(
        `${CircuitId.AtomicQuerySigV2.toString()}/circuit.wasm`
      ),
      provingKey: await loader.load(
        `${CircuitId.AtomicQuerySigV2.toString()}/circuit_final.zkey`
      ),
      verificationKey: await loader.load(
        `${CircuitId.AtomicQuerySigV2.toString()}/verification_key.json`
      )
    })
  
    await circuitStorage.saveCircuitData(CircuitId.StateTransition, {
      circuitId: CircuitId.StateTransition,
      wasm: await loader.load(
        `${CircuitId.StateTransition.toString()}/circuit.wasm`
      ),
      provingKey: await loader.load(
        `${CircuitId.StateTransition.toString()}/circuit_final.zkey`
      ),
      verificationKey: await loader.load(
        `${CircuitId.StateTransition.toString()}/verification_key.json`
      )
    })
  
    await circuitStorage.saveCircuitData(CircuitId.AtomicQueryMTPV2, {
      circuitId: CircuitId.AtomicQueryMTPV2,
      wasm: await loader.load(
        `${CircuitId.AtomicQueryMTPV2.toString()}/circuit.wasm`
      ),
      provingKey: await loader.load(
        `${CircuitId.AtomicQueryMTPV2.toString()}/circuit_final.zkey`
      ),
      verificationKey: await loader.load(
        `${CircuitId.AtomicQueryMTPV2.toString()}/verification_key.json`
      )
    })
    return circuitStorage
}
  
async function initProofService(
    identityWallet,
    credentialWallet,
    stateStorage,
    circuitStorage
) {
    return new ProofService(
      identityWallet,
      credentialWallet,
      circuitStorage,
      stateStorage
    )
}
  
async function generateProofs(rpcUrl, contractAddress) {
  console.log("=============== generate proofs ===============")

  const dataStorage = initDataStorage(rpcUrl, contractAddress)
  let credentialWallet = await initCredentialWallet(dataStorage)
  credentialWallet.getRevocationStatus = async function(credStatus, issuerDID, issuerData) {
    //   const did = js_iden3_core_1.DID.parse(cred.issuer);
    const cTR = await dataStorage.mt.getMerkleTreeByIdentifierAndType(issuerDID.toString(), mt_1.MerkleTreeType.Claims);
    const rTR = await dataStorage.mt.getMerkleTreeByIdentifierAndType(issuerDID.toString(), mt_1.MerkleTreeType.Revocations);
    const roTR = await dataStorage.mt.getMerkleTreeByIdentifierAndType(issuerDID.toString(), mt_1.MerkleTreeType.Roots);
    const s = await (0, js_merkletree_1.hashElems)([
        (await cTR.root()).bigInt(),
        (await rTR.root()).bigInt(),
        (await roTR.root()).bigInt()
    ]);
    const r = {
      mtp: {
        existence: false,
        nodeAux: undefined,
        siblings: []
      },
      issuer: {
        state: s.hex(),
        claimsTreeRoot: (await cTR.root()).hex(),
        revocationTreeRoot: (await rTR.root()).hex(),
        rootOfRoots: (await roTR.root()).hex()
      }
    };
    return r;
  };
  const identityWallet = await initIdentityWallet(dataStorage, credentialWallet)
  const circuitStorage = await initCircuitStorage()
  const proofService = await initProofService(
    identityWallet,
    credentialWallet,
    dataStorage.states,
    circuitStorage
  )

  const {
    did: userDID,
    credential: authBJJCredentialUser
  } = await identityWallet.createIdentity({
    method: core.DidMethod.Iden3,
    blockchain: core.Blockchain.Polygon,
    networkId: core.NetworkId.Mumbai,
    revocationOpts: {
      type: CredentialStatusType.Iden3ReverseSparseMerkleTreeProof,
      baseUrl: rhsUrl
    }
  })

  console.log("=============== user did ===============")

  const {
    did: issuerDID,
    credential: issuerAuthBJJCredential
  } = await identityWallet.createIdentity({
    method: core.DidMethod.Iden3,
    blockchain: core.Blockchain.Polygon,
    networkId: core.NetworkId.Mumbai,
    revocationOpts: {
      type: CredentialStatusType.Iden3ReverseSparseMerkleTreeProof,
      baseUrl: rhsUrl
    }
  })

  const credentialRequest = {
    credentialSchema:
      "https://raw.githubusercontent.com/iden3/claim-schema-vocab/main/schemas/json/KYCAgeCredential-v3.json",
    type: "KYCAgeCredential",
    credentialSubject: {
      id: userDID.toString(),
      birthday: 19960424,
      documentType: 99
    },
    expiration: 12345678888,
    revocationOpts: {
      type: CredentialStatusType.Iden3ReverseSparseMerkleTreeProof,
      baseUrl: rhsUrl
    }
  }
  const credential = await identityWallet.issueCredential(
    issuerDID,
    credentialRequest
  )

  await dataStorage.credential.saveCredential(credential)

  console.log(
    "================= generate Iden3SparseMerkleTreeProof ======================="
  )

  const res = await identityWallet.addCredentialsToMerkleTree(
    [credential],
    issuerDID
  )

  console.log("================= push states to rhs ===================")

  await identityWallet.publishStateToRHS(issuerDID, rhsUrl);
  console.log("================= publish to blockchain ===================")

  const ethSigner = new ethers.Wallet(walletKey, dataStorage.states.provider)
  const txId = await proofService.transitState(
    issuerDID,
    res.oldTreeState,
    true,
    dataStorage.states,
    ethSigner
  )
  console.log(txId)

  const proofReqSig = {
    id: 1,
    circuitId: CircuitId.AtomicQuerySigV2,
    optional: false,
    query: {
      allowedIssuers: ["*"],
      type: credentialRequest.type,
      context:
        "https://raw.githubusercontent.com/iden3/claim-schema-vocab/main/schemas/json-ld/kyc-v3.json-ld",
      credentialSubject: {
        documentType: {
          $eq: 99
        }
      }
    }
  }

  let credsToChooseForZKPReq = await credentialWallet.findByQuery(
    proofReqSig.query
  )

  console.log(
    "================= generate credentialAtomicSigV2 ==================="
  )

  return proofService.generateProof(
    proofReqSig,
    userDID,
    credsToChooseForZKPReq[0]
  )
}

describe("ZKEntry", function () {
  beforeEach(async function () {
      //准备必要账户
      [deployer, admin, miner, user, user1, ,user2, user3, redeemaccount] = await hre.ethers.getSigners()

      console.log(CircuitId.AuthV2.toString())
      console.log(CircuitId.AtomicQuerySigV2.toString())
      console.log(CircuitId.StateTransition.toString())
      console.log(CircuitId.AtomicQueryMTPV2.toString())

      console.log("deployer account:", deployer.address)
      console.log("admin account:", admin.address)
      console.log("team account:", miner.address)
      console.log("user account:", user.address)
      console.log("user1 account:", user1.address)
      console.log("user2 account:", user2.address)
      console.log("user3 account:", user3.address)
      console.log("redeemaccount account:", redeemaccount.address)

      shadowWalletCon = await ethers.getContractFactory("ShadowWallet", deployer)
      shadowWallet = await shadowWalletCon.deploy()
      await shadowWallet.deployed()
      console.log("+++++++++++++shadowWallet+++++++++++++++ ", shadowWallet.address)

      shadowWalletFactoryCon = await ethers.getContractFactory("ShadowWalletFactory", deployer)
      shadowWalletFactory = await shadowWalletFactoryCon.deploy(shadowWallet.address)
      await shadowWalletFactory.deployed()
      console.log("+++++++++++++shadowWalletFactory+++++++++++++++ ", shadowWalletFactory.address)

      poseidon1Con = await ethers.getContractFactory("PoseidonUnit1L", deployer)
      poseidon1 = await poseidon1Con.deploy()
      await poseidon1.deployed()
      console.log("+++++++++++++poseidon1+++++++++++++++ ", poseidon1.address)

      poseidon2Con = await ethers.getContractFactory("PoseidonUnit2L", deployer)
      poseidon2 = await poseidon2Con.deploy()
      await poseidon2.deployed()
      console.log("+++++++++++++poseidon2+++++++++++++++ ", poseidon2.address)

      poseidon3Con = await ethers.getContractFactory("PoseidonUnit3L", deployer)
      poseidon3 = await poseidon3Con.deploy()
      await poseidon3.deployed()
      console.log("+++++++++++++poseidon3+++++++++++++++ ", poseidon3.address)

      poseidon4Con = await ethers.getContractFactory("PoseidonUnit4L", deployer)
      poseidon4 = await poseidon4Con.deploy()
      await poseidon4.deployed()
      console.log("+++++++++++++poseidon4+++++++++++++++ ", poseidon4.address)

      poseidon5Con = await ethers.getContractFactory("PoseidonUnit5L", deployer)
      poseidon5 = await poseidon5Con.deploy()
      await poseidon5.deployed()
      console.log("+++++++++++++poseidon5+++++++++++++++ ", poseidon5.address)

      poseidon6Con = await ethers.getContractFactory("PoseidonUnit6L", deployer)
      poseidon6 = await poseidon6Con.deploy()
      await poseidon6.deployed()
      console.log("+++++++++++++poseidon6+++++++++++++++ ", poseidon6.address)

      spongePoseidonCon = await ethers.getContractFactory("SpongePoseidon", {
        signer: deployer,
        libraries: {
          PoseidonUnit6L: poseidon6.address
        }
      })

      spongePoseidon = await spongePoseidonCon.deploy()
      await spongePoseidon.deployed()
      console.log("+++++++++++++spongePoseidon+++++++++++++++ ", spongePoseidon.address)

      poseidonCon = await ethers.getContractFactory("PoseidonFacade", {
        signer: deployer,
        libraries: {
          PoseidonUnit1L: poseidon1.address,
          PoseidonUnit2L: poseidon2.address,
          PoseidonUnit3L: poseidon3.address,
          PoseidonUnit4L: poseidon4.address,
          PoseidonUnit5L: poseidon5.address,
          PoseidonUnit6L: poseidon6.address,
          SpongePoseidon: spongePoseidon.address,
        }
      })

      poseidon = await poseidonCon.deploy()
      await poseidon.deployed()
      console.log("+++++++++++++poseidon+++++++++++++++ ", poseidon.address)

      stateLibCon = await ethers.getContractFactory("StateLib", {
        signer: deployer,
        // libraries: {
        //   PoseidonFacade: poseidon.address
        // }
      })
      stateLib = await stateLibCon.deploy()
      await stateLib.deployed()
      console.log("+++++++++++++stateLib+++++++++++++++ ", stateLib.address)

      smtLibCon = await ethers.getContractFactory("SmtLib", {
        signer: deployer,
        libraries: {
          PoseidonUnit2L: poseidon2.address,
          PoseidonUnit3L: poseidon3.address,
        }
      })
      smtLib = await smtLibCon.deploy()
      await smtLib.deployed()
      console.log("+++++++++++++smtLib+++++++++++++++ ", smtLib.address)

      stateV2Con = await ethers.getContractFactory("StateV2",  {
        signer: deployer,
        libraries: {
          PoseidonUnit1L: poseidon1.address,
          SmtLib: smtLib.address,
          StateLib: stateLib.address
        }
      })
      stateV2 = await stateV2Con.deploy()
      await stateV2.deployed()
      console.log("+++++++++++++stateV2+++++++++++++++ ", stateV2.address)

      zkPVerifierCon = await ethers.getContractFactory("ZkEntry", {
        signer: deployer,
        libraries: {
          PoseidonFacade: poseidon.address
        }
      })
      
      await expect(zkPVerifierCon.deploy(shadowWalletFactory.address, AddressZero)).to.be.revertedWith("invalid state")
      await expect(zkPVerifierCon.deploy(AddressZero, stateV2.address)).to.be.revertedWith("invalid factory")
      zkPVerifier = await zkPVerifierCon.deploy(shadowWalletFactory.address, stateV2.address)
      await zkPVerifier.deployed()
      console.log("+++++++++++++zkPVerifier+++++++++++++++ ", zkPVerifier.address)

      verifierV2Con = await ethers.getContractFactory("VerifierV2", deployer)
      verifierV2 = await verifierV2Con.deploy()
      await verifierV2.deployed()
      console.log("+++++++++++++verifierV2+++++++++++++++ ", verifierV2.address)

      await stateV2.initialize(verifierV2.address)

      verifierSigCon = await ethers.getContractFactory("VerifierSigWrapper", deployer)
      verifierSig = await verifierSigCon.deploy()
      await verifierSig.deployed()
      console.log("+++++++++++++VerifierSigWrapper+++++++++++++++ ", verifierSig.address)

      sigValidatorCon = await ethers.getContractFactory("CredentialAtomicQuerySigValidator", deployer)
      sigValidator = await sigValidatorCon.deploy()
      await sigValidator.deployed()
      console.log("+++++++++++++sigValidator+++++++++++++++ ", sigValidator.address)
      await sigValidator.initialize(verifierSig.address, stateV2.address)

      erc20TokenCon = await ethers.getContractFactory("ERC20TokenSample", deployer)
      erc20Token = await erc20TokenCon.deploy()
      await erc20Token.deployed()
      console.log("+++++++++++++erc20Token+++++++++++++++ ", erc20Token.address)
  })

  it('ZKEntry', async () => {
    const circuitId = "credentialAtomicQuerySig";
    await expect(zkPVerifier.setZKPRequest(
      1,
      sigValidator.address,
      ethers.BigNumber.from("000000000000000000000000000000000000000"),
      2,
      2,
      [20010101, ...new Array(63).fill(0).map((i) => 0)]
    )).to.be.revertedWith("invalid schema")

    await expect(zkPVerifier.setZKPRequest(
      1,
      AddressZero,
      ethers.BigNumber.from("000000000000000000000000000000000000000"),
      2,
      2,
      [20010101, ...new Array(63).fill(0).map((i) => 0)]
    )).to.be.revertedWith("invalid schema")

    let tx = await zkPVerifier.setZKPRequest(
      1,
      sigValidator.address,
      ethers.BigNumber.from("210459579859058135404770043788028292398"),
      2,
      2,
      [20010101, ...new Array(63).fill(0).map((i) => 0)]
    )

    const {pub_signals, proof} =  await generateProofs(rpcUrl, stateV2.address)
    console.log(proof)
    console.log(pub_signals)
    const transferCalldata = erc20Token.interface.encodeFunctionData('transfer', [user.address, 128])
    let temp = pub_signals[17]
    pub_signals[17]=7
    await expect(zkPVerifier.submitZKPResponse(
      1,
      pub_signals.map((p)=>p.toString()), 
      proof.pi_a.slice(0, 2), 
      [
        [proof.pi_b[0][1].toString(), proof.pi_b[0][0].toString()],
        [proof.pi_b[1][1].toString(), proof.pi_b[1][0].toString()]
      ],
      proof.pi_c.slice(0, 2),
      erc20Token.address,
      transferCalldata
    )).to.be.revertedWith("Proof is not valid")

    pub_signals[17]=temp

    await expect(zkPVerifier.submitZKPResponse(
      2,
      pub_signals.map((p)=>p.toString()), 
      proof.pi_a.slice(0, 2), 
      [
        [proof.pi_b[0][1].toString(), proof.pi_b[0][0].toString()],
        [proof.pi_b[1][1].toString(), proof.pi_b[1][0].toString()]
      ],
      proof.pi_c.slice(0, 2),
      erc20Token.address,
      transferCalldata
    )).to.be.revertedWith("validator is not set for this request id")

    await zkPVerifier.submitZKPResponse(
      1,
      pub_signals.map((p)=>p.toString()), 
      proof.pi_a.slice(0, 2), 
      [
        [proof.pi_b[0][1].toString(), proof.pi_b[0][0].toString()],
        [proof.pi_b[1][1].toString(), proof.pi_b[1][0].toString()]
      ],
      proof.pi_c.slice(0, 2),
      erc20Token.address,
      transferCalldata
    )

    tx = await zkPVerifier.idMappings(pub_signals[1].toString())
    console.log(tx)
    await erc20Token.transfer(tx, 100000)
    await zkPVerifier.submitZKPResponse(
      1,
      pub_signals.map((p)=>p.toString()), 
      proof.pi_a.slice(0, 2), 
      [
        [proof.pi_b[0][1].toString(), proof.pi_b[0][0].toString()],
        [proof.pi_b[1][1].toString(), proof.pi_b[1][0].toString()]
      ],
      proof.pi_c.slice(0, 2),
      erc20Token.address,
      transferCalldata
    )

    await expect(zkPVerifier.submitZKPResponse(
      1,
      pub_signals.map((p)=>p.toString()), 
      proof.pi_a.slice(0, 2), 
      [
        [proof.pi_b[0][1].toString(), proof.pi_b[0][0].toString()],
        [proof.pi_b[1][1].toString(), proof.pi_b[1][0].toString()]
      ],
      proof.pi_c.slice(0, 2),
      erc20Token.address,
      transferCalldata
    )).to.be.revertedWith("proof has been used")
  })
})