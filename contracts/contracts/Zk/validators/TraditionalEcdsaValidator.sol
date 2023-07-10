// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "../interfaces/IValidator.sol";

/**
    The format of action:|userID|Nonce|Target|Action|
*/

contract TraditionalEcdsaValidator is IValidator, Initializable{
    function initialize(
        address /*_verifier*/
    ) public initializer {
    }

    function verify(
        uint256                 id,
        bytes          calldata proof,
        bytes          calldata action,
        address                 context
    ) external pure override returns (bool) {
        // verify that zkp is valid
        (address owner, uint8 v, bytes32 r, bytes32 s) = abi.decode(proof, (address,uint8,bytes32,bytes32));
        bytes32 msgHash = keccak256(action);
        address recoveredOwner = ECDSA.recover(ECDSA.toEthSignedMessageHash(msgHash), v, r, s);
        require(id == _getUserId(action), "invalid user");
        require(context == recoveredOwner, "invalid context");
        if (owner != recoveredOwner) {
            return false;
        }
        return true;
    }

    function getID() external pure override returns (bytes32) {
        return keccak256("TraditionalEcdsaValidator");
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
        (address owner, , , ) = abi.decode(proof, (address,uint8,bytes32,bytes32));
        return uint256(uint160(owner));
    }
}