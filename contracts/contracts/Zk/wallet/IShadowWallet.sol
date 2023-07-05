// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IShadowWallet {
    function initialize(
        address        _caller, 
        address        _verifer,
        uint256        id,
        uint256        proofKind,
        bytes calldata proof,
        bytes calldata action
    ) external;

    function execute(
        uint256        id,        
        uint256        proofKind,
        bytes calldata proof,
        bytes calldata action,
        address        context
    ) external returns (bytes memory);

    function changeMaterial(
        uint256        id,
        uint256        proofKind,
        bytes calldata oldProof,
        bytes calldata proof,
        bytes calldata action,
        address        context
    ) external;

    function grant(
        uint256        id,
        uint256        proofKind,
        bytes calldata proof,
        uint256        grantedProofKind,
        bytes calldata grantedProof,
        bytes calldata action,
        address        context
    ) external;

    function revoke(
        uint256        id,
        uint256        proofKind,
        bytes calldata proof,
        uint256        revokedProofKind,
        bytes calldata action,
        address        context
    ) external;
}