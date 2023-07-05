// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IShadowFactory {
    function clone(
        address        _walletProxy,
        uint256        id,
        uint256        proofKind,
        bytes calldata proof,
        bytes calldata action
    ) external returns (address _shadowWallet);

    function getValidator(uint256 proofKind) external view returns (address);
}