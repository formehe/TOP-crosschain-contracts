// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "./CredentialAtomicQueryValidator.sol";

contract CredentialAtomicQuerySigValidator is CredentialAtomicQueryValidator {
    string constant CIRCUIT_ID = "credentialAtomicQuerySig";
    uint256 constant CHALLENGE_INDEX = 1;

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
        params[2] = inputs[4]; // issuerId
        params[3] = inputs[2]; // issuerClaimAuthState
        params[4] = inputs[6]; // issuerClaimNonRevState
        return params;
    }

    function _checkInput(
        uint256[] calldata inputs,
        uint256 /*queryHash*/
    ) internal view override {
        //destrcut values from result array
        uint256[] memory validationParams = _getInputValidationParameters(inputs);
        uint256 issuerId = validationParams[2];
        uint256 issuerClaissuerClaimState = validationParams[3];
        _checkStateContractOrGenesis(issuerId, issuerClaissuerClaimState);
        uint256 issuerClaimNonRevState = validationParams[4];
        _checkClaimNonRevState(issuerId, issuerClaimNonRevState);
    }
}
