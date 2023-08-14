// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../common/Roles.sol";
import "../common/AdminControlledUpgradeable.sol";

contract RewardDistribution is UUPSUpgradeable, AdminControlledUpgradeable {
    IERC20  public reward;
    mapping(address => bool) public provers;
    mapping(uint256 => bool) public proofs;
    uint256 constant UNPAUSED_ALL = 0;
    uint256 constant PAUSED_TRANSFER = 1 << 0;
    uint256 public workLoadPercent;

    event ProverBound(address prover);
    event ProverUnbound(address prover);
    event WorkProofUsed(uint256 nonce, address trasfered, uint256 amount);

    function initialize(address _reward, address _dao, address _owner, uint256 _workLoadPercent) external initializer {
        require(_reward.code.length > 0, "not contract address");
        //require(_dao.code.length > 0, "not contract address");
        require(_dao != address(0), "invalid address");
        require(_owner != address(0), "invalid owner");
        require(_workLoadPercent != 0, "invalid work load percent");
        reward = IERC20(_reward);
        
        workLoadPercent = _workLoadPercent;
        AdminControlledUpgradeable._AdminControlledUpgradeable_init(msg.sender, 0xff);
        _setRoleAdmin(ADMIN_ROLE, OWNER_ROLE);
        _setRoleAdmin(CONTROLLED_ROLE, ADMIN_ROLE);
        _setRoleAdmin(DAO_ADMIN_ROLE, ADMIN_ROLE);

        _grantRole(OWNER_ROLE, _owner);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(DAO_ADMIN_ROLE, _dao);
    }

    function bindWorkProver(address[] calldata erasedWorkProver, address[] calldata workProver) external onlyRole(DAO_ADMIN_ROLE){
        for (uint256 i = 0; i < erasedWorkProver.length; i++) {
            require(erasedWorkProver[i] != address(0), "invalid address");
            require(provers[erasedWorkProver[i]], "address is not existed");
            delete provers[erasedWorkProver[i]];
            emit ProverUnbound(erasedWorkProver[i]);
        }

        for (uint256 i = 0; i < workProver.length; i++) {
            require(workProver[i] != address(0), "invalid address");
            require(!provers[workProver[i]], "address is existed");
            provers[workProver[i]] = true;
            emit ProverBound(workProver[i]);
        }
    }

    function claim(uint256 nonce, address worker, uint256 workload) external returns(bool) {
        require(isPause(PAUSED_TRANSFER), "claim is paused");
        require(provers[msg.sender], "not prover");
        require(worker != address(0), "invalid address");
        require(workload != 0, "work load can not be zero");
        require(!proofs[nonce], "proof has been used");
        proofs[nonce] = true;
        // uint256 asset = workload / workLoadPercent;
        emit WorkProofUsed(nonce, worker, workload);
        return reward.transfer(worker, workload);
    }

    function _authorizeUpgrade(address newImplementation) internal view override onlyRole(OWNER_ROLE) {
        (newImplementation);
    }
}