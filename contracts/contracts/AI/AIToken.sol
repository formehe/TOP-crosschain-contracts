// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../common/AdminControlledUpgradeable.sol";

contract AIToken is ERC20, AdminControlledUpgradeable {
    // 兑换比例，例如 1 法币 = 100 AI Token
    uint256 public exchangeRate;

    event TokensMinted(address indexed user, uint256 amount);
    event TokensBurned(address indexed user, uint256 amount);

    constructor(
        uint256 _initialSupply, 
        uint256 _exchangeRate,
        address _owner
    ) ERC20("AI Token", "AIT") initializer {
        require(_owner != address(0), "Invalid owner");
        _mint(msg.sender, _initialSupply); // 初始铸造给合约拥有者
        exchangeRate = _exchangeRate; // 设置兑换比例
        _setRoleAdmin(ADMIN_ROLE, OWNER_ROLE);
        _setRoleAdmin(CONTROLLED_ROLE, ADMIN_ROLE);

        _grantRole(OWNER_ROLE, _owner);
        _grantRole(ADMIN_ROLE, msg.sender);

        AdminControlledUpgradeable._AdminControlledUpgradeable_init(msg.sender, 0xff);
    }

    // 用户充值：业务平台调用该函数铸造相应的 AI Token
    function mint(
        uint256 fiatAmount
    ) external onlyRole(CONTROLLED_ROLE) {
        // uint256 tokenAmount = fiatAmount * exchangeRate; // 计算相应的 AI Token 数量
        _mint(msg.sender, fiatAmount);
        emit TokensMinted(msg.sender, fiatAmount);
    }

    // 用户提现：销毁相应的 AI Token
    function burn(
        uint256 amount
    ) external {
        require(balanceOf(msg.sender) >= amount, "Insufficient balance");
        _burn(msg.sender, amount);
        emit TokensBurned(msg.sender, amount);
    }

    // 设置新的兑换比例，仅合约拥有者可以调用
    function setExchangeRate(
        uint256 newRate
    ) external onlyRole(CONTROLLED_ROLE) {
        exchangeRate = newRate;
    }
}