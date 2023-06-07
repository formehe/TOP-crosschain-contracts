// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IShadowFactory {
    function clone() external returns (address _shadowWallet);
}