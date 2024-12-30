// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./ShareDataType.sol";

abstract contract NodesRegistry is Initializable {
    using EnumerableSet for EnumerableSet.AddressSet;
    struct Node {
        address identifier;
        string  aliasIdentifier;
        uint256 registrationTime;
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
    mapping(string => address) private aliasNodes;
    mapping(address => mapping(string => uint256)) public gpuTypeOfNodes;//gpu index
    mapping(string => ComputeAvailable) public gpuSummary;
    EnumerableSet.AddressSet private identifiers;
    mapping(address => address) private authorizations;
    address public allocator;

    event NodeRegistered(address indexed wallet, address identifier, uint256 time, string aliasIdentifier);
    event NodeActived(address indexed wallet, address identifier, uint256 time, string aliasIdentifier);
    event NodeDeregistered(address indexed identifier, uint256 time, string aliasIdentifier);
    event Authorized(address indexed owner, address indexed spender);

    function _nodesRegistry_initialize(
        address[]   calldata _identifiers,
        string[]    calldata _aliasIdentifiers,
        address[]   calldata _wallets,
        string[][]  calldata _gpuTypes,
        uint256[][] calldata _gpuNums,
        address     _allocator
    ) internal onlyInitializing {
        require((_identifiers.length == _wallets.length)
            && (_identifiers.length == _gpuTypes.length)
            && (_identifiers.length == _gpuNums.length)
            && (_identifiers.length == _aliasIdentifiers.length), "Invalid initialize parameters");
        
        for (uint256 i = 0; i < _identifiers.length; i++) {
            _registerNode(_wallets[i], _identifiers[i], _aliasIdentifiers[i], _gpuTypes[i], _gpuNums[i]);
            _active(_identifiers[i]);
        }

        require(_allocator != address(0), "Invalid allocator");
        allocator = _allocator;
    }

    function registerNode(
        address            wallet,
        string    calldata aliasIdentifier,
        string[]  calldata gpuTypes,
        uint256[] calldata gpuNums
    ) public {
        _registerNode(wallet, msg.sender, aliasIdentifier, gpuTypes, gpuNums);
        _checkRegister(wallet);
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
        emit Authorized(owner, authorizedPerson);
    }

    function _cancel(
        address owner
    ) internal {
        require(owner != address(0), "Invalid owner");
        authorizations[owner] = address(0);
        emit Authorized(owner, address(0));
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
        string memory aliasIdentifier = node.aliasIdentifier;
        for (uint256 i = 0; i < node.gpus.length; i++) {
            ComputeAvailable storage available = node.gpus[i];
            gpuSummary[available.gpuType].totalNum -= available.totalNum;
            gpuSummary[available.gpuType].used -= available.used;
            available.used = 0;
        }

        delete aliasNodes[aliasIdentifier];
        delete nodes[identifier];
        identifiers.remove(identifier);

        emit NodeDeregistered(identifier, block.timestamp, aliasIdentifier);
    }

    function _registerNode(
        address wallet,
        address identifier,
        string  calldata aliasIdentifier,
        string[]  calldata gpuTypes,
        uint256[] calldata gpuNums
    ) internal {
        require(gpuTypes.length == gpuNums.length && gpuNums.length != 0, "Invalid GPU data");
        require(wallet != address(0) && (identifier != address(0)) 
            && (bytes(aliasIdentifier).length > 0), "Invalid wallet or identifier");

        Node storage node = nodes[identifier];
        require(node.identifier == address(0), "Identifier exist");
        require(aliasNodes[aliasIdentifier] == address(0), "Alias identifier exist");
        
        mapping(string => uint256) storage gpuTypeOfNode = gpuTypeOfNodes[identifier];
        node.identifier = identifier;
        node.registrationTime = block.timestamp;
        node.wallet = wallet;
        node.aliasIdentifier = aliasIdentifier;

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
        aliasNodes[aliasIdentifier] = identifier;

        emit NodeRegistered(wallet, identifier, block.timestamp, aliasIdentifier);
    }

    function _active(
        address identifier
    ) internal {
        Node storage node = nodes[identifier];
        require(node.identifier != address(0), "Identifier not exist");
        if (!node.active) {
            node.active = true;
            emit NodeActived(node.wallet, node.identifier, block.timestamp, node.aliasIdentifier);
        }
    }

    function _checkRegister(
        address candidate
    ) internal virtual;
}