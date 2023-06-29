// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "./IShadowWallet.sol";
import "../factory/IShadowFactory.sol";
import "../interfaces/ICircuitValidator.sol";

contract ShadowWallet is IShadowWallet, Initializable {
    address public caller;
    IShadowFactory public factory;
    uint256 public nonce;
    bytes32 public material;

    event ProofUsed(
        address wallet,
        uint256 id
    );

    function initialize(
        address _caller, 
        address _factory,
        uint256 id,
        uint256[] memory inputs,
        uint256[2] calldata a,
        uint256[2][2] calldata b,
        uint256[2] calldata c,
        bytes calldata action
    ) external override initializer{
        require(Address.isContract(_caller), "invalid caller");
        require(Address.isContract(_factory), "invalid factory");
        caller = _caller;
        factory = IShadowFactory(_factory);
        ICircuitValidator validator = ICircuitValidator(factory.getValidator());
        require(validator.verify(id, inputs, a, b, c, action), "proof is not valid");
        require((validator.getChallengeId(inputs, action) == nonce) && (nonce == 0), "nonce uncorrect");
        material = validator.getMaterial(inputs, action);
        emit ProofUsed(address(this), nonce);
        nonce++;
    }

    function execute(
        uint256            id,        
        uint256[] calldata inputs,
        uint256[2]  calldata a,
        uint256[2][2] calldata b,
        uint256[2] calldata c,
        bytes calldata action
    ) external override returns (bytes memory){
        require(msg.sender == caller, "can not call");
        ICircuitValidator validator = ICircuitValidator(factory.getValidator());
        require(validator.verify(id, inputs, a, b, c, action), "proof is not valid");
        require((validator.getChallengeId(inputs, action) == nonce) && (nonce != 0), "nonce uncorrect");
        require(material == validator.getMaterial(inputs, action), "invalid material");
        nonce++;
        (address target, bytes memory method) = validator.getTargetMethod(inputs, action);
        emit ProofUsed(address(this), nonce);    
        return Address.functionCall(target, method);
    }

    function changeMaterial(
        uint256            id,
        uint256[] memory oldInputs,
        uint256[2] calldata oldA,
        uint256[2][2] calldata oldB,
        uint256[2] calldata oldC,
        uint256[] memory newInputs,
        uint256[2] calldata newA,
        uint256[2][2] calldata newB,
        uint256[2] calldata newC,
        bytes calldata action
    ) external override {
        require(msg.sender == caller, "can not call");
        ICircuitValidator validator = ICircuitValidator(factory.getValidator());
        require(validator.verify(id, oldInputs, oldA, oldB, oldC, action), "proof is not valid");
        require(validator.verify(id, newInputs, newA, newB, newC, action), "proof is not valid");
        require(material == validator.getMaterial(oldInputs, action), "invalid material");
        require((validator.getChallengeId(oldInputs, action) == nonce) && (nonce != 0), "nonce uncorrect");
        material = validator.getMaterial(newInputs, action);
        emit ProofUsed(address(this), nonce);
        nonce++;
    }
}