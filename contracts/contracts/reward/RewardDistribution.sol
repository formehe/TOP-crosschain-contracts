// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../common/Roles.sol";

contract RewardDistribution is UUPSUpgradeable, /*AccessControl,*/ Initializable {
    IERC20 public reward;
    address public dao;
    address public owner;
    mapping(address => bool) public provers;
    mapping(uint256 => bool) public proofs;

    event ProverBound(address prover);
    event ProverUnbound(address prover);
    event WorkProofUsed(uint256 nonce, address trasfered, uint256 amount);

    function initialize(address _reward, address _dao, address _owner) external initializer {
        require(_reward.code.length > 0, "not contract address");
        require(_dao.code.length > 0, "not contract address");
        require(_owner != address(0), "invalid owner");
        reward = IERC20(_reward);
        dao = _dao;
        owner = _owner;
    }

    function bindWorkProver(address[] calldata erasedWorkProver, address[] calldata workProver) external{
        require(msg.sender == dao, "not dao");
        
        for (uint256 i = 0; i < erasedWorkProver.length; i++) {
            delete provers[erasedWorkProver[i]];
            emit ProverUnbound(erasedWorkProver[i]);
        }

        for (uint256 i = 0; i < workProver.length; i++) {
            provers[workProver[i]] = true;
            emit ProverBound(workProver[i]);
        }
    }

    function claim(uint256 nonce, address worker, uint256 workload) external returns(bool) {
        require(provers[msg.sender], "not prover");
        require(!proofs[nonce], "proof has been used");
        proofs[nonce] = true;
        emit WorkProofUsed(nonce, worker, workload);
        return reward.transfer(worker, workload);
    }

    function _authorizeUpgrade(address newImplementation) internal view override {
        (newImplementation);
        require(msg.sender == owner, "not owner");
    }
}