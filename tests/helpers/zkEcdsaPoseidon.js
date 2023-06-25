const snarkJs = require("snarkjs");
const {buildEddsa,buildBabyjub} = require("circomlibjs");
const {
  hashPersonalMessage,
} = require("@ethereumjs/util");
const fs = require("fs");

const privKey = BigInt(
  "0xf5b552f608f5b552f608f5b552f6082ff5b552f608f5b552f608f5b552f6082f"
);

const ZKEY_PATH =
  "../curcuit/ecdsaposeidon/circuit_final.zkey";
const VKEY_PATH = "../curcuit/ecdsaposeidon/verification_key.json";
const verify = async (proof, publicSignals) => {
  const vKey = JSON.parse(fs.readFileSync(VKEY_PATH));
  const result = await snarkJs.groth16.verify(
    vKey,
    publicSignals,
    proof,
    console
  );

  if (result) {
    console.log("Proof verified!");
  } else {
    console.log("Proof verification failed");
  }
};

const prove = async () => {
  if (!fs.existsSync(ZKEY_PATH)) {
    console.log(
      "zkey not found. Please run `yarn build:ecdsa_verify_pubkey_to_addr` first"
    );
    return;
  }

  console.time("Full proof generation");

  const msgHash = hashPersonalMessage(Buffer.from("hello world"))
  const msgHash1 = hashPersonalMessage(Buffer.from("hell0 world"))
  const ecdsa = await buildEddsa()
  const babyJub = await buildBabyjub();
  const { F } = babyJub;
  console.log("====priKey====")
  console.log(privKey.toString(16))
  const msg = F.e(msgHash);
  const pubKey = ecdsa.prv2pub(privKey.toString(16))
  const signature = ecdsa.signPoseidon(privKey.toString(16), msg)
  console.log("====msg====")
  console.log(msg)
  console.log("====pubkey====")
  console.log(F.toObject(pubKey[0]))
  console.log("====signature====")
  console.log(signature)

  const input = {
    enabled: 1,
    Ax: F.toObject(pubKey[0]),
    Ay: F.toObject(pubKey[1]),
    R8x: F.toObject(signature.R8[0]),
    R8y: F.toObject(signature.R8[1]),
    S:  signature.S,
    M:   F.toObject(msg)
  };

  console.log("Proving...");
  const { publicSignals, proof } = await snarkJs.groth16.fullProve(
      input,
      "../curcuit/ecdsaposeidon/curcuit.wasm",
      ZKEY_PATH
  );

  console.log("=============");
  console.log(proof);
  console.log(publicSignals);
  const t = publicSignals[2]
  publicSignals[2]=F.toObject(F.e(msgHash1))
  try{
    await verify(proof, publicSignals);
  } catch(e) {
    console.log(e)
  }
  publicSignals[2] = t
  await verify(proof, publicSignals);
  process.exit(0)
};

prove();