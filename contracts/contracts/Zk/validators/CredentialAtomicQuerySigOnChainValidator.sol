// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "./CredentialAtomicQueryValidator.sol";

contract credentialAtomicQuerySigV2OnChainValidator is CredentialAtomicQueryValidator {
    string constant CIRCUIT_ID = "credentialAtomicQuerySigV2OnChain";
    uint256 constant CHALLENGE_INDEX = 5;

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
        params[1] = inputs[6]; // gistRoot
        params[2] = inputs[7]; // issuerId
        params[3] = inputs[3]; // issuerClaimAuthState
        params[4] = inputs[9]; // issuerClaimNonRevState
        return params;
    }

    function _checkInput(
        uint256[] calldata inputs,
        uint256 queryHash
    )internal view override {
        //destrcut values from result array
        uint256[] memory validationParams = _getInputValidationParameters(inputs);
        uint256 inputQueryHash = validationParams[0];
        require(inputQueryHash == queryHash, "query hash does not match the requested one");

        uint256 gistRoot = validationParams[1];
        _checkGistRoot(gistRoot);
        uint256 issuerId = validationParams[2];
        uint256 issuerClaissuerClaimState = validationParams[3];
        _checkStateContractOrGenesis(issuerId, issuerClaissuerClaimState);
        uint256 issuerClaimNonRevState = validationParams[4];
        _checkClaimNonRevState(issuerId, issuerClaimNonRevState);
    }
}
