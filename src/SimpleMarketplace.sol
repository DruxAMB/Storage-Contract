// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title MarketplaceStorage
 * @dev Storage and data structures for the marketplace
 */
contract MarketplaceStorage {
    // Enums
    enum ItemStatus { Active, Sold, Cancelled }
    enum OrderStatus { Created, Accepted, Completed, Refunded, Disputed, Resolved }
    
    // Structs
    struct Item {
        uint256 id;
        string title;
        string description;
        uint256 price;
        address payable seller;
        ItemStatus status;
        uint256 createdAt;
        string[] imageURIs;
        string category;
        bool isDigital;
        uint256 reviewCount;
        uint256 totalRating;
    }
    
    struct Order {
        uint256 id;
        uint256 itemId;
        address payable buyer;
        address payable seller;
        uint256 price;
        uint256 createdAt;
        uint256 completedAt;
        OrderStatus status;
        bool reviewed;
    }
    
    struct Review {
        uint256 id;
        uint256 itemId;
        uint256 orderId;
        address reviewer;
        uint256 rating; // 1-5 stars
        string comment;
        uint256 timestamp;
    }
    
    struct Dispute {
        uint256 orderId;
        string buyerReason;
        string sellerResponse;
        bool resolved;
        bool buyerFavored;
    }
    
    // State variables
    mapping(uint256 => Item) public items;
    mapping(uint256 => Order) public orders;
    mapping(uint256 => Review) public reviews;
    mapping(uint256 => Dispute) public disputes;
    mapping(address => uint256[]) public userItems;
    mapping(address => uint256[]) public userOrders;
    mapping(uint256 => uint256[]) public itemReviews;
    
    uint256 public itemCount;
    uint256 public orderCount;
    uint256 public reviewCount;
    
    // Platform fee (in basis points, 250 = 2.5%)
    uint256 public platformFee = 250;
    address payable public owner;
    
    // Escrow timelock (in seconds, default 3 days)
    uint256 public escrowTimelock = 3 days;
    
    // Events
    event ItemListed(
        uint256 indexed itemId,
        address indexed seller,
        string title,
        uint256 price
    );
    
    event ItemUpdated(
        uint256 indexed itemId,
        string title,
        uint256 price,
        ItemStatus status
    );
    
    event OrderCreated(
        uint256 indexed orderId,
        uint256 indexed itemId,
        address indexed buyer,
        address seller,
        uint256 price
    );
    
    event OrderAccepted(
        uint256 indexed orderId,
        address indexed seller
    );
    
    event OrderCompleted(
        uint256 indexed orderId,
        address indexed buyer,
        address indexed seller,
        uint256 price
    );
    
    event OrderRefunded(
        uint256 indexed orderId,
        address indexed buyer,
        uint256 amount
    );
    
    event DisputeCreated(
        uint256 indexed orderId,
        address indexed buyer,
        string reason
    );
    
    event DisputeResolved(
        uint256 indexed orderId,
        bool buyerFavored
    );
    
    event ReviewLeft(
        uint256 indexed reviewId,
        uint256 indexed itemId,
        address indexed reviewer,
        uint256 rating
    );
    
    constructor() {
        owner = payable(msg.sender);
    }
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }
    
    modifier itemExists(uint256 itemId) {
        require(itemId < itemCount, "Item does not exist");
        _;
    }
    
    modifier orderExists(uint256 orderId) {
        require(orderId < orderCount, "Order does not exist");
        _;
    }
    
    modifier onlySeller(uint256 itemId) {
        require(msg.sender == items[itemId].seller, "Not the seller");
        _;
    }
    
    modifier onlyBuyer(uint256 orderId) {
        require(msg.sender == orders[orderId].buyer, "Not the buyer");
        _;
    }
    
    modifier onlyInvolved(uint256 orderId) {
        require(
            msg.sender == orders[orderId].buyer || 
            msg.sender == orders[orderId].seller || 
            msg.sender == owner,
            "Not involved in this order"
        );
        _;
    }
}

/**
 * @title SimpleMarketplace
 * @dev A basic peer-to-peer marketplace for digital goods and services
 * @notice Allows users to list items, make offers, use escrow payments, and leave reviews
 */
contract SimpleMarketplace is MarketplaceStorage {
    
    /**
     * @dev List a new item for sale
     * @param title Item title
     * @param description Item description
     * @param price Item price in wei
     * @param category Item category
     * @param imageURIs Array of image URIs
     * @param isDigital Whether the item is digital
     * @return itemId The ID of the created item
     */
    function listItem(
        string memory title,
        string memory description,
        uint256 price,
        string memory category,
        string[] memory imageURIs,
        bool isDigital
    ) external returns (uint256 itemId) {
        require(bytes(title).length > 0, "Title cannot be empty");
        require(bytes(description).length > 0, "Description cannot be empty");
        require(price > 0, "Price must be greater than 0");
        
        itemId = itemCount++;
        
        items[itemId] = Item({
            id: itemId,
            title: title,
            description: description,
            price: price,
            seller: payable(msg.sender),
            status: ItemStatus.Active,
            createdAt: block.timestamp,
            imageURIs: imageURIs,
            category: category,
            isDigital: isDigital,
            reviewCount: 0,
            totalRating: 0
        });
        
        userItems[msg.sender].push(itemId);
        
        emit ItemListed(itemId, msg.sender, title, price);
    }
    
    /**
     * @dev Update an existing item
     * @param itemId Item ID to update
     * @param title New title (empty to keep current)
     * @param description New description (empty to keep current)
     * @param price New price (0 to keep current)
     * @param status New status
     * @param imageURIs New image URIs (empty array to keep current)
     */
    function updateItem(
        uint256 itemId,
        string memory title,
        string memory description,
        uint256 price,
        ItemStatus status,
        string[] memory imageURIs
    ) external itemExists(itemId) onlySeller(itemId) {
        Item storage item = items[itemId];
        require(item.status != ItemStatus.Sold, "Cannot update sold item");
        
        if (bytes(title).length > 0) {
            item.title = title;
        }
        
        if (bytes(description).length > 0) {
            item.description = description;
        }
        
        if (price > 0) {
            item.price = price;
        }
        
        if (imageURIs.length > 0) {
            item.imageURIs = imageURIs;
        }
        
        item.status = status;
        
        emit ItemUpdated(itemId, item.title, item.price, status);
    }
    
    /**
     * @dev Purchase an item (creates an order and locks payment in escrow)
     * @param itemId Item ID to purchase
     * @return orderId The ID of the created order
     */
    function purchaseItem(uint256 itemId) 
        external 
        payable 
        itemExists(itemId) 
        returns (uint256 orderId) 
    {
        Item storage item = items[itemId];
        require(item.status == ItemStatus.Active, "Item not available");
        require(msg.sender != item.seller, "Cannot buy your own item");
        require(msg.value >= item.price, "Insufficient payment");
        
        orderId = orderCount++;
        
        orders[orderId] = Order({
            id: orderId,
            itemId: itemId,
            buyer: payable(msg.sender),
            seller: item.seller,
            price: item.price,
            createdAt: block.timestamp,
            completedAt: 0,
            status: OrderStatus.Created,
            reviewed: false
        });
        
        // Update item status
        item.status = ItemStatus.Sold;
        
        // Track user orders
        userOrders[msg.sender].push(orderId);
        
        // Refund excess payment if any
        uint256 excess = msg.value - item.price;
        if (excess > 0) {
            payable(msg.sender).transfer(excess);
        }
        
        emit OrderCreated(orderId, itemId, msg.sender, item.seller, item.price);
    }
    
    /**
     * @dev Accept an order (seller confirms)
     * @param orderId Order ID to accept
     */
    function acceptOrder(uint256 orderId) 
        external 
        orderExists(orderId) 
    {
        Order storage order = orders[orderId];
        require(msg.sender == order.seller, "Not the seller");
        require(order.status == OrderStatus.Created, "Order not in created status");
        
        order.status = OrderStatus.Accepted;
        
        emit OrderAccepted(orderId, msg.sender);
    }
    
    /**
     * @dev Complete an order (buyer confirms receipt)
     * @param orderId Order ID to complete
     */
    function completeOrder(uint256 orderId) 
        external 
        orderExists(orderId) 
        onlyBuyer(orderId) 
    {
        Order storage order = orders[orderId];
        require(
            order.status == OrderStatus.Created || 
            order.status == OrderStatus.Accepted, 
            "Order cannot be completed"
        );
        
        order.status = OrderStatus.Completed;
        order.completedAt = block.timestamp;
        
        // Calculate fees and transfer payment
        uint256 feeAmount = (order.price * platformFee) / 10000;
        uint256 sellerAmount = order.price - feeAmount;
        
        // Transfer funds
        if (feeAmount > 0) {
            owner.transfer(feeAmount);
        }
        order.seller.transfer(sellerAmount);
        
        emit OrderCompleted(orderId, order.buyer, order.seller, order.price);
    }
    
    /**
     * @dev Auto-complete order after timelock expires
     * @param orderId Order ID to auto-complete
     */
    function autoCompleteOrder(uint256 orderId) 
        external 
        orderExists(orderId) 
    {
        Order storage order = orders[orderId];
        require(
            order.status == OrderStatus.Created || 
            order.status == OrderStatus.Accepted, 
            "Order cannot be auto-completed"
        );
        require(
            block.timestamp > order.createdAt + escrowTimelock,
            "Escrow timelock not expired"
        );
        
        order.status = OrderStatus.Completed;
        order.completedAt = block.timestamp;
        
        // Calculate fees and transfer payment
        uint256 feeAmount = (order.price * platformFee) / 10000;
        uint256 sellerAmount = order.price - feeAmount;
        
        // Transfer funds
        if (feeAmount > 0) {
            owner.transfer(feeAmount);
        }
        order.seller.transfer(sellerAmount);
        
        emit OrderCompleted(orderId, order.buyer, order.seller, order.price);
    }
}

