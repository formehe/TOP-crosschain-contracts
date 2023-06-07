// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IShadowWallet {
    function initialize(address _caller) external;
    function forwardCall(address objectContract, bytes memory method) external returns (bytes memory);
}