// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IShadowWallet {
    function initialize(
        address _caller, 
        address _verifer,
        uint256 id,
        uint256[] memory inputs,
        uint256[2] calldata a,
        uint256[2][2] calldata b,
        uint256[2] calldata c,
        bytes calldata action
    ) external;

    function execute(
        uint256            id,        
        uint256[] memory inputs,
        uint256[2] calldata a,
        uint256[2][2] calldata b,
        uint256[2] calldata c,
        bytes calldata action
    ) external returns (bytes memory);

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
    ) external;
}