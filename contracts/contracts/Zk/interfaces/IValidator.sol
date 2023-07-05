// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

interface IValidator {
    function verify(
        uint256        id,
        bytes calldata proof,
        bytes calldata action,
        address        context
    ) external view returns (bool r);

    function getID() external pure returns (bytes32);

    function getUserId(
        bytes calldata proof,
        bytes calldata action
    ) external pure returns (uint256);

    function getChallengeId(
        bytes calldata proof,
        bytes calldata action
    ) external pure returns (uint256);

    function getTargetMethod(
        bytes calldata /*proof*/,
        bytes calldata action
    ) external pure returns (address target, bytes memory method);

    function getMaterial(
        bytes calldata proof,
        bytes calldata action,
        address        context
    ) external view returns (uint256);
}
