// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../lib/GenesisUtils.sol";
import "../lib/Poseidon.sol";
import "../interfaces/ICircuitValidator.sol";
import "../interfaces/IZKPVerifier.sol";
import "../factory/IShadowFactory.sol";
// import "hardhat/console.sol";

abstract contract ZKPVerifier is IZKPVerifier, Ownable {
    event Transfer_Requested (
        uint64 requestId,
        address validator,
        uint256 schema
    );

    mapping(uint64 => ICircuitValidator.CircuitQuery) public requestQueries;
    mapping(uint64 => ICircuitValidator) public requestValidators;

    uint64[] public supportedRequests;

    function setZKPRequest(
        uint64 requestId,
        ICircuitValidator validator,
        uint256 schema,
        uint256 claimPathKey,
        uint256 operator,
        uint256[] calldata value
    ) public override onlyOwner returns (bool) {
        uint256 valueHash = PoseidonFacade.poseidonSponge(value);
        // only merklized claims are supported (claimPathNotExists is false, slot index is set to 0 )
        uint256 queryHash = PoseidonFacade.poseidon6(
            [schema, 0, operator, claimPathKey, 0, valueHash]
        );

        return
            setZKPRequestRaw(
                requestId,
                validator,
                schema,
                claimPathKey,
                operator,
                value,
                queryHash
            );
    }

    function setZKPRequestRaw(
        uint64 requestId,
        ICircuitValidator validator,
        uint256 schema,
        uint256 claimPathKey,
        uint256 operator,
        uint256[] calldata value,
        uint256 queryHash
    ) public override onlyOwner returns (bool) {
        if (requestValidators[requestId] == ICircuitValidator(address(0x00))) {
            supportedRequests.push(requestId);
        }
        requestQueries[requestId].queryHash = queryHash;
        requestQueries[requestId].operator = operator;
        requestQueries[requestId].circuitId = validator.getCircuitId();
        requestQueries[requestId].claimPathKey = claimPathKey;
        requestQueries[requestId].schema = schema;
        requestQueries[requestId].value = value;
        requestValidators[requestId] = validator;
        emit Transfer_Requested(requestId, address(validator), schema);
        return true;
    }

    function submitZKPResponse(
        uint64 requestId,
        uint256[] calldata inputs,
        uint256[2] calldata a,
        uint256[2][2] calldata b,
        uint256[2] calldata c,
        address proxied,
        bytes calldata method
    ) external override returns (bool){
        ICircuitValidator validator =  requestValidators[requestId];
        require(
            validator != ICircuitValidator(address(0)),
            "validator is not set for this request id"
        );

        ICircuitValidator.CircuitQuery memory query = requestQueries[requestId];
        require(
            query.schema != 0,
            "query is not set for this request id"
        );

        _beforeProofSubmit(requestId, inputs, validator);
        
        require(
            validator.verify(
                inputs,
                a,
                b,
                c,
                query.queryHash
            ),
            "proof response is not valid"
        );

        //proofs[msg.sender][requestId] = true; // user provided a valid proof for request
        _afterProofSubmit(requestId, inputs, validator, proxied, method);
        return true;
    }

    function getZKPRequest(uint64 requestId)
        external
        view
        override
        returns (ICircuitValidator.CircuitQuery memory)
    {
        return requestQueries[requestId];
    }

    function getSupportedRequests()
        external
        view
        returns (uint64[] memory arr)
    {
        return supportedRequests;
    }

    /**
     * @dev Hook that is called before any proof response submit
     */
    function _beforeProofSubmit(
        uint64 requestId,
        uint256[] calldata inputs,
        ICircuitValidator validator
    ) internal virtual {}

    /**
     * @dev Hook that is called after any proof response submit
     */
    function _afterProofSubmit(
        uint64 requestId,
        uint256[] calldata inputs,
        ICircuitValidator validator,
        address proxied,
        bytes calldata method
    ) internal virtual {}

    function _initialize(
        IShadowFactory _factory
    ) internal virtual {}
}