// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "../interfaces/ICircuitValidator.sol";
import "../interfaces/IVerifier.sol";
import "../lib/Poseidon.sol";
/**
    The format of action:|userID|Nonce|Target|Action|
*/

contract CredentialEcdsaValidator is ICircuitValidator, Initializable{
    IVerifier public verifier;

    function initialize(
        address _verifier
    ) public initializer {
        verifier = IVerifier(_verifier);
    }

    function verify(
        uint256                 id,
        uint256[]      calldata inputs,
        uint256[2]     calldata a,
        uint256[2][2]  calldata b,
        uint256[2]     calldata c,
        bytes          calldata action
    ) external view override returns (bool) {
        // verify that zkp is valid
        require(inputs.length == 3, "invalid input length");
        bytes32 msgHash = keccak256(action);
        require(inputs[2] == PoseidonUnit1L.poseidon([uint256(msgHash)]), "invalid hash");
        require(id == _getUserId(action), "invalid user");
        return verifier.verifyProof(a, b, c, inputs);
    }

    function getUserId(
        uint256[] calldata /*inputs*/, 
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
        uint256[] calldata /*inputs*/, 
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
        uint256[] calldata /*inputs*/, 
        bytes calldata action
    ) external pure override returns (address target, bytes memory method) {
        (, ,target, method) = abi.decode(action, (uint256,uint256,address,bytes));
    }

    function getMaterial(
        uint256[] calldata inputs, 
        bytes calldata /*action*/
    ) external pure override returns (bytes32) {
        require(inputs.length == 3, "invalid input length");
        bytes memory knowledge = abi.encode(inputs[0], inputs[1]);
        return keccak256(knowledge);
    }
}
