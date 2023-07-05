// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "../interfaces/IValidator.sol";
import "../interfaces/IVerifier.sol";
import "../lib/Poseidon.sol";
/**
    The format of action:|userID|Nonce|Target|Action|
*/

contract ZkEcdsaValidator is IValidator, Initializable{
    IVerifier public verifier;

    function initialize(
        address _verifier
    ) public initializer {
        verifier = IVerifier(_verifier);
    }

    function verify(
        uint256                 id,
        bytes          calldata proof,
        bytes          calldata action,
        address                 /*context*/
    ) external view override returns (bool) {
        (uint256[] memory inputs, uint256[2] memory a, uint256[2][2] memory b, uint256[2] memory c) 
                        = abi.decode(proof, (uint256[],uint256[2],uint256[2][2],uint256[2]));
        require(inputs.length == 3, "invalid input length");
        bytes32 msgHash = keccak256(action);
        require(inputs[2] == PoseidonUnit1L.poseidon([uint256(msgHash)]), "invalid hash");
        require(id == _getUserId(action), "invalid user");
        return verifier.verifyProof(a, b, c, inputs);
    }

    function getID() external pure override returns (bytes32) {
        return keccak256("ZkEcdsaValidator");
    }

    function getUserId(
        bytes calldata /*proof*/, 
        bytes calldata action
    ) external pure override returns (uint256) {
        return _getUserId(action);
    }

    function _getUserId(
        bytes calldata action
    ) internal pure returns (uint256 userId) {
        (userId, , ,) = abi.decode(action, (uint256,uint256,address,bytes));
    }

    function getChallengeId(
        bytes calldata /*proof*/, 
        bytes calldata action
    ) external pure override returns (uint256) {
        return _getChallengeId(action);
    }

    function _getChallengeId( 
        bytes calldata action
    ) internal pure returns (uint256 challengeId) {
        (,challengeId, ,) = abi.decode(action, (uint256,uint256,address,bytes));
    }

    function getTargetMethod(
        bytes calldata /*proof*/, 
        bytes calldata action
    ) external pure override returns (address target, bytes memory method) {
        (, ,target, method) = abi.decode(action, (uint256,uint256,address,bytes));
    }

    function getMaterial(
        bytes calldata proof, 
        bytes calldata /*action*/,
        address        /*context*/
    ) external pure override returns (uint256) {
        (uint256[] memory inputs, , ,) 
                        = abi.decode(proof, (uint256[],uint256[2],uint256[2][2],uint256[2]));
        require(inputs.length == 3, "invalid input length");
        bytes memory knowledge = abi.encode(inputs[0], inputs[1]);
        return uint256(keccak256(knowledge));
    }
}