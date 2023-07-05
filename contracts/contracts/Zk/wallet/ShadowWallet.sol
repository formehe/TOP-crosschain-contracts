// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "./IShadowWallet.sol";
import "../factory/IShadowFactory.sol";
import "../interfaces/IValidator.sol";

contract ShadowWallet is IShadowWallet, Initializable {
    address public caller;
    IShadowFactory public factory;
    uint256 public nonce;
    mapping(uint256 => uint256) public materials;
    // a kind of validator can be granted only once;
    mapping(uint256 => uint256) public granted;
    mapping(uint256 => uint256[]) public granter;

    event ProofUsed(
        address wallet,
        uint256 id
    );

    event ValidatorGranted(
        uint256 proofKind,
        // address proofValidator,
        uint256 grantedProofKind
        // address grantedProofValidator
    );

    event ValidatorRevoked(
        uint256 proofKind,
        // address proofValidator,
        uint256 revokedProofKind
        // address revokedProofValidator
    );

    function initialize(
        address           _caller,
        address           _factory,
        uint256           id,
        uint256           proofKind,
        bytes calldata    proof,
        bytes calldata    action
    ) external override initializer{
        require(Address.isContract(_caller), "invalid caller");
        require(Address.isContract(_factory), "invalid factory");
        caller = _caller;
        factory = IShadowFactory(_factory);

        address temp = factory.getValidator(proofKind);
        require(temp != address(0), "validator is not exist");
        IValidator validator = IValidator(temp);
        require(validator.verify(id, proof, action, msg.sender), "proof is not valid");
        require((validator.getChallengeId(proof, action) == nonce) && (nonce == 0), "nonce uncorrect");
        
        uint256 material = validator.getMaterial(proof, action, msg.sender);
        require(materials[proofKind] == 0 && material != 0, "material is exist");
        materials[proofKind] = material;
        granted[proofKind] = proofKind;

        emit ProofUsed(address(this), nonce);
        nonce++;
    }

    function execute(
        uint256           id,
        uint256           proofKind,
        bytes calldata    proof,
        bytes calldata    action,
        address           context
    ) external override returns (bytes memory){
        require(msg.sender == caller, "not permit to call");
        require(granted[proofKind] != 0, "proof kind has not been granted");

        address temp = factory.getValidator(proofKind);
        require(temp != address(0), "validator is not exist");
        IValidator validator = IValidator(temp);
        require(validator.verify(id, proof, action, context), "proof is not valid");
        require((validator.getChallengeId(proof, action) == nonce) && (nonce != 0), "nonce uncorrect");
        nonce++;

        uint256 material = validator.getMaterial(proof, action, context);
        require(material != 0 && material == materials[proofKind], "invalid material");

        (address target, bytes memory method) = validator.getTargetMethod(proof, action);
        emit ProofUsed(address(this), nonce);    
        return Address.functionCall(target, method);
    }

    function changeMaterial(
        uint256        id,
        uint256        proofKind,
        bytes calldata oldProof,
        bytes calldata proof,
        bytes calldata action,
        address        context
    ) external override {
        require(msg.sender == caller, "not permit to call");
        require(granted[proofKind] != 0, "proof kind has not been granted");

        address temp = factory.getValidator(proofKind);
        require(temp != address(0), "validator is not exist");
        IValidator validator = IValidator(temp);

        require(validator.verify(id, oldProof, action, context), "proof is not valid");
        require(validator.verify(id, proof, action, context), "proof is not valid");

        uint256 material = validator.getMaterial(oldProof, action, context);
        require(material != 0 && material == materials[proofKind], "invalid material");

        require((validator.getChallengeId(oldProof, action) == nonce) && (nonce != 0), "nonce uncorrect");
        material = validator.getMaterial(proof, action, context);
        require(material != 0, "invalid material");
        materials[proofKind] = material;

        emit ProofUsed(address(this), nonce);
        nonce++;
    }

    function grant(
        uint256        id,
        uint256        proofKind,
        bytes calldata proof,
        uint256        grantedProofKind,
        bytes calldata grantedProof,
        bytes calldata action,
        address        context
    ) external override {
        require(msg.sender == caller, "not permit to call");
        require(proofKind != grantedProofKind, "proof kind is equal");
        require(granted[proofKind] != 0, "proof kind has not been granted");
        require(granted[grantedProofKind] == 0, "granted proof kind has been granted");
        
        address temp = factory.getValidator(proofKind);
        require(temp != address(0), "validator is not exist");
        IValidator validator = IValidator(temp);
        require(validator.verify(id, proof, action, context), "proof is not valid");
        
        uint256 material = validator.getMaterial(proof, action, context);
        require(material != 0 && material == materials[proofKind], "invalid material");

        temp = factory.getValidator(grantedProofKind);
        require(temp != address(0), "validator is not exist");
        validator = IValidator(temp);
        // require(validator.verify(id, grantedProof, action), "proof is not valid");

        material = validator.getMaterial(grantedProof, action, context);
        require(material != 0, "invalid material");

        materials[grantedProofKind] = material;
        granted[grantedProofKind] = proofKind;
        granter[proofKind].push(grantedProofKind);
        require((validator.getChallengeId(proof, action) == nonce) && (nonce != 0), "nonce uncorrect");
        emit ValidatorGranted(proofKind, grantedProofKind);
        emit ProofUsed(address(this), nonce);
        nonce++;
    }

    function revoke(
        uint256        id,
        uint256        proofKind,
        bytes calldata proof,
        uint256        revokedProofKind,
        bytes calldata action,
        address        context
    ) external override {
        require(msg.sender == caller, "not permit to call");
        require(proofKind != revokedProofKind, "proof kind is equal");
        require(granted[proofKind] != 0, "proof kind has not been granted");
        require(granted[revokedProofKind] == proofKind, "granted proof kind has been revoked");

        address temp = factory.getValidator(proofKind);
        require(temp != address(0), "validator is not exist");
        IValidator validator = IValidator(temp);
        require(validator.verify(id, proof, action, context), "proof is not valid");
        
        uint256 material = validator.getMaterial(proof, action, context);
        require(material != 0 && material == materials[proofKind], "invalid material");

        delete materials[revokedProofKind];
        delete granted[revokedProofKind];
        for (uint256 i = 0; i < granter[proofKind].length; i++) {
            if (granter[proofKind][i] == revokedProofKind) {
                granter[proofKind][i] = granter[proofKind][granter[proofKind].length - 1];
                granter[proofKind].pop();
                break;
            }
        }

        //may be need large gas
        _clean(revokedProofKind);

        require((validator.getChallengeId(proof, action) == nonce) && (nonce != 0), "nonce uncorrect");
        emit ValidatorRevoked(proofKind, revokedProofKind);
        emit ProofUsed(address(this), nonce);
        nonce++;
    }

    function _clean(uint256 revoked) internal{
        for (uint256 i = 0; i < granter[revoked].length; i++) {
            _clean(granter[revoked][i]);
            delete materials[granter[revoked][i]];
            delete granted[granter[revoked][i]];
            delete granter[revoked];
        }
    }
}