// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title GreetingContract
 * @dev A contract for storing and managing personalized greetings on Base
 * @notice Users can set their own greetings and view others' greetings
 */
contract GreetingContract {
    // State variables
    mapping(address => string) private userGreetings;
    mapping(address => uint256) private greetingTimestamps;
    address[] private greeters;
    address public owner;
    string public defaultGreeting;
    uint256 public totalGreetings;
    
    // Events
    event GreetingSet(address indexed user, string greeting, uint256 timestamp);
    event DefaultGreetingUpdated(string newDefault, address updatedBy);
    
    // Constructor
    constructor(string memory _defaultGreeting) {
        owner = msg.sender;
        defaultGreeting = _defaultGreeting;
        totalGreetings = 0;
    }
    
    /**
     * @dev Set a personalized greeting for the caller
     * @param _greeting The greeting message to store
     */
    function setGreeting(string memory _greeting) public {
        require(bytes(_greeting).length > 0, "Greeting cannot be empty");
        require(bytes(_greeting).length <= 280, "Greeting too long (max 280 characters)");
        
        // If this is the user's first greeting, add them to greeters array
        if (bytes(userGreetings[msg.sender]).length == 0) {
            greeters.push(msg.sender);
            totalGreetings++;
        }
        
        userGreetings[msg.sender] = _greeting;
        greetingTimestamps[msg.sender] = block.timestamp;
        
        emit GreetingSet(msg.sender, _greeting, block.timestamp);
    }
    
    /**
     * @dev Get the greeting for a specific address
     * @param _user The address to get the greeting for
     * @return The user's greeting or default greeting if not set
     */
    function getGreeting(address _user) public view returns (string memory) {
        if (bytes(userGreetings[_user]).length > 0) {
            return userGreetings[_user];
        }
        return defaultGreeting;
    }
    
    /**
     * @dev Get the caller's own greeting
     * @return The caller's greeting or default greeting if not set
     */
    function getMyGreeting() public view returns (string memory) {
        return getGreeting(msg.sender);
    }
    
    /**
     * @dev Get greeting info for a specific user
     * @param _user The address to get info for
     * @return greeting The user's greeting
     * @return timestamp When the greeting was last updated
     * @return hasCustom Whether the user has set a custom greeting
     */
    function getGreetingInfo(address _user) public view returns (
        string memory greeting,
        uint256 timestamp,
        bool hasCustom
    ) {
        hasCustom = bytes(userGreetings[_user]).length > 0;
        greeting = hasCustom ? userGreetings[_user] : defaultGreeting;
        timestamp = greetingTimestamps[_user];
    }
    
    /**
     * @dev Get all addresses that have set greetings
     * @return Array of addresses that have set custom greetings
     */
    function getAllGreeters() public view returns (address[] memory) {
        return greeters;
    }
    
    /**
     * @dev Get the total number of unique greeters
     * @return The count of users who have set greetings
     */
    function getTotalGreeters() public view returns (uint256) {
        return totalGreetings;
    }
    
    /**
     * @dev Update the default greeting (owner only)
     * @param _newDefault The new default greeting
     */
    function updateDefaultGreeting(string memory _newDefault) public {
        require(msg.sender == owner, "Only owner can update default greeting");
        require(bytes(_newDefault).length > 0, "Default greeting cannot be empty");
        
        defaultGreeting = _newDefault;
        emit DefaultGreetingUpdated(_newDefault, msg.sender);
    }
    
    /**
     * @dev Check if an address has set a custom greeting
     * @param _user The address to check
     * @return True if the user has set a custom greeting
     */
    function hasCustomGreeting(address _user) public view returns (bool) {
        return bytes(userGreetings[_user]).length > 0;
    }
    
    /**
     * @dev Get contract statistics
     * @return totalUsers Total number of users with greetings
     * @return contractOwner Address of the contract owner
     * @return defaultMsg The current default greeting
     */
    function getContractInfo() public view returns (
        uint256 totalUsers,
        address contractOwner,
        string memory defaultMsg
    ) {
        return (totalGreetings, owner, defaultGreeting);
    }
}
