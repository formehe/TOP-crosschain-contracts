// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

struct NodeState {
    uint64  failedCnt;
    uint64  successfulCnt;
    uint128 expectCnt;
    address wallet;
    address identifier;
}

struct NodeComputeUsed {
    address identifier;
    string  gpuType;
    uint256 used;
}