// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./Share.sol";

contract Rooms is ERC721{
    using Clones for address;
    
    event ShareVaultCreated(address owner, uint256 tokenID, uint256 shares);

    address public immutable shareToken;
    address public owner;
    mapping(uint256 => address) private shareVaults;
    
    constructor(string memory name_, string memory symbol_, address shareToken_, address owner_) ERC721(name_, symbol_) {
        require(shareToken_.code.length > 0, "Invalid share token address");
        shareToken = shareToken_;

        require(owner_ != address(0), "Invalid owner");
        owner = owner_;
    }

    function mint(address roomOwner, address shareOwner, uint256 tokenID, uint256 shares) external {
        require(msg.sender == owner, "No permit");
        require(shareOwner != address(0) && roomOwner != address(0), "Invalid room owner or share owner");
        
        _mint(roomOwner, tokenID);
        _buildShareVault(shareOwner, tokenID, shares);
    }

    function shareVault(uint256 tokenID) public view returns (address){
        return shareVaults[tokenID];
    }

    function _buildShareVault(address shareOwner, uint256 tokenID, uint256 shares) internal {
        require(shareVaults[tokenID] == address(0), "Share vault already exist");
        
        address token = shareToken.clone();
        require(token != address(0), "Clone failed");
        
        string memory errorMessage = "Underly call reverted without message";
        (bool success, bytes memory returndata) = token.call(abi.encodeWithSignature("initialize(address,uint256)", shareOwner, shares));
        Address.verifyCallResult(success, returndata, errorMessage);
        
        shareVaults[tokenID] = token;
        emit ShareVaultCreated(shareOwner, tokenID, shares);
    }
}