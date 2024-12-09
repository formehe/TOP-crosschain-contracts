// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./ShareDataType.sol";
import "hardhat/console.sol";

contract NodesRegistry is Initializable {
    using EnumerableSet for EnumerableSet.AddressSet;
    struct Node {
        address identifier;
        uint256 registrationTime;
        uint256 unRegistrationTime;
        bool    active;
        ComputeAvailable[] gpus;
        address wallet;
    }

    struct ComputeAvailable {
        string  gpuType;
        uint256 totalNum;
        uint256 used;
    }

    mapping(address => Node) private nodes;
    mapping(address => mapping(string => uint256)) public gpuTypeOfNodes;//gpu index
    mapping(string => ComputeAvailable) public gpuSummary;
    EnumerableSet.AddressSet private identifiers;
    mapping(address => address) private authorizations;
    address public allocator;

    event NodeRegistered(address indexed miner, address identifier, uint256 time);
    event NodeDeregistered(address indexed identifier, uint256 time);
    event authorized(address indexed owner, address indexed spender);

    function _nodesRegistry_initialize(
        address[]   calldata _identifiers,
        address[]   calldata _wallets,
        string[][]  calldata _gpuTypes,
        uint256[][] calldata _gpuNums,
        address     _allocator
    ) internal onlyInitializing {
        require((_identifiers.length == _wallets.length)
            && (_identifiers.length == _gpuTypes.length)
            && (_identifiers.length == _gpuNums.length), "Invalid initialize parameters");
        
        for (uint256 i = 0; i < _identifiers.length; i++) {
            _registerNode(_wallets[i], _identifiers[i], _gpuTypes[i], _gpuNums[i]);
        }

        require(_allocator != address(0), "Invalid allocator");
        allocator = _allocator;
    }

    function registerNode(
        address   wallet,
        string[]  calldata gpuTypes,
        uint256[] calldata gpuNums
    ) public {
        _registerNode(wallet, msg.sender, gpuTypes, gpuNums);
    }

    function deregisterNode(
    ) public {
        _deregisterNode(msg.sender);
        _cancel(msg.sender);
    }

    function deregisterNode(
        address authorizer
    ) public {
        require(_check(authorizer, msg.sender), "Not authorized");
        _cancel(authorizer);
        _deregisterNode(authorizer); 
    }

    // approve
    function approve(
        address authorizedPerson
    ) public returns (bool) {
        _approve(msg.sender, authorizedPerson);
        return true;
    }

    function _approve(
        address owner,
        address authorizedPerson
    ) internal {
        require(owner != address(0), "Invalid owner");
        require(authorizedPerson != address(0), "Invalid authorized person");
        Node storage node = nodes[owner];
        require(node.active, "None such node");
        authorizations[owner] = authorizedPerson;
        emit authorized(owner, authorizedPerson);
    }

    function _cancel(        
        address owner
    ) internal {
        require(owner != address(0), "Invalid owner");
        authorizations[owner] = address(0);
        emit authorized(owner, address(0));
    }

    function _check(
        address owner,
        address authorizedPerson
    ) internal view returns (bool){
        if (authorizations[owner] == authorizedPerson) {
            return true;
        }

        return false;
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

    function check(
        address identifier
    ) view public returns(bool) {
        Node storage node = nodes[identifier];
        if (node.active) {
            return true;
        }

        return false;
    }

    function allocGPU(
        uint256 startIndex,
        string[] calldata gpuTypes,
        uint256[] calldata gpuNums
    ) external returns(NodeComputeUsed[] memory gpuNodes, uint256 len) {
        require(msg.sender == allocator, "Only for allocator");
        uint256[] memory needGpus = new uint256[](gpuTypes.length);
        uint256 totalNeedNums;
        for (uint256 j = 0; j < gpuTypes.length; j++) {
            ComputeAvailable storage available = gpuSummary[gpuTypes[j]];
            require((available.totalNum - available.used) >= gpuNums[j], "gpu is not enough");
            available.used += gpuNums[j];
            needGpus[j] = gpuNums[j];
            totalNeedNums += gpuNums[j];
        }

        gpuNodes = new NodeComputeUsed[](identifiers.length() * gpuTypes.length);
        for (uint256 i = startIndex; i < startIndex + identifiers.length() && totalNeedNums > 0; i++) {
            address id = identifiers.at(i % identifiers.length());
            Node storage node = nodes[id];
            if (!node.active) {
                continue;
            }

            mapping(string => uint256) storage gpuTypeOfNode = gpuTypeOfNodes[id];
            for (uint256 j = 0; j < gpuTypes.length && totalNeedNums > 0; j++) {
                if (needGpus[j] <= 0) {
                    continue;
                }

                uint256 index = gpuTypeOfNode[gpuTypes[j]];
                if (index == 0) {
                    continue;
                }

                ComputeAvailable storage available = node.gpus[index - 1];
                uint256 remainNum = available.totalNum - available.used;
                if (remainNum <= 0) {
                    continue;
                }

                gpuNodes[len].identifier = id;
                gpuNodes[len].gpuType = gpuTypes[j];
                
                if (needGpus[j] > remainNum) {
                    needGpus[j] -= remainNum;
                    totalNeedNums -= remainNum;
                    gpuNodes[len].used = remainNum;
                    available.used = available.totalNum;
                } else {
                    available.used += needGpus[j];
                    totalNeedNums  -= needGpus[j];
                    gpuNodes[len].used = needGpus[j];
                    needGpus[j] = 0;
                }
                len += 1;
            }
        }
    }

    function freeGPU(
        NodeComputeUsed[] calldata gpuNodes
    ) external {
        require(msg.sender == allocator, "Only for allocator");
        for (uint256 i = 0; i < gpuNodes.length; i++) {
            address identifier = gpuNodes[i].identifier;
            require(identifier != address(0), "Invalid identifier");
            Node storage node = nodes[identifier];
            if (node.active) {
                mapping(string => uint256) storage gpuTypeOfNode = gpuTypeOfNodes[identifier];
                uint256 index = gpuTypeOfNode[gpuNodes[i].gpuType];
                require(index > 0, "Invalid gpu type");
                node.gpus[index - 1].used -= gpuNodes[i].used;
                ComputeAvailable storage available = gpuSummary[gpuNodes[i].gpuType];
                available.used -= gpuNodes[i].used;
            }
        }
    }

    function _deregisterNode(
        address identifier
    ) internal {
        require(identifier != address(0), "Invalid identifier");
        Node storage node = nodes[identifier];
        require(node.identifier != address(0), "Identifier not exist");
        require(node.active == true, "Identifier has been deregistered");
        node.active = false;
        for (uint256 i = 0; i < node.gpus.length; i++) {
            ComputeAvailable storage available = node.gpus[i];
            gpuSummary[available.gpuType].totalNum -= available.totalNum;
            gpuSummary[available.gpuType].used -= available.used;
            available.used = 0;
        }
        node.unRegistrationTime = block.timestamp;
        emit NodeDeregistered(identifier, block.timestamp);
    }

    function _registerNode(
        address wallet,
        address identifier,
        string[]  calldata gpuTypes,
        uint256[] calldata gpuNums
    ) internal {
        require(gpuTypes.length == gpuNums.length, "Invalid GPU data");
        require(wallet != address(0) && (identifier != address(0)), "Invalid wallet or identifier");
        Node storage node = nodes[identifier];
        if (node.identifier == address(0)) {
            mapping(string => uint256) storage gpuTypeOfNode = gpuTypeOfNodes[identifier];
            node.identifier = identifier;
            node.registrationTime = block.timestamp;
            node.unRegistrationTime = 0;
            node.active = true;
            node.wallet = wallet;
            for (uint256 i = 0; i < gpuTypes.length; i++) {
                node.gpus.push(ComputeAvailable({
                    gpuType: gpuTypes[i],
                    totalNum: gpuNums[i],
                    used: 0
                }));

                gpuTypeOfNode[gpuTypes[i]] = node.gpus.length;
                gpuSummary[gpuTypes[i]].totalNum += gpuNums[i];
                gpuSummary[gpuTypes[i]].gpuType = gpuTypes[i];
            }
            identifiers.add(identifier);
        } else if(!node.active) {
            node.active = true;
            node.registrationTime = block.timestamp;
            node.unRegistrationTime = 0;
            for (uint256 i = 0; i < node.gpus.length; i++) {
                ComputeAvailable storage available = node.gpus[i];
                gpuSummary[available.gpuType].totalNum += available.totalNum;
            }
        } else {
            revert("Identifier exist");
        }

        emit NodeRegistered(wallet, identifier, block.timestamp);
    }
}