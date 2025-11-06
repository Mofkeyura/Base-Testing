// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title BaseToken
 * @dev Một token ERC20 đơn giản có thể được triển khai trên mạng Base
 * Token này có các tính năng:
 * - Mint (tạo token mới) - chỉ owner
 * - Burn (đốt token) - bất kỳ ai
 * - Transfer (chuyển token) - chuẩn ERC20
 * - Blacklist (chặn địa chỉ) - chỉ owner
 */
contract BaseToken is ERC20, ERC20Burnable, Ownable {
    uint256 public constant MAX_SUPPLY = 1000000000 * 10**18; // 1 tỷ token
    
    // Mapping để lưu blacklist
    mapping(address => bool) public blacklist;
    
    // Events
    event AddedToBlacklist(address indexed account);
    event RemovedFromBlacklist(address indexed account);

    /**
     * @dev Constructor - Khởi tạo token với tên và symbol
     * @param name Tên của token
     * @param symbol Ký hiệu của token
     * @param initialSupply Số lượng token ban đầu (sẽ được mint cho deployer)
     */
    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply
    ) ERC20(name, symbol) Ownable(msg.sender) {
        require(initialSupply <= MAX_SUPPLY, "Initial supply exceeds max supply");
        if (initialSupply > 0) {
            _mint(msg.sender, initialSupply);
        }
    }

    /**
     * @dev Mint token mới - chỉ owner có thể gọi
     * @param to Địa chỉ nhận token
     * @param amount Số lượng token cần mint
     */
    function mint(address to, uint256 amount) public onlyOwner {
        require(totalSupply() + amount <= MAX_SUPPLY, "Minting would exceed max supply");
        _mint(to, amount);
    }

    /**
     * @dev Kiểm tra số lượng token còn có thể mint
     * @return Số lượng token còn lại có thể mint
     */
    function remainingMintable() public view returns (uint256) {
        return MAX_SUPPLY - totalSupply();
    }

    /**
     * @dev Thêm địa chỉ vào blacklist - chỉ owner có thể gọi
     * @param account Địa chỉ cần thêm vào blacklist
     */
    function addToBlacklist(address account) public onlyOwner {
        require(account != address(0), "Cannot blacklist zero address");
        require(!blacklist[account], "Address already blacklisted");
        blacklist[account] = true;
        emit AddedToBlacklist(account);
    }

    /**
     * @dev Xóa địa chỉ khỏi blacklist - chỉ owner có thể gọi
     * @param account Địa chỉ cần xóa khỏi blacklist
     */
    function removeFromBlacklist(address account) public onlyOwner {
        require(blacklist[account], "Address not blacklisted");
        blacklist[account] = false;
        emit RemovedFromBlacklist(account);
    }

    /**
     * @dev Kiểm tra địa chỉ có trong blacklist không
     * @param account Địa chỉ cần kiểm tra
     * @return true nếu địa chỉ trong blacklist
     */
    function isBlacklisted(address account) public view returns (bool) {
        return blacklist[account];
    }

    /**
     * @dev Override hàm _update để chặn transfer nếu địa chỉ trong blacklist
     */
    function _update(address from, address to, uint256 value) internal override {
        require(!blacklist[from], "Sender is blacklisted");
        require(!blacklist[to], "Recipient is blacklisted");
        super._update(from, to, value);
    }
}

