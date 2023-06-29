// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IShadowFactory {
    function clone(
        address _walletProxy,
        uint256 id,
        uint256[] calldata inputs,
        uint256[2] calldata a,
        uint256[2][2] calldata b,
        uint256[2] calldata c,
        bytes calldata action
    ) external returns (address _shadowWallet);

    function getValidator() external view returns (address);
}