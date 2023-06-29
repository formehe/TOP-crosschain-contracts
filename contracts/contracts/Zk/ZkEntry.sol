// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";
import "./interfaces/ICircuitValidator.sol";
import "./wallet/IShadowWallet.sol";
import "./factory/IShadowFactory.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "hardhat/console.sol";

contract ZkEntry is Initializable{
    event Shadow_Wallet_Created(
        uint256 id,
        address wallet
    );

    event MaterialChanged(
        uint256 id,
        address wallet
    );

    mapping(uint256 => address)  public idMappings;

    IShadowFactory public factory;

    function initialize(
        IShadowFactory _factory
    ) external initializer {
        require(Address.isContract(address(_factory)), "invalid factory");
        factory = _factory;
    }

    function newWallet(
        uint256            id,
        uint256[] memory inputs,
        uint256[2] calldata a,
        uint256[2][2] calldata b,
        uint256[2] calldata c,
        bytes calldata action
    ) external returns (address) {
        require(idMappings[id] == address(0), "id already exist");
        address wallet = factory.clone(address(this), id, inputs, a, b, c, action);
        idMappings[id] = wallet;
        emit Shadow_Wallet_Created(id, wallet);
        return wallet;
    }

    function execute(
        uint256            id,        
        uint256[] memory inputs,
        uint256[2] calldata a,
        uint256[2][2] calldata b,
        uint256[2] calldata c,
        bytes calldata action
    ) external {
        address wallet = idMappings[id];
        require(wallet != address(0), "id not exist");
        IShadowWallet(wallet).execute(id, inputs, a, b, c, action);
    }

    function changeMaterial(
        uint256            id,
        uint256[] memory oldInputs,
        uint256[2] calldata oldA,
        uint256[2][2] calldata oldB,
        uint256[2] calldata oldC,
        uint256[] memory newInputs,
        uint256[2] calldata newA,
        uint256[2][2] calldata newB,
        uint256[2] calldata newC,
        bytes calldata action
    ) external {
        address wallet = idMappings[id];
        require(wallet != address(0), "id not exist");
        IShadowWallet(wallet).changeMaterial(id, oldInputs, oldA, oldB, oldC, newInputs, newA, newB, newC, action);
        emit MaterialChanged(id, wallet);
    }
}