// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/governance/utils/IVotes.sol";

contract ScalableVotes is IVotes {
    struct Checkpoint {
        uint256 fromBlock;
        uint256 votes;
    }

    mapping(address => uint256) private checkpoints;
    Checkpoint private totalSupplyCheckpoint;
    address private governor;

    modifier onlyGovernance() {
        require(msg.sender == governor, "Governor: onlyGovernance");
        _;
    }

    constructor(address[] memory _voters, address _governor) {
        require(_voters.length >= 3, "number of voters must more than 3");
        require(_governor.code.length > 0, "invalid governor");
        for (uint256 i = 0; i < _voters.length; i++) {
            require(_voters[i] != address(0), "invalid voter");
            require(checkpoints[_voters[i]] == 0, "voter can not be repeated");
            checkpoints[_voters[i]] = block.number;
        }

        _totalSupplyCheckpoint = Checkpoint(block.number, voters.length);
        governor = _governor;
    }

    function getVotes(address account) override external view returns (uint256) {
        return _checkpoints[account];
    }

    function getPastVotes(address account, uint256 blockNumber) override external view returns (uint256) {
        require(blockNumber < block.number, "block not yet mined");
        return _checkpoints[account];
    }

    function getPastTotalSupply(uint256 blockNumber) override external view returns (uint256) {
        require(blockNumber < block.number, "block not yet mined");
        return _totalSupplyCheckpoint.votes;
    }

    function mint(address[] calldata voters) external onlyGovernance {

    }

    function delegates(address /*account*/) override external pure returns (address) {
        require(false, "not support");
    }

    function delegate(address /*delegatee*/) override external pure{
        require(false, "not support");
    }

    function delegateBySig(
        address /*delegatee*/,
        uint256 /*nonce*/,
        uint256 /*expiry*/,
        uint8 /*v*/,
        bytes32 /*r*/,
        bytes32 /*s*/
    ) override external pure {
        require(false, "not support");
    }
}