// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "../common/AdminControlledUpgradeable.sol";

contract AIChainConfiguration is AdminControlledUpgradeable {
    mapping(address => uint256[]) public eventsInContract;
    mapping(uint256 => address) public eventsOfContract;
    event EventRegistered(address indexed contractAddress, uint256 indexed eventId);
    event EventDeregistered(address indexed contractAddress, uint256 indexed eventId);
    constructor() {
    }

    function registerEvents(
        uint256 eventId,
        address contractAddress
    ) external {
        require(eventsOfContract[eventId] == address(0), "Event has been registered");
        eventsOfContract[eventId] = contractAddress;
        emit EventRegistered(contractAddress, eventId);
    }

    function deregisterEvents(
        uint256 eventId
    ) external {
        address contractAddress = eventsOfContract[eventId];
        require(contractAddress != address(0), "Event has not been registered");
        
        eventsOfContract[eventId] = address(0);
        emit EventDeregistered(contractAddress, eventId);
    }
}