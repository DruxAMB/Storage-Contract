// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v4.8.0/contracts/security/ReentrancyGuard.sol";
import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v4.8.0/contracts/access/Ownable.sol";

/**
 * @title SimpleStore
 * @dev Basic on-chain marketplace for digital items
 * @notice Allows users to list items for sale and purchase them with ETH
 */
contract SimpleStore is ReentrancyGuard, Ownable {
    // Item status
    enum ItemStatus { ACTIVE, SOLD, REMOVED }
    
    // Store item struct
    struct StoreItem {
        string name;
        string description;
        string imageUrl;
        uint256 price;
        address seller;
        address buyer;
        uint256 listedAt;
        uint256 soldAt;
        ItemStatus status;
        bool exists;
    }
    
    // State variables
    uint256 public itemCount;
    uint256 public platformFee = 250; // 2.5% in basis points
    uint256 public listingFee = 0.001 ether;
    
    // Mappings
    mapping(uint256 => StoreItem) public items;
    mapping(address => uint256[]) public sellerItems;
    mapping(address => uint256[]) public buyerItems;
    mapping(address => uint256) public sellerItemCount;
    mapping(address => uint256) public buyerItemCount;
    
    // Events
    event ItemListed(
        uint256 indexed itemId,
        address indexed seller,
        string name,
        uint256 price
    );
    
    event ItemPurchased(
        uint256 indexed itemId,
        address indexed buyer,
        address indexed seller,
        uint256 price
    );
    
    event ItemRemoved(uint256 indexed itemId, address indexed seller);
    event PriceUpdated(uint256 indexed itemId, uint256 oldPrice, uint256 newPrice);
    event FeesUpdated(uint256 platformFee, uint256 listingFee);
    
    /**
     * @dev Constructor
     */
    constructor() Ownable() {}
    
    /**
     * @dev List an item for sale
     * @param name Name of the item
     * @param description Description of the item
     * @param imageUrl URL of the item image
     * @param price Price in ETH (wei)
     * @return itemId ID of the listed item
     */
    function listItem(
        string memory name,
        string memory description,
        string memory imageUrl,
        uint256 price
    ) external payable nonReentrant returns (uint256 itemId) {
        require(bytes(name).length > 0, "Name cannot be empty");
        require(price > 0, "Price must be positive");
        require(msg.value >= listingFee, "Insufficient listing fee");
        
        itemId = itemCount++;
        
        items[itemId] = StoreItem({
            name: name,
            description: description,
            imageUrl: imageUrl,
            price: price,
            seller: msg.sender,
            buyer: address(0),
            listedAt: block.timestamp,
            soldAt: 0,
            status: ItemStatus.ACTIVE,
            exists: true
        });
        
        // Track seller items
        sellerItems[msg.sender].push(itemId);
        sellerItemCount[msg.sender]++;
        
        emit ItemListed(itemId, msg.sender, name, price);
        
        return itemId;
    }
    
    /**
     * @dev Purchase an item
     * @param itemId ID of the item to purchase
     */
    function purchaseItem(uint256 itemId) external payable nonReentrant {
        require(itemId < itemCount, "Item does not exist");
        require(items[itemId].exists, "Item not found");
        
        StoreItem storage item = items[itemId];
        require(item.status == ItemStatus.ACTIVE, "Item not available");
        require(msg.sender != item.seller, "Cannot buy your own item");
        require(msg.value >= item.price, "Insufficient payment");
        
        // Calculate fees
        uint256 feeAmount = (item.price * platformFee) / 10000;
        uint256 sellerAmount = item.price - feeAmount;
        
        // Update item status
        item.buyer = msg.sender;
        item.soldAt = block.timestamp;
        item.status = ItemStatus.SOLD;
        
        // Track buyer items
        buyerItems[msg.sender].push(itemId);
        buyerItemCount[msg.sender]++;
        
        // Transfer payment to seller
        payable(item.seller).transfer(sellerAmount);
        
        // Refund excess payment
        if (msg.value > item.price) {
            payable(msg.sender).transfer(msg.value - item.price);
        }
        
        emit ItemPurchased(itemId, msg.sender, item.seller, item.price);
    }
    
    /**
     * @dev Remove an item from sale (seller only)
     * @param itemId ID of the item to remove
     */
    function removeItem(uint256 itemId) external nonReentrant {
        require(itemId < itemCount, "Item does not exist");
        require(items[itemId].exists, "Item not found");
        
        StoreItem storage item = items[itemId];
        require(msg.sender == item.seller, "Not the seller");
        require(item.status == ItemStatus.ACTIVE, "Item not active");
        
        item.status = ItemStatus.REMOVED;
        
        emit ItemRemoved(itemId, msg.sender);
    }
    
    /**
     * @dev Update item price (seller only)
     * @param itemId ID of the item
     * @param newPrice New price in ETH (wei)
     */
    function updatePrice(uint256 itemId, uint256 newPrice) external {
        require(itemId < itemCount, "Item does not exist");
        require(items[itemId].exists, "Item not found");
        require(newPrice > 0, "Price must be positive");
        
        StoreItem storage item = items[itemId];
        require(msg.sender == item.seller, "Not the seller");
        require(item.status == ItemStatus.ACTIVE, "Item not active");
        
        uint256 oldPrice = item.price;
        item.price = newPrice;
        
        emit PriceUpdated(itemId, oldPrice, newPrice);
    }
    
    /**
     * @dev Get item details
     * @param itemId ID of the item
     * @return Basic item information
     */
    function getItem(uint256 itemId) external view returns (
        string memory name,
        string memory description,
        string memory imageUrl,
        uint256 price,
        address seller,
        ItemStatus status
    ) {
        require(itemId < itemCount, "Item does not exist");
        require(items[itemId].exists, "Item not found");
        
        StoreItem storage item = items[itemId];
        return (
            item.name,
            item.description,
            item.imageUrl,
            item.price,
            item.seller,
            item.status
        );
    }
    
    /**
     * @dev Get item sale details
     * @param itemId ID of the item
     * @return Sale-related information
     */
    function getItemSaleInfo(uint256 itemId) external view returns (
        address buyer,
        uint256 listedAt,
        uint256 soldAt,
        bool isSold
    ) {
        require(itemId < itemCount, "Item does not exist");
        require(items[itemId].exists, "Item not found");
        
        StoreItem storage item = items[itemId];
        return (
            item.buyer,
            item.listedAt,
            item.soldAt,
            item.status == ItemStatus.SOLD
        );
    }
    
    /**
     * @dev Get all active items (for browsing)
     * @param offset Starting index for pagination
     * @param limit Maximum number of items to return
     * @return itemIds Array of active item IDs
     */
    function getActiveItems(uint256 offset, uint256 limit) external view returns (uint256[] memory itemIds) {
        require(limit > 0 && limit <= 100, "Invalid limit");
        
        // Count active items first
        uint256 activeCount = 0;
        for (uint256 i = 0; i < itemCount; i++) {
            if (items[i].exists && items[i].status == ItemStatus.ACTIVE) {
                activeCount++;
            }
        }
        
        if (offset >= activeCount) {
            return new uint256[](0);
        }
        
        uint256 resultSize = activeCount - offset;
        if (resultSize > limit) {
            resultSize = limit;
        }
        
        itemIds = new uint256[](resultSize);
        uint256 currentIndex = 0;
        uint256 resultIndex = 0;
        
        for (uint256 i = 0; i < itemCount && resultIndex < resultSize; i++) {
            if (items[i].exists && items[i].status == ItemStatus.ACTIVE) {
                if (currentIndex >= offset) {
                    itemIds[resultIndex] = i;
                    resultIndex++;
                }
                currentIndex++;
            }
        }
        
        return itemIds;
    }
    
    /**
     * @dev Get items listed by a seller
     * @param seller Address of the seller
     * @return Array of item IDs listed by the seller
     */
    function getSellerItems(address seller) external view returns (uint256[] memory) {
        return sellerItems[seller];
    }
    
    /**
     * @dev Get items purchased by a buyer
     * @param buyer Address of the buyer
     * @return Array of item IDs purchased by the buyer
     */
    function getBuyerItems(address buyer) external view returns (uint256[] memory) {
        return buyerItems[buyer];
    }
    
    /**
     * @dev Get seller statistics
     * @param seller Address of the seller
     * @return totalListed Total items listed
     * @return totalSold Total items sold
     * @return totalRevenue Total revenue earned (excluding fees)
     */
    function getSellerStats(address seller) external view returns (
        uint256 totalListed,
        uint256 totalSold,
        uint256 totalRevenue
    ) {
        totalListed = sellerItemCount[seller];
        
        uint256[] memory sellerItemIds = sellerItems[seller];
        for (uint256 i = 0; i < sellerItemIds.length; i++) {
            uint256 itemId = sellerItemIds[i];
            if (items[itemId].status == ItemStatus.SOLD) {
                totalSold++;
                uint256 feeAmount = (items[itemId].price * platformFee) / 10000;
                totalRevenue += items[itemId].price - feeAmount;
            }
        }
        
        return (totalListed, totalSold, totalRevenue);
    }
    
    /**
     * @dev Get marketplace statistics
     * @return totalItems Total items ever listed
     * @return activeItems Currently active items
     * @return soldItems Total items sold
     * @return totalVolume Total trading volume
     */
    function getMarketplaceStats() external view returns (
        uint256 totalItems,
        uint256 activeItems,
        uint256 soldItems,
        uint256 totalVolume
    ) {
        totalItems = itemCount;
        
        for (uint256 i = 0; i < itemCount; i++) {
            if (items[i].exists) {
                if (items[i].status == ItemStatus.ACTIVE) {
                    activeItems++;
                } else if (items[i].status == ItemStatus.SOLD) {
                    soldItems++;
                    totalVolume += items[i].price;
                }
            }
        }
        
        return (totalItems, activeItems, soldItems, totalVolume);
    }
    
    /**
     * @dev Update platform and listing fees (owner only)
     * @param newPlatformFee New platform fee in basis points
     * @param newListingFee New listing fee in wei
     */
    function updateFees(uint256 newPlatformFee, uint256 newListingFee) external onlyOwner {
        require(newPlatformFee <= 1000, "Platform fee too high"); // Max 10%
        
        platformFee = newPlatformFee;
        listingFee = newListingFee;
        
        emit FeesUpdated(newPlatformFee, newListingFee);
    }
    
    /**
     * @dev Withdraw collected fees (owner only)
     */
    function withdrawFees() external onlyOwner nonReentrant {
        uint256 balance = address(this).balance;
        require(balance > 0, "No fees to withdraw");
        
        payable(owner()).transfer(balance);
    }
    
    /**
     * @dev Get contract balance
     * @return Current contract balance
     */
    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
    
    /**
     * @dev Check if an item exists and is active
     * @param itemId ID of the item
     * @return Whether the item is available for purchase
     */
    function isItemAvailable(uint256 itemId) external view returns (bool) {
        return itemId < itemCount && 
               items[itemId].exists && 
               items[itemId].status == ItemStatus.ACTIVE;
    }
}
