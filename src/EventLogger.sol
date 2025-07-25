// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title EventLogger
 * @dev A simple contract for logging and retrieving events/announcements
 * @notice Allows users to post events and retrieve them with timestamps
 */
contract EventLogger {
    
    // Structs
    struct Event {
        uint256 id;
        string title;
        string description;
        address creator;
        uint256 timestamp;
        string category;
        bool isActive;
    }
    
    // State variables
    mapping(uint256 => Event) public events;
    mapping(address => uint256[]) public userEvents;
    mapping(string => uint256[]) public categoryEvents;
    uint256 public eventCount;
    
    // Events
    event EventCreated(
        uint256 indexed eventId,
        address indexed creator,
        string title,
        string category,
        uint256 timestamp
    );
    
    event EventUpdated(
        uint256 indexed eventId,
        address indexed creator,
        string title,
        uint256 timestamp
    );
    
    event EventDeactivated(
        uint256 indexed eventId,
        address indexed creator,
        uint256 timestamp
    );
    
    /**
     * @dev Create a new event
     * @param title Event title
     * @param description Event description
     * @param category Event category
     * @return eventId The ID of the created event
     */
    function createEvent(
        string memory title,
        string memory description,
        string memory category
    ) external returns (uint256 eventId) {
        require(bytes(title).length > 0, "Title cannot be empty");
        require(bytes(description).length > 0, "Description cannot be empty");
        require(bytes(category).length > 0, "Category cannot be empty");
        
        eventId = eventCount++;
        
        events[eventId] = Event({
            id: eventId,
            title: title,
            description: description,
            creator: msg.sender,
            timestamp: block.timestamp,
            category: category,
            isActive: true
        });
        
        userEvents[msg.sender].push(eventId);
        categoryEvents[category].push(eventId);
        
        emit EventCreated(eventId, msg.sender, title, category, block.timestamp);
    }
    
    /**
     * @dev Update an existing event (only creator can update)
     * @param eventId The event ID to update
     * @param title New event title
     * @param description New event description
     * @param category New event category
     */
    function updateEvent(
        uint256 eventId,
        string memory title,
        string memory description,
        string memory category
    ) external {
        require(eventId < eventCount, "Event does not exist");
        require(bytes(title).length > 0, "Title cannot be empty");
        require(bytes(description).length > 0, "Description cannot be empty");
        require(bytes(category).length > 0, "Category cannot be empty");
        
        Event storage eventItem = events[eventId];
        require(msg.sender == eventItem.creator, "Only creator can update event");
        require(eventItem.isActive, "Event is not active");
        
        // Remove from old category
        _removeFromCategory(eventItem.category, eventId);
        
        // Update event
        eventItem.title = title;
        eventItem.description = description;
        eventItem.category = category;
        
        // Add to new category
        categoryEvents[category].push(eventId);
        
        emit EventUpdated(eventId, msg.sender, title, block.timestamp);
    }
    
    /**
     * @dev Deactivate an event (only creator can deactivate)
     * @param eventId The event ID to deactivate
     */
    function deactivateEvent(uint256 eventId) external {
        require(eventId < eventCount, "Event does not exist");
        
        Event storage eventItem = events[eventId];
        require(msg.sender == eventItem.creator, "Only creator can deactivate event");
        require(eventItem.isActive, "Event already inactive");
        
        eventItem.isActive = false;
        
        emit EventDeactivated(eventId, msg.sender, block.timestamp);
    }
    
    /**
     * @dev Get event information
     * @param eventId The event ID
     * @return title Event title
     * @return description Event description
     * @return creator Event creator address
     * @return timestamp Creation timestamp
     * @return category Event category
     * @return isActive Whether event is active
     */
    function getEvent(uint256 eventId) external view returns (
        string memory title,
        string memory description,
        address creator,
        uint256 timestamp,
        string memory category,
        bool isActive
    ) {
        require(eventId < eventCount, "Event does not exist");
        
        Event storage eventItem = events[eventId];
        return (
            eventItem.title,
            eventItem.description,
            eventItem.creator,
            eventItem.timestamp,
            eventItem.category,
            eventItem.isActive
        );
    }
    
    /**
     * @dev Get events created by a user
     * @param user The user address
     * @return eventIds Array of event IDs created by user
     */
    function getUserEvents(address user) external view returns (uint256[] memory eventIds) {
        return userEvents[user];
    }
    
    /**
     * @dev Get events by category
     * @param category The category name
     * @return eventIds Array of event IDs in the category
     */
    function getEventsByCategory(string memory category) external view returns (uint256[] memory eventIds) {
        return categoryEvents[category];
    }
    
    /**
     * @dev Get recent events (last N events)
     * @param count Number of recent events to retrieve
     * @return eventIds Array of recent event IDs
     */
    function getRecentEvents(uint256 count) external view returns (uint256[] memory eventIds) {
        if (count > eventCount) {
            count = eventCount;
        }
        
        eventIds = new uint256[](count);
        
        for (uint256 i = 0; i < count; i++) {
            eventIds[i] = eventCount - 1 - i;
        }
    }
    
    /**
     * @dev Get active events only
     * @param offset Starting index for pagination
     * @param limit Maximum number of events to return
     * @return eventIds Array of active event IDs
     */
    function getActiveEvents(uint256 offset, uint256 limit) external view returns (uint256[] memory eventIds) {
        uint256 activeCount = 0;
        
        // Count active events
        for (uint256 i = 0; i < eventCount; i++) {
            if (events[i].isActive) {
                activeCount++;
            }
        }
        
        if (offset >= activeCount) {
            return new uint256[](0);
        }
        
        uint256 end = offset + limit;
        if (end > activeCount) {
            end = activeCount;
        }
        
        eventIds = new uint256[](end - offset);
        uint256 currentIndex = 0;
        uint256 resultIndex = 0;
        
        for (uint256 i = 0; i < eventCount && resultIndex < (end - offset); i++) {
            if (events[i].isActive) {
                if (currentIndex >= offset) {
                    eventIds[resultIndex] = i;
                    resultIndex++;
                }
                currentIndex++;
            }
        }
    }
    
    /**
     * @dev Get total number of events
     * @return count Total event count
     */
    function getTotalEvents() external view returns (uint256 count) {
        return eventCount;
    }
    
    /**
     * @dev Get total number of active events
     * @return count Active event count
     */
    function getActiveEventCount() external view returns (uint256 count) {
        uint256 activeCount = 0;
        for (uint256 i = 0; i < eventCount; i++) {
            if (events[i].isActive) {
                activeCount++;
            }
        }
        return activeCount;
    }
    
    /**
     * @dev Internal function to remove event from category array
     * @param category Category to remove from
     * @param eventId Event ID to remove
     */
    function _removeFromCategory(string memory category, uint256 eventId) internal {
        uint256[] storage categoryEventIds = categoryEvents[category];
        
        for (uint256 i = 0; i < categoryEventIds.length; i++) {
            if (categoryEventIds[i] == eventId) {
                categoryEventIds[i] = categoryEventIds[categoryEventIds.length - 1];
                categoryEventIds.pop();
                break;
            }
        }
    }
}
