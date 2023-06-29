// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

interface ICircuitValidator {
    function verify(
        uint256          id,
        uint256[] calldata inputs,
        uint256[2] calldata a,
        uint256[2][2] calldata b,
        uint256[2] calldata c,
        bytes calldata action
    ) external view returns (bool r);

    function getUserId(
        uint256[] calldata inputs, 
        bytes calldata action
    ) external pure returns (uint256);

    function getChallengeId(
        uint256[] calldata inputs, 
        bytes calldata action
    ) external pure returns (uint256);

    function getTargetMethod(
        uint256[] calldata /*inputs*/, 
        bytes calldata action
    ) external pure returns (address target, bytes memory method);

    function getMaterial(
        uint256[] calldata inputs, 
        bytes calldata action
    ) external pure returns (bytes32);
}
