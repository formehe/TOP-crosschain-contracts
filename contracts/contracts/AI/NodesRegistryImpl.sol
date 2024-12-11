// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./NodesRegistry.sol";

contract NodesRegistryImpl is NodesRegistry {
    function nodesRegistryImpl_initialize(
        address[] calldata _identifiers,
        string[]  calldata _aliasIdentifiers,
        address[] calldata _wallets,
        string[][]  calldata _gpuTypes,
        uint256[][] calldata _gpuNums,
        address _allocator
    ) external initializer {
        require((_identifiers.length == _wallets.length)
            && (_identifiers.length == _gpuTypes.length)
            && (_identifiers.length == _gpuNums.length)
            && (_identifiers.length == _aliasIdentifiers.length), "Invalid initialize parameters");
            
        _nodesRegistry_initialize(_identifiers, _aliasIdentifiers, _wallets, _gpuTypes, _gpuNums, _allocator);
    }

    function _checkRegister(address candidate) internal override {
        _active(candidate);
    }
}