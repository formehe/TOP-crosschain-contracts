// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "./CredentialAtomicQueryValidator.sol";

contract CredentialAtomicQueryMTPValidator is CredentialAtomicQueryValidator {
    string constant CIRCUIT_ID = "credentialAtomicQueryMTPV2OnChain";
    uint256 constant CHALLENGE_INDEX = 4;

    function getCircuitId() external pure override returns (string memory id) {
        return CIRCUIT_ID;
    }

    function getChallengeInputIndex() external pure override returns (uint256 index) {
        return CHALLENGE_INDEX;
    }

    function getUserIdInputIndex() external pure override returns (uint256 index) {
        return 1;
    }

    function _getInputValidationParameters(
        uint256[] calldata inputs
    ) internal pure override returns (uint256[] memory) {
        uint256[] memory params = new uint256[](5);
        params[0] = inputs[2]; // queryHash
        params[1] = inputs[5]; // gistRoot
        params[2] = inputs[6]; // issuerId
        params[3] = inputs[7]; // issuerClaimIdenState
        params[4] = inputs[9]; // issuerClaimNonRevState
        return params;
    }
}
