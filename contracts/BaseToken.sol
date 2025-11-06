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
 * - Tax/Fee 5% - thu phí khi transfer
 */
contract BaseToken is ERC20, ERC20Burnable, Ownable {
    uint256 public constant MAX_SUPPLY = 1000000000 * 10**18; // 1 tỷ token
    uint256 public constant MAX_TAX_RATE = 1000; // 10% tối đa (1000 basis points)
    uint256 private constant BASIS_POINTS = 10000; // 100% = 10000 basis points
    
    // Mapping để lưu blacklist
    mapping(address => bool) public blacklist;
    
    // Tax/Fee variables
    uint256 public taxRate = 500; // 5% = 500 basis points (mặc định)
    address public taxRecipient; // Địa chỉ nhận tax
    bool public taxEnabled = true; // Bật/tắt tax
    
    // Events
    event AddedToBlacklist(address indexed account);
    event RemovedFromBlacklist(address indexed account);
    event TaxRateUpdated(uint256 oldRate, uint256 newRate);
    event TaxRecipientUpdated(address indexed oldRecipient, address indexed newRecipient);
    event TaxEnabled(bool enabled);
    event TaxCollected(address indexed from, address indexed to, uint256 amount);

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
        taxRecipient = msg.sender; // Mặc định owner nhận tax
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
     * @dev Thay đổi tax rate - chỉ owner có thể gọi
     * @param newTaxRate Tax rate mới (basis points, ví dụ: 500 = 5%)
     */
    function setTaxRate(uint256 newTaxRate) public onlyOwner {
        require(newTaxRate <= MAX_TAX_RATE, "Tax rate exceeds maximum");
        uint256 oldRate = taxRate;
        taxRate = newTaxRate;
        emit TaxRateUpdated(oldRate, newTaxRate);
    }

    /**
     * @dev Thay đổi địa chỉ nhận tax - chỉ owner có thể gọi
     * @param newRecipient Địa chỉ nhận tax mới
     */
    function setTaxRecipient(address newRecipient) public onlyOwner {
        require(newRecipient != address(0), "Tax recipient cannot be zero address");
        address oldRecipient = taxRecipient;
        taxRecipient = newRecipient;
        emit TaxRecipientUpdated(oldRecipient, newRecipient);
    }

    /**
     * @dev Bật/tắt tax - chỉ owner có thể gọi
     * @param enabled true để bật tax, false để tắt
     */
    function setTaxEnabled(bool enabled) public onlyOwner {
        taxEnabled = enabled;
        emit TaxEnabled(enabled);
    }

    /**
     * @dev Tính toán số tax từ amount
     * @param amount Số lượng token
     * @return Số tax cần thu
     */
    function calculateTax(uint256 amount) public view returns (uint256) {
        if (!taxEnabled || taxRate == 0) {
            return 0;
        }
        return (amount * taxRate) / BASIS_POINTS;
    }

    /**
     * @dev Override hàm _update để chặn transfer nếu địa chỉ trong blacklist và tính tax
     */
    function _update(address from, address to, uint256 value) internal override {
        require(!blacklist[from], "Sender is blacklisted");
        require(!blacklist[to], "Recipient is blacklisted");
        
        // Tính tax nếu tax được bật và không phải mint/burn
        if (taxEnabled && taxRate > 0 && from != address(0) && to != address(0) && taxRecipient != address(0)) {
            uint256 taxAmount = calculateTax(value);
            
            if (taxAmount > 0) {
                // Transfer tax đến tax recipient
                super._update(from, taxRecipient, taxAmount);
                emit TaxCollected(from, taxRecipient, taxAmount);
                
                // Transfer phần còn lại đến recipient
                super._update(from, to, value - taxAmount);
                return;
            }
        }
        
        // Nếu không có tax, transfer bình thường
        super._update(from, to, value);
    }
}