/**
 * @title MarketplaceOrders
 * @dev Extension for SimpleMarketplace with order management functions
 */
contract MarketplaceOrders is SimpleMarketplace {
    /**
     * @dev Refund an order (seller cancels)
     * @param orderId Order ID to refund
     */
    function refundOrder(uint256 orderId) 
        external 
        orderExists(orderId) 
    {
        Order storage order = orders[orderId];
        require(msg.sender == order.seller, "Not the seller");
        require(
            order.status == OrderStatus.Created || 
            order.status == OrderStatus.Accepted, 
            "Order cannot be refunded"
        );
        
        order.status = OrderStatus.Refunded;
        
        // Return payment to buyer
        order.buyer.transfer(order.price);
        
        // Update item status back to active
        items[order.itemId].status = ItemStatus.Active;
        
        emit OrderRefunded(orderId, order.buyer, order.price);
    }
    
    /**
     * @dev Create a dispute for an order
     * @param orderId Order ID to dispute
     * @param reason Reason for dispute
     */
    function createDispute(uint256 orderId, string memory reason) 
        external 
        orderExists(orderId) 
        onlyBuyer(orderId) 
    {
        Order storage order = orders[orderId];
        require(
            order.status == OrderStatus.Created || 
            order.status == OrderStatus.Accepted, 
            "Order cannot be disputed"
        );
        require(bytes(reason).length > 0, "Reason cannot be empty");
        
        order.status = OrderStatus.Disputed;
        
        disputes[orderId] = Dispute({
            orderId: orderId,
            buyerReason: reason,
            sellerResponse: "",
            resolved: false,
            buyerFavored: false
        });
        
        emit DisputeCreated(orderId, msg.sender, reason);
    }
    
    /**
     * @dev Respond to a dispute (seller)
     * @param orderId Order ID of the dispute
     * @param response Seller's response
     */
    function respondToDispute(uint256 orderId, string memory response) 
        external 
        orderExists(orderId) 
    {
        Order storage order = orders[orderId];
        require(msg.sender == order.seller, "Not the seller");
        require(order.status == OrderStatus.Disputed, "Order not disputed");
        require(bytes(response).length > 0, "Response cannot be empty");
        
        disputes[orderId].sellerResponse = response;
    }
    
    /**
     * @dev Resolve a dispute (owner/admin only)
     * @param orderId Order ID of the dispute
     * @param buyerFavored Whether to favor the buyer (refund) or seller (complete)
     */
    function resolveDispute(uint256 orderId, bool buyerFavored) 
        external 
        orderExists(orderId) 
        onlyOwner 
    {
        Order storage order = orders[orderId];
        require(order.status == OrderStatus.Disputed, "Order not disputed");
        
        Dispute storage dispute = disputes[orderId];
        dispute.resolved = true;
        dispute.buyerFavored = buyerFavored;
        
        order.status = OrderStatus.Resolved;
        
        if (buyerFavored) {
            // Refund buyer
            order.buyer.transfer(order.price);
            // Update item status back to active
            items[order.itemId].status = ItemStatus.Active;
        } else {
            // Complete order in favor of seller
            uint256 feeAmount = (order.price * platformFee) / 10000;
            uint256 sellerAmount = order.price - feeAmount;
            
            // Transfer funds
            if (feeAmount > 0) {
                owner.transfer(feeAmount);
            }
            order.seller.transfer(sellerAmount);
        }
        
        emit DisputeResolved(orderId, buyerFavored);
    }
    
    /**
     * @dev Leave a review for an item after purchase
     * @param orderId Order ID to review
     * @param rating Rating (1-5)
     * @param comment Review comment
     * @return reviewId The ID of the created review
     */
    function leaveReview(
        uint256 orderId,
        uint256 rating,
        string memory comment
    ) external orderExists(orderId) onlyBuyer(orderId) returns (uint256 reviewId) {
        Order storage order = orders[orderId];
        require(order.status == OrderStatus.Completed, "Order not completed");
        require(!order.reviewed, "Already reviewed");
        require(rating >= 1 && rating <= 5, "Rating must be between 1-5");
        
        reviewId = reviewCount++;
        uint256 itemId = order.itemId;
        
        reviews[reviewId] = Review({
            id: reviewId,
            itemId: itemId,
            orderId: orderId,
            reviewer: msg.sender,
            rating: rating,
            comment: comment,
            timestamp: block.timestamp
        });
        
        // Update item rating
        Item storage item = items[itemId];
        item.reviewCount++;
        item.totalRating += rating;
        
        // Mark order as reviewed
        order.reviewed = true;
        
        // Track item reviews
        itemReviews[itemId].push(reviewId);
        
        emit ReviewLeft(reviewId, itemId, msg.sender, rating);
    }
}

/**
 * @title MarketplaceViews
 * @dev Extension for SimpleMarketplace with view functions
 */
contract MarketplaceViews is MarketplaceOrders {
    /**
     * @dev Get item information
     * @param itemId Item ID
     * @return title Item title
     * @return description Item description
     * @return price Item price
     * @return seller Seller address
     * @return status Item status
     * @return isDigital Whether item is digital
     * @return avgRating Average rating (0-5)
     */
    function getItem(uint256 itemId) 
        external 
        view 
        itemExists(itemId) 
        returns (
            string memory title,
            string memory description,
            uint256 price,
            address seller,
            ItemStatus status,
            bool isDigital,
            uint256 avgRating
        ) 
    {
        Item storage item = items[itemId];
        uint256 rating = 0;
        
        if (item.reviewCount > 0) {
            rating = item.totalRating / item.reviewCount;
        }
        
        return (
            item.title,
            item.description,
            item.price,
            item.seller,
            item.status,
            item.isDigital,
            rating
        );
    }
    
    /**
     * @dev Get item image URIs
     * @param itemId Item ID
     * @return imageURIs Array of image URIs
     */
    function getItemImages(uint256 itemId) 
        external 
        view 
        itemExists(itemId) 
        returns (string[] memory imageURIs) 
    {
        return items[itemId].imageURIs;
    }
    
    /**
     * @dev Get order information
     * @param orderId Order ID
     * @return itemId Item ID
     * @return buyer Buyer address
     * @return seller Seller address
     * @return price Order price
     * @return status Order status
     * @return createdAt Order creation timestamp
     * @return completedAt Order completion timestamp
     */
    function getOrder(uint256 orderId) 
        external 
        view 
        orderExists(orderId) 
        onlyInvolved(orderId) 
        returns (
            uint256 itemId,
            address buyer,
            address seller,
            uint256 price,
            OrderStatus status,
            uint256 createdAt,
            uint256 completedAt
        ) 
    {
        Order storage order = orders[orderId];
        return (
            order.itemId,
            order.buyer,
            order.seller,
            order.price,
            order.status,
            order.createdAt,
            order.completedAt
        );
    }
    
    /**
     * @dev Get dispute information
     * @param orderId Order ID
     * @return buyerReason Buyer's reason for dispute
     * @return sellerResponse Seller's response
     * @return resolved Whether dispute is resolved
     * @return buyerFavored Whether buyer was favored in resolution
     */
    function getDispute(uint256 orderId) 
        external 
        view 
        orderExists(orderId) 
        onlyInvolved(orderId) 
        returns (
            string memory buyerReason,
            string memory sellerResponse,
            bool resolved,
            bool buyerFavored
        ) 
    {
        Dispute storage dispute = disputes[orderId];
        return (
            dispute.buyerReason,
            dispute.sellerResponse,
            dispute.resolved,
            dispute.buyerFavored
        );
    }
    
    /**
     * @dev Get review information
     * @param reviewId Review ID
     * @return itemId Item ID
     * @return reviewer Reviewer address
     * @return rating Rating (1-5)
     * @return comment Review comment
     * @return timestamp Review timestamp
     */
    function getReview(uint256 reviewId) 
        external 
        view 
        returns (
            uint256 itemId,
            address reviewer,
            uint256 rating,
            string memory comment,
            uint256 timestamp
        ) 
    {
        require(reviewId < reviewCount, "Review does not exist");
        
        Review storage review = reviews[reviewId];
        return (
            review.itemId,
            review.reviewer,
            review.rating,
            review.comment,
            review.timestamp
        );
    }
}

/**
 * @title MarketplaceQueries
 * @dev Extension for SimpleMarketplace with query functions
 */
contract MarketplaceQueries is MarketplaceViews {
    /**
     * @dev Get items listed by a user
     * @param user User address
     * @return itemIds Array of item IDs
     */
    function getUserItems(address user) 
        external 
        view 
        returns (uint256[] memory itemIds) 
    {
        return userItems[user];
    }
    
    /**
     * @dev Get orders made by a user
     * @param user User address
     * @return orderIds Array of order IDs
     */
    function getUserOrders(address user) 
        external 
        view 
        returns (uint256[] memory orderIds) 
    {
        return userOrders[user];
    }
    
    /**
     * @dev Get reviews for an item
     * @param itemId Item ID
     * @return reviewIds Array of review IDs
     */
    function getItemReviews(uint256 itemId) 
        external 
        view 
        itemExists(itemId) 
        returns (uint256[] memory reviewIds) 
    {
        return itemReviews[itemId];
    }
    
    /**
     * @dev Get active items by category (paginated)
     * @param category Category to filter by (empty for all)
     * @param offset Starting index
     * @param limit Maximum number of items to return
     * @return itemIds Array of active item IDs
     */
    function getActiveItemsByCategory(
        string memory category,
        uint256 offset,
        uint256 limit
    ) external view returns (uint256[] memory itemIds) {
        uint256 activeCount = 0;
        bool filterCategory = bytes(category).length > 0;
        
        // Count active items in category
        for (uint256 i = 0; i < itemCount; i++) {
            if (items[i].status == ItemStatus.Active) {
                if (!filterCategory || keccak256(bytes(items[i].category)) == keccak256(bytes(category))) {
                    activeCount++;
                }
            }
        }
        
        if (offset >= activeCount) {
            return new uint256[](0);
        }
        
        uint256 end = offset + limit;
        if (end > activeCount) {
            end = activeCount;
        }
        
        itemIds = new uint256[](end - offset);
        uint256 currentIndex = 0;
        uint256 resultIndex = 0;
        
        for (uint256 i = 0; i < itemCount && resultIndex < (end - offset); i++) {
            if (items[i].status == ItemStatus.Active) {
                if (!filterCategory || keccak256(bytes(items[i].category)) == keccak256(bytes(category))) {
                    if (currentIndex >= offset) {
                        itemIds[resultIndex] = i;
                        resultIndex++;
                    }
                    currentIndex++;
                }
            }
        }
    }
    
    /**
     * @dev Update platform fee (owner only)
     * @param newFee New platform fee in basis points
     */
    function updatePlatformFee(uint256 newFee) external onlyOwner {
        require(newFee <= 1000, "Platform fee too high"); // Max 10%
        platformFee = newFee;
    }
    
    /**
     * @dev Update escrow timelock (owner only)
     * @param newTimelock New timelock in seconds
     */
    function updateEscrowTimelock(uint256 newTimelock) external onlyOwner {
        require(newTimelock >= 1 hours, "Timelock too short");
        require(newTimelock <= 30 days, "Timelock too long");
        escrowTimelock = newTimelock;
    }
    
    /**
     * @dev Emergency withdraw (owner only) - for stuck funds
     */
    function emergencyWithdraw() external onlyOwner {
        owner.transfer(address(this).balance);
    }
}
