// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
 * @title DataFeed
 * @dev On-chain data oracle for simple use cases
 * @notice Allows authorized data providers to post values with time-weighted averaging
 */
contract DataFeed is AccessControl, Pausable {
    // Roles
    bytes32 public constant DATA_PROVIDER_ROLE = keccak256("DATA_PROVIDER_ROLE");
    bytes32 public constant ADMIN_ROLE = DEFAULT_ADMIN_ROLE;
    
    // Struct to represent a data feed
    struct Feed {
        string name;               // Name of the feed (e.g., "ETH-USD")
        string description;        // Description of the feed
        uint256 decimals;          // Number of decimals (e.g., 8 for price feeds)
        uint256 heartbeatHours;    // Maximum time between updates in hours
        uint256 latestValue;       // Latest value of the feed
        uint256 timestamp;         // Timestamp of the latest update
        address lastProvider;      // Address of the last provider
        bool active;               // Whether the feed is active
    }
    
    // Struct to represent a historical data point
    struct DataPoint {
        uint256 value;             // Value at this point
        uint256 timestamp;         // Timestamp of the update
        address provider;          // Provider who submitted this value
    }
    
    // Mapping from feed ID to Feed
    mapping(bytes32 => Feed) public feeds;
    
    // Mapping from feed ID to array of historical data points
    mapping(bytes32 => DataPoint[]) private feedHistory;
    
    // Mapping from feed ID to maximum history length
    mapping(bytes32 => uint256) public maxHistoryLength;
    
    // Default maximum history length
    uint256 public defaultMaxHistoryLength = 24; // 24 hours by default
    
    // Mapping from address to subscribed feeds
    mapping(address => bytes32[]) private subscriptions;
    
    // Array of all feed IDs
    bytes32[] public allFeeds;
    
    // Events
    event FeedCreated(
        bytes32 indexed feedId,
        string name,
        string description,
        uint256 decimals,
        uint256 heartbeatHours
    );
    
    event FeedUpdated(
        bytes32 indexed feedId,
        uint256 value,
        uint256 timestamp,
        address indexed provider
    );
    
    event FeedConfigUpdated(
        bytes32 indexed feedId,
        string name,
        string description,
        uint256 heartbeatHours,
        bool active
    );
    
    event ProviderAdded(address indexed provider);
    event ProviderRemoved(address indexed provider);
    
    event Subscribed(address indexed subscriber, bytes32 indexed feedId);
    event Unsubscribed(address indexed subscriber, bytes32 indexed feedId);
    
    /**
     * @dev Constructor
     */
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(DATA_PROVIDER_ROLE, msg.sender);
    }
    
    /**
     * @dev Create a new data feed
     * @param name Name of the feed
     * @param description Description of the feed
     * @param decimals Number of decimals
     * @param heartbeatHours Maximum time between updates in hours
     * @param initialValue Initial value of the feed
     * @param historyLength Maximum history length for this feed
     * @return feedId ID of the created feed
     */
    function createFeed(
        string memory name,
        string memory description,
        uint256 decimals,
        uint256 heartbeatHours,
        uint256 initialValue,
        uint256 historyLength
    ) external onlyRole(ADMIN_ROLE) returns (bytes32 feedId) {
        require(bytes(name).length > 0, "Name cannot be empty");
        require(heartbeatHours > 0, "Heartbeat must be positive");
        
        // Generate feed ID from name
        feedId = keccak256(abi.encodePacked(name));
        
        // Ensure feed doesn't already exist
        require(feeds[feedId].timestamp == 0, "Feed already exists");
        
        // Create the feed
        feeds[feedId] = Feed({
            name: name,
            description: description,
            decimals: decimals,
            heartbeatHours: heartbeatHours,
            latestValue: initialValue,
            timestamp: block.timestamp,
            lastProvider: msg.sender,
            active: true
        });
        
        // Set history length
        maxHistoryLength[feedId] = historyLength > 0 ? historyLength : defaultMaxHistoryLength;
        
        // Add initial data point
        feedHistory[feedId].push(DataPoint({
            value: initialValue,
            timestamp: block.timestamp,
            provider: msg.sender
        }));
        
        // Add to list of all feeds
        allFeeds.push(feedId);
        
        emit FeedCreated(feedId, name, description, decimals, heartbeatHours);
        emit FeedUpdated(feedId, initialValue, block.timestamp, msg.sender);
    }
    
    /**
     * @dev Update a feed with a new value
     * @param feedId ID of the feed to update
     * @param value New value for the feed
     */
    function updateFeed(bytes32 feedId, uint256 value) 
        external 
        onlyRole(DATA_PROVIDER_ROLE) 
        whenNotPaused 
    {
        Feed storage feed = feeds[feedId];
        require(feed.timestamp > 0, "Feed does not exist");
        require(feed.active, "Feed is not active");
        
        // Update feed
        feed.latestValue = value;
        feed.timestamp = block.timestamp;
        feed.lastProvider = msg.sender;
        
        // Add to history
        DataPoint[] storage history = feedHistory[feedId];
        
        // If history is at max length, remove oldest entry
        if (history.length >= maxHistoryLength[feedId]) {
            // Shift all elements left by one
            for (uint256 i = 0; i < history.length - 1; i++) {
                history[i] = history[i + 1];
            }
            history.pop(); // Remove the last duplicate
        }
        
        // Add new data point
        history.push(DataPoint({
            value: value,
            timestamp: block.timestamp,
            provider: msg.sender
        }));
        
        emit FeedUpdated(feedId, value, block.timestamp, msg.sender);
    }
    
    /**
     * @dev Update feed configuration
     * @param feedId ID of the feed to update
     * @param name New name (empty to keep current)
     * @param description New description (empty to keep current)
     * @param heartbeatHours New heartbeat hours (0 to keep current)
     * @param active Whether the feed is active
     */
    function updateFeedConfig(
        bytes32 feedId,
        string memory name,
        string memory description,
        uint256 heartbeatHours,
        bool active
    ) external onlyRole(ADMIN_ROLE) {
        Feed storage feed = feeds[feedId];
        require(feed.timestamp > 0, "Feed does not exist");
        
        if (bytes(name).length > 0) {
            feed.name = name;
        }
        
        if (bytes(description).length > 0) {
            feed.description = description;
        }
        
        if (heartbeatHours > 0) {
            feed.heartbeatHours = heartbeatHours;
        }
        
        feed.active = active;
        
        emit FeedConfigUpdated(
            feedId,
            feed.name,
            feed.description,
            feed.heartbeatHours,
            feed.active
        );
    }
    
    /**
     * @dev Get the latest value of a feed
     * @param feedId ID of the feed
     * @return value Latest value
     * @return timestamp Timestamp of the latest update
     * @return heartbeatExpired Whether the heartbeat has expired
     */
    function getLatestValue(bytes32 feedId) 
        external 
        view 
        returns (
            uint256 value,
            uint256 timestamp,
            bool heartbeatExpired
        ) 
    {
        Feed storage feed = feeds[feedId];
        require(feed.timestamp > 0, "Feed does not exist");
        
        return (
            feed.latestValue,
            feed.timestamp,
            block.timestamp > feed.timestamp + (feed.heartbeatHours * 1 hours)
        );
    }
    
    /**
     * @dev Get time-weighted average value over a period
     * @param feedId ID of the feed
     * @param timespan Timespan in seconds to calculate average over
     * @return twav Time-weighted average value
     * @return validDataPoints Number of data points used in calculation
     */
    function getTimeWeightedAverage(bytes32 feedId, uint256 timespan) 
        external 
        view 
        returns (uint256 twav, uint256 validDataPoints) 
    {
        require(timespan > 0, "Timespan must be positive");
        
        Feed storage feed = feeds[feedId];
        require(feed.timestamp > 0, "Feed does not exist");
        
        DataPoint[] storage history = feedHistory[feedId];
        uint256 earliestTimestamp = block.timestamp - timespan;
        
        // If no history or all history is too recent, return latest value
        if (history.length == 0 || history[0].timestamp > earliestTimestamp) {
            return (feed.latestValue, 1);
        }
        
        uint256 weightedSum = 0;
        uint256 totalWeight = 0;
        validDataPoints = 0;
        
        // Find the first data point within the timespan
        uint256 startIndex = 0;
        while (startIndex < history.length && history[startIndex].timestamp < earliestTimestamp) {
            startIndex++;
        }
        
        // If we went past all data points, use the most recent one
        if (startIndex == history.length) {
            startIndex = history.length - 1;
        }
        
        // Calculate time-weighted average
        for (uint256 i = startIndex; i < history.length; i++) {
            uint256 startTime = history[i].timestamp;
            uint256 endTime = i < history.length - 1 ? history[i + 1].timestamp : block.timestamp;
            
            // Ensure we're within the requested timespan
            if (startTime < earliestTimestamp) {
                startTime = earliestTimestamp;
            }
            
            uint256 timeWeight = endTime - startTime;
            weightedSum += history[i].value * timeWeight;
            totalWeight += timeWeight;
            validDataPoints++;
        }
        
        // Calculate weighted average
        if (totalWeight > 0) {
            twav = weightedSum / totalWeight;
        } else {
            twav = feed.latestValue;
            validDataPoints = 1;
        }
    }
    
    /**
     * @dev Get historical data for a feed
     * @param feedId ID of the feed
     * @param maxPoints Maximum number of points to return (0 for all)
     * @return values Array of values
     * @return timestamps Array of timestamps
     * @return providers Array of provider addresses
     */
    function getHistory(bytes32 feedId, uint256 maxPoints) 
        external 
        view 
        returns (
            uint256[] memory values,
            uint256[] memory timestamps,
            address[] memory providers
        ) 
    {
        DataPoint[] storage history = feedHistory[feedId];
        
        uint256 resultCount = maxPoints > 0 && maxPoints < history.length ? maxPoints : history.length;
        uint256 startIndex = history.length - resultCount;
        
        values = new uint256[](resultCount);
        timestamps = new uint256[](resultCount);
        providers = new address[](resultCount);
        
        for (uint256 i = 0; i < resultCount; i++) {
            DataPoint storage point = history[startIndex + i];
            values[i] = point.value;
            timestamps[i] = point.timestamp;
            providers[i] = point.provider;
        }
    }
    
    /**
     * @dev Get all feed IDs
     * @return feedIds Array of all feed IDs
     */
    function getAllFeeds() external view returns (bytes32[] memory feedIds) {
        return allFeeds;
    }
    
    /**
     * @dev Get active feed IDs
     * @return feedIds Array of active feed IDs
     */
    function getActiveFeeds() external view returns (bytes32[] memory feedIds) {
        uint256 activeCount = 0;
        
        // Count active feeds
        for (uint256 i = 0; i < allFeeds.length; i++) {
            if (feeds[allFeeds[i]].active) {
                activeCount++;
            }
        }
        
        // Collect active feed IDs
        feedIds = new bytes32[](activeCount);
        uint256 index = 0;
        
        for (uint256 i = 0; i < allFeeds.length; i++) {
            if (feeds[allFeeds[i]].active) {
                feedIds[index] = allFeeds[i];
                index++;
            }
        }
    }
    
    /**
     * @dev Subscribe to a feed
     * @param feedId ID of the feed to subscribe to
     */
    function subscribe(bytes32 feedId) external {
        Feed storage feed = feeds[feedId];
        require(feed.timestamp > 0, "Feed does not exist");
        
        bytes32[] storage userSubs = subscriptions[msg.sender];
        
        // Check if already subscribed
        for (uint256 i = 0; i < userSubs.length; i++) {
            if (userSubs[i] == feedId) {
                return; // Already subscribed
            }
        }
        
        // Add subscription
        userSubs.push(feedId);
        
        emit Subscribed(msg.sender, feedId);
    }
    
    /**
     * @dev Unsubscribe from a feed
     * @param feedId ID of the feed to unsubscribe from
     */
    function unsubscribe(bytes32 feedId) external {
        bytes32[] storage userSubs = subscriptions[msg.sender];
        
        // Find and remove subscription
        for (uint256 i = 0; i < userSubs.length; i++) {
            if (userSubs[i] == feedId) {
                // Replace with last element and pop
                userSubs[i] = userSubs[userSubs.length - 1];
                userSubs.pop();
                
                emit Unsubscribed(msg.sender, feedId);
                return;
            }
        }
    }
    
    /**
     * @dev Get subscriptions for a user
     * @param user User address
     * @return feedIds Array of subscribed feed IDs
     */
    function getSubscriptions(address user) external view returns (bytes32[] memory feedIds) {
        return subscriptions[user];
    }
    
    /**
     * @dev Add a data provider
     * @param provider Address of the provider to add
     */
    function addProvider(address provider) external onlyRole(ADMIN_ROLE) {
        grantRole(DATA_PROVIDER_ROLE, provider);
        emit ProviderAdded(provider);
    }
    
    /**
     * @dev Remove a data provider
     * @param provider Address of the provider to remove
     */
    function removeProvider(address provider) external onlyRole(ADMIN_ROLE) {
        revokeRole(DATA_PROVIDER_ROLE, provider);
        emit ProviderRemoved(provider);
    }
    
    /**
     * @dev Set default maximum history length
     * @param length New default history length
     */
    function setDefaultHistoryLength(uint256 length) external onlyRole(ADMIN_ROLE) {
        require(length > 0, "Length must be positive");
        defaultMaxHistoryLength = length;
    }
    
    /**
     * @dev Set history length for a specific feed
     * @param feedId ID of the feed
     * @param length New history length
     */
    function setFeedHistoryLength(bytes32 feedId, uint256 length) external onlyRole(ADMIN_ROLE) {
        require(feeds[feedId].timestamp > 0, "Feed does not exist");
        require(length > 0, "Length must be positive");
        maxHistoryLength[feedId] = length;
    }
    
    /**
     * @dev Pause the contract
     */
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }
    
    /**
     * @dev Unpause the contract
     */
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }
}
