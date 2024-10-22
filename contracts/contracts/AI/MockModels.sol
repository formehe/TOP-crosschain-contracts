// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Models.sol";

contract MockModels is Models {
    constructor(address _aiTokenAddress, address _owner) Models(_aiTokenAddress, _owner) {
    }

    // 计算奖励的 AI Token（示例公式）
    function calculateUploadReward(
        uint256[] memory parameters
    ) public pure returns (uint256) {
        return _calculateUploadReward(parameters);
    }

    function calculateUsingReward(
        uint256[] memory parameters
    ) public pure returns (uint256) {
        return _calculateUsingReward(parameters);
    }
}