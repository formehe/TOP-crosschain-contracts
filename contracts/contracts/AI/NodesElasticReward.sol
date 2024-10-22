// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IReward.sol";
contract NodesElasticReward is IReward {
    constructor(address _nodes, uint256 settlementCircleId) {
    }

    function distributeRewards(uint256 detectPeriodId, uint256 totalAsset) external override {
    }
}