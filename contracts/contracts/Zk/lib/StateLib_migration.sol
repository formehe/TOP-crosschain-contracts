// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

library StateLib_migration {
    struct Entry {
        uint256 state;
        uint256 timestamp;
        uint256 block;
    }

    struct Data {
        mapping(uint256 => Entry[]) stateEntries;
        mapping(uint256 => mapping(uint256 => uint256[])) stateIndexes;
        uint256[48] __gap;
    }

    function addStateWithTimestampAndBlock(
        Data storage self,
        uint256 id,
        uint256 state,
        uint256 timestamp,
        uint256 blockNumber
    ) external {
        if (timestamp == 0 || blockNumber == 0) {
            require(self.stateEntries[id].length == 0, "Genesis state must be the first state of identity");
        }
        self.stateEntries[id].push(Entry(state, timestamp, blockNumber));
        self.stateIndexes[id][state].push(self.stateEntries[id].length - 1);
    }
}
