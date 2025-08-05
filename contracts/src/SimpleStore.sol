// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v4.8.0/contracts/security/ReentrancyGuard.sol";

/**
 * @title SimpleStore
 * @dev A simple on-chain store for listing and selling items for ETH.
 * @notice Users can list items, and others can purchase them.
 */
contract SimpleStore is ReentrancyGuard {

    // Struct for an item in the store
    struct Item {
        string name;
        string description;
        uint256 price;
        address payable seller;
        bool isSold;
        address buyer;
        bool exists;
    }

    // State variables
    uint256 public itemCount;
    mapping(uint256 => Item) public items;

    // Events
    event ItemListed(uint256 indexed itemId, string name, uint256 price, address indexed seller);
    event ItemSold(uint256 indexed itemId, address indexed buyer, uint256 price);

    /**
     * @notice Lists a new item for sale.
     * @param _name The name of the item.
     * @param _description A description of the item.
     * @param _price The price of the item in wei.
     * @return The ID of the newly listed item.
     */
    function listItem(string memory _name, string memory _description, uint256 _price) external returns (uint256) {
        require(bytes(_name).length > 0, "Name cannot be empty");
        require(_price > 0, "Price must be positive");

        uint256 itemId = itemCount;
        items[itemId] = Item({
            name: _name,
            description: _description,
            price: _price,
            seller: payable(msg.sender),
            isSold: false,
            buyer: address(0),
            exists: true
        });

        itemCount++;
        emit ItemListed(itemId, _name, _price, msg.sender);
        return itemId;
    }

    /**
     * @notice Purchases an item.
     * @param _itemId The ID of the item to purchase.
     */
    function purchaseItem(uint256 _itemId) external payable nonReentrant {
        require(_itemId < itemCount && items[_itemId].exists, "Item not found");
        Item storage item = items[_itemId];

        require(!item.isSold, "Item is already sold");
        require(msg.value == item.price, "Incorrect payment amount");
        require(msg.sender != item.seller, "Seller cannot buy their own item");

        // Mark as sold and record buyer
        item.isSold = true;
        item.buyer = msg.sender;

        // Transfer funds to the seller
        (bool success, ) = item.seller.call{value: msg.value}("");
        require(success, "Payment failed");

        emit ItemSold(_itemId, msg.sender, msg.value);
    }

    /**
     * @notice Gets the details of an item.
     * @param _itemId The ID of the item.
     * @return The details of the item.
     */
    function getItem(uint256 _itemId) 
        external 
        view 
        returns (
            string memory name,
            string memory description,
            uint256 price,
            address seller,
            bool isSold,
            address buyer
        )
    {
        require(_itemId < itemCount && items[_itemId].exists, "Item not found");
        Item storage item = items[_itemId];
        return (item.name, item.description, item.price, item.seller, item.isSold, item.buyer);
    }
}
