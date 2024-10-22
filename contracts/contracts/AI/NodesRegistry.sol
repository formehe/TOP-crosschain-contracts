// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "../common/AdminControlledUpgradeable.sol";
import "./ShareDataType.sol";

contract NodesRegistry is AdminControlledUpgradeable{
    using EnumerableSet for EnumerableSet.AddressSet;
    struct Node {
        address identifier;
        uint256 registrationTime;
        uint256 unRegistrationTime;
        bool    active;
        address wallet;
    }

    mapping(address => Node) internal nodes;
    EnumerableSet.AddressSet internal identifiers;

    event NodeRegistered(address indexed miner, address identifier, uint256 time);
    event NodeDeregistered(address indexed identifer, uint256 time);

    constructor(
        address[] memory _identifiers, 
        address[] memory _wallets,
        address _owner
    ) initializer{
        require(_identifiers.length == _wallets.length, "Identifier length and wallet account length is not match");
        require(_owner != address(0), "Invalid owner");
        for (uint256 i = 0; i < _identifiers.length; i++) {
            _registerNode(_wallets[i], _identifiers[i]);
        }

        _setRoleAdmin(ADMIN_ROLE, OWNER_ROLE);
        _setRoleAdmin(CONTROLLED_ROLE, ADMIN_ROLE);

        _grantRole(OWNER_ROLE, _owner);
        _grantRole(ADMIN_ROLE, msg.sender);

        AdminControlledUpgradeable._AdminControlledUpgradeable_init(msg.sender, 0xff);
    }

    function registerNode(
        address identifier,
        address wallet
    ) public onlyRole(CONTROLLED_ROLE) {
        _registerNode(wallet, identifier);
    }

    function deregisterNode(
        address identifier
    ) public onlyRole(CONTROLLED_ROLE) {
        _deregisterNode(identifier);
    }

    function at(
        uint256 index
    ) public  view returns(Node memory node) {
        address id = identifiers.at(index);
        return nodes[id];
    }

    function get(
        address identifier
    ) view public returns(Node memory node) {
        node = nodes[identifier];
        return node;
    }

    function length() view public returns(uint256) {
        return identifiers.length();
    }

    function _deregisterNode(
        address identifier
    ) internal {
        require(identifier != address(0), "Invalid identify");
        Node storage node = nodes[identifier];
        require(node.identifier != address(0), "Identifier not exist");
        require(node.active == true, "Identifier has been deregistered");
        node.active = false;
        node.unRegistrationTime = block.timestamp;
        emit NodeDeregistered(identifier, block.timestamp);
    }

    function _registerNode(
        address wallet,
        address identifier
    ) internal {
        require(wallet != address(0) && (identifier != address(0)), "Invalid wallet or identifier");
        Node storage node = nodes[identifier];
        if (node.identifier == address(0)) {
            nodes[identifier] = Node({
                identifier: identifier,
                registrationTime: block.timestamp,
                unRegistrationTime: 0,
                active: true,
                wallet: wallet
            });
            identifiers.add(identifier);
        } else if(!node.active) {
            node.active = true;
            node.registrationTime = block.timestamp;
            node.unRegistrationTime = 0;
        } else {
            revert("Identifier exist");
        }

        emit NodeRegistered(wallet, identifier, block.timestamp);
    }
}