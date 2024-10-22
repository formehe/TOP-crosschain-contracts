// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract AIToken2 is ERC20, Ownable {
    // 兑换比例，例如 1 法币 = 100 AI Token
    uint256 public exchangeRate;

    // 在线奖励的锁定周期（以秒为单位）
    uint256 public rewardLockPeriod;

    // 记录算力节点的在线奖励
    struct Miner {
        uint256 onlineRewards; // 当前在线奖励
        uint256 lastRewardCycle; // 上一次奖励的周期
        uint256 lastClaimedCycle; // 上一次领取的周期
    }

    mapping(address => Miner) public miners; // 存储每个算力节点的信息

    event TokensMinted(address indexed user, uint256 amount);
    event TokensBurned(address indexed user, uint256 amount);
    event OnlineRewardClaimed(address indexed miner, uint256 amount);

    constructor(
        uint256 _initialSupply, 
        uint256 _exchangeRate, 
        uint256 _rewardLockPeriod
    ) ERC20("AI Token", "AIT") {
        _mint(msg.sender, _initialSupply); // 初始铸造给合约拥有者
        exchangeRate = _exchangeRate; // 设置兑换比例
        rewardLockPeriod = _rewardLockPeriod; // 设置奖励锁定周期
    }

    // 用户充值：业务平台调用该函数铸造相应的 AI Token
    function mintTokens(
        uint256 fiatAmount
    ) external onlyOwner {
        uint256 tokenAmount = fiatAmount * exchangeRate; // 计算相应的 AI Token 数量
        _mint(msg.sender, tokenAmount);
        emit TokensMinted(msg.sender, tokenAmount);
    }

    // 用户提现：销毁相应的 AI Token
    function burnTokens(
        uint256 amount
    ) external {
        require(balanceOf(msg.sender) >= amount, "Insufficient balance");
        _burn(msg.sender, amount);
        emit TokensBurned(msg.sender, amount);
        
        // 在这里可以添加业务平台的逻辑，监听到销毁事件后进行法币兑换
    }

    // 设置新的兑换比例，仅合约拥有者可以调用
    function setExchangeRate(
        uint256 newRate
    ) external onlyOwner {
        exchangeRate = newRate;
    }

    // 为算力节点发放在线奖励
    function distributeOnlineRewards(
        address miner, 
        uint256 rewardAmount
    ) external onlyOwner {
        require(rewardAmount > 0, "Reward amount must be greater than 0");
        miners[miner].onlineRewards += rewardAmount;
    }

    // 计算是否可以领取在线奖励
    function canClaimRewards(
        address miner
    ) public view returns (bool) {
        return (block.timestamp / rewardLockPeriod) > miners[miner].lastClaimedCycle;
    }

    // 提现在线奖励
    function claimOnlineRewards() external {
        require(canClaimRewards(msg.sender), "Rewards are still locked");
        
        uint256 rewardToClaim = miners[msg.sender].onlineRewards;
        require(rewardToClaim > 0, "No rewards to claim");

        // 重置奖励
        miners[msg.sender].onlineRewards = 0;
        miners[msg.sender].lastClaimedCycle = block.timestamp / rewardLockPeriod;

        // 将 ETH 发送给算力节点
        _transfer(owner(), msg.sender, rewardToClaim);

        emit OnlineRewardClaimed(msg.sender, rewardToClaim);
    }
}