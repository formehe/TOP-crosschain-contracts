// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ICircuitValidator.sol";
interface IZKPVerifier {
    function setZKPRequest(
        uint64 requestId,
        ICircuitValidator validator,
        uint256 schema,
        uint256 slotIndex,
        uint256 operator,
        uint256[] calldata value
    ) external returns (bool);

    function setZKPRequestRaw(
        uint64 requestId,
        ICircuitValidator validator,
        uint256 schema,
        uint256 slotIndex,
        uint256 operator,
        uint256[] calldata value,
        uint256 queryHash
    ) external returns (bool);

    function submitZKPResponse(
        uint64 requestId,
        uint256[] calldata inputs,
        uint256[2] calldata a,
        uint256[2][2] calldata b,
        uint256[2] calldata c,
        address proxied,
        bytes calldata method
    ) external returns (bool);

    function getZKPRequest(
        uint64 requestId
    ) external returns (ICircuitValidator.CircuitQuery memory);
}