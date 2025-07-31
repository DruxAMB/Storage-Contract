// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v4.8.0/contracts/security/ReentrancyGuard.sol";
import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v4.8.0/contracts/access/Ownable.sol";

/**
 * @title SimpleRegistry
 * @dev Basic name/value registry system for key-value pairs
 * @notice Allows users to register names mapped to addresses or strings with ownership management
 */
contract SimpleRegistry is ReentrancyGuard, Ownable {
    // Registry entry types
    enum EntryType { ADDRESS, STRING }
    
    // Registry entry struct
    struct RegistryEntry {
        address owner;
        EntryType entryType;
        address addressValue;
        string stringValue;
        uint256 registeredAt;
        uint256 updatedAt;
        bool exists;
    }
    
    // State variables
    uint256 public totalEntries;
    uint256 public registrationFee = 0.001 ether;
    uint256 public transferFee = 0.0005 ether;
    
    // Mappings
    mapping(string => RegistryEntry) public registry;
    mapping(address => string[]) public ownerEntries;
    mapping(address => uint256) public ownerEntryCount;
    
    // Events
    event EntryRegistered(
        string indexed name,
        address indexed owner,
        EntryType entryType,
        address addressValue,
        string stringValue
    );
    
    event EntryUpdated(
        string indexed name,
        address indexed owner,
        EntryType entryType,
        address addressValue,
        string stringValue
    );
    
    event EntryTransferred(
        string indexed name,
        address indexed from,
        address indexed to
    );
    
    event EntryDeleted(string indexed name, address indexed owner);
    
    event FeesUpdated(uint256 registrationFee, uint256 transferFee);
    event FeesWithdrawn(address indexed owner, uint256 amount);
    
    /**
     * @dev Constructor
     */
    constructor() Ownable() {}
    
    /**
     * @dev Register a name with an address value
     * @param name The name to register
     * @param addressValue The address to map to the name
     */
    function registerAddress(string memory name, address addressValue) external payable nonReentrant {
        require(bytes(name).length > 0, "Name cannot be empty");
        require(bytes(name).length <= 64, "Name too long");
        require(addressValue != address(0), "Invalid address");
        require(!registry[name].exists, "Name already registered");
        require(msg.value >= registrationFee, "Insufficient registration fee");
        
        // Create registry entry
        registry[name] = RegistryEntry({
            owner: msg.sender,
            entryType: EntryType.ADDRESS,
            addressValue: addressValue,
            stringValue: "",
            registeredAt: block.timestamp,
            updatedAt: block.timestamp,
            exists: true
        });
        
        // Update owner tracking
        ownerEntries[msg.sender].push(name);
        ownerEntryCount[msg.sender]++;
        totalEntries++;
        
        emit EntryRegistered(name, msg.sender, EntryType.ADDRESS, addressValue, "");
    }
    
    /**
     * @dev Register a name with a string value
     * @param name The name to register
     * @param stringValue The string to map to the name
     */
    function registerString(string memory name, string memory stringValue) external payable nonReentrant {
        require(bytes(name).length > 0, "Name cannot be empty");
        require(bytes(name).length <= 64, "Name too long");
        require(bytes(stringValue).length > 0, "String value cannot be empty");
        require(bytes(stringValue).length <= 256, "String value too long");
        require(!registry[name].exists, "Name already registered");
        require(msg.value >= registrationFee, "Insufficient registration fee");
        
        // Create registry entry
        registry[name] = RegistryEntry({
            owner: msg.sender,
            entryType: EntryType.STRING,
            addressValue: address(0),
            stringValue: stringValue,
            registeredAt: block.timestamp,
            updatedAt: block.timestamp,
            exists: true
        });
        
        // Update owner tracking
        ownerEntries[msg.sender].push(name);
        ownerEntryCount[msg.sender]++;
        totalEntries++;
        
        emit EntryRegistered(name, msg.sender, EntryType.STRING, address(0), stringValue);
    }
    
    /**
     * @dev Update an existing address entry (owner only)
     * @param name The name to update
     * @param newAddressValue The new address value
     */
    function updateAddress(string memory name, address newAddressValue) external nonReentrant {
        require(registry[name].exists, "Name not registered");
        require(registry[name].owner == msg.sender, "Not the owner");
        require(registry[name].entryType == EntryType.ADDRESS, "Not an address entry");
        require(newAddressValue != address(0), "Invalid address");
        
        registry[name].addressValue = newAddressValue;
        registry[name].updatedAt = block.timestamp;
        
        emit EntryUpdated(name, msg.sender, EntryType.ADDRESS, newAddressValue, "");
    }
    
    /**
     * @dev Update an existing string entry (owner only)
     * @param name The name to update
     * @param newStringValue The new string value
     */
    function updateString(string memory name, string memory newStringValue) external nonReentrant {
        require(registry[name].exists, "Name not registered");
        require(registry[name].owner == msg.sender, "Not the owner");
        require(registry[name].entryType == EntryType.STRING, "Not a string entry");
        require(bytes(newStringValue).length > 0, "String value cannot be empty");
        require(bytes(newStringValue).length <= 256, "String value too long");
        
        registry[name].stringValue = newStringValue;
        registry[name].updatedAt = block.timestamp;
        
        emit EntryUpdated(name, msg.sender, EntryType.STRING, address(0), newStringValue);
    }
    
    /**
     * @dev Transfer ownership of a registry entry
     * @param name The name to transfer
     * @param newOwner The new owner address
     */
    function transferEntry(string memory name, address newOwner) external payable nonReentrant {
        require(registry[name].exists, "Name not registered");
        require(registry[name].owner == msg.sender, "Not the owner");
        require(newOwner != address(0), "Invalid new owner");
        require(newOwner != msg.sender, "Cannot transfer to yourself");
        require(msg.value >= transferFee, "Insufficient transfer fee");
        
        address oldOwner = registry[name].owner;
        
        // Update ownership
        registry[name].owner = newOwner;
        registry[name].updatedAt = block.timestamp;
        
        // Update owner tracking
        _removeFromOwnerEntries(oldOwner, name);
        ownerEntries[newOwner].push(name);
        ownerEntryCount[newOwner]++;
        
        emit EntryTransferred(name, oldOwner, newOwner);
    }
    
    /**
     * @dev Delete a registry entry (owner only)
     * @param name The name to delete
     */
    function deleteEntry(string memory name) external nonReentrant {
        require(registry[name].exists, "Name not registered");
        require(registry[name].owner == msg.sender, "Not the owner");
        
        // Remove from owner tracking
        _removeFromOwnerEntries(msg.sender, name);
        
        // Delete the entry
        delete registry[name];
        totalEntries--;
        
        emit EntryDeleted(name, msg.sender);
    }
    
    /**
     * @dev Look up an address value by name
     * @param name The name to look up
     * @return The address value associated with the name
     */
    function lookupAddress(string memory name) external view returns (address) {
        require(registry[name].exists, "Name not registered");
        require(registry[name].entryType == EntryType.ADDRESS, "Not an address entry");
        return registry[name].addressValue;
    }
    
    /**
     * @dev Look up a string value by name
     * @param name The name to look up
     * @return The string value associated with the name
     */
    function lookupString(string memory name) external view returns (string memory) {
        require(registry[name].exists, "Name not registered");
        require(registry[name].entryType == EntryType.STRING, "Not a string entry");
        return registry[name].stringValue;
    }
    
    /**
     * @dev Get complete registry entry information
     * @param name The name to look up
     * @return owner Owner of the entry
     * @return entryType Type of the entry
     * @return addressValue Address value (if applicable)
     * @return stringValue String value (if applicable)
     * @return registeredAt Registration timestamp
     * @return updatedAt Last update timestamp
     */
    function getEntry(string memory name) external view returns (
        address owner,
        EntryType entryType,
        address addressValue,
        string memory stringValue,
        uint256 registeredAt,
        uint256 updatedAt
    ) {
        require(registry[name].exists, "Name not registered");
        
        RegistryEntry memory entry = registry[name];
        return (
            entry.owner,
            entry.entryType,
            entry.addressValue,
            entry.stringValue,
            entry.registeredAt,
            entry.updatedAt
        );
    }
    
    /**
     * @dev Check if a name is registered
     * @param name The name to check
     * @return Whether the name is registered
     */
    function isRegistered(string memory name) external view returns (bool) {
        return registry[name].exists;
    }
    
    /**
     * @dev Get the owner of a registered name
     * @param name The name to check
     * @return The owner address
     */
    function getOwner(string memory name) external view returns (address) {
        require(registry[name].exists, "Name not registered");
        return registry[name].owner;
    }
    
    /**
     * @dev Get all entries owned by an address
     * @param owner The owner address
     * @return Array of names owned by the address
     */
    function getOwnerEntries(address owner) external view returns (string[] memory) {
        return ownerEntries[owner];
    }
    
    /**
     * @dev Get the number of entries owned by an address
     * @param owner The owner address
     * @return Number of entries owned
     */
    function getOwnerEntryCount(address owner) external view returns (uint256) {
        return ownerEntryCount[owner];
    }
    
    /**
     * @dev Update registration and transfer fees (owner only)
     * @param newRegistrationFee New registration fee
     * @param newTransferFee New transfer fee
     */
    function updateFees(uint256 newRegistrationFee, uint256 newTransferFee) external onlyOwner {
        registrationFee = newRegistrationFee;
        transferFee = newTransferFee;
        
        emit FeesUpdated(newRegistrationFee, newTransferFee);
    }
    
    /**
     * @dev Withdraw collected fees (owner only)
     */
    function withdrawFees() external onlyOwner nonReentrant {
        uint256 balance = address(this).balance;
        require(balance > 0, "No fees to withdraw");
        
        payable(owner()).transfer(balance);
        
        emit FeesWithdrawn(owner(), balance);
    }
    
    /**
     * @dev Get contract balance
     * @return Current contract balance
     */
    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
    
    /**
     * @dev Internal function to remove a name from owner's entry list
     * @param owner The owner address
     * @param name The name to remove
     */
    function _removeFromOwnerEntries(address owner, string memory name) internal {
        string[] storage entries = ownerEntries[owner];
        
        for (uint256 i = 0; i < entries.length; i++) {
            if (keccak256(bytes(entries[i])) == keccak256(bytes(name))) {
                // Move the last element to the current position and pop
                entries[i] = entries[entries.length - 1];
                entries.pop();
                ownerEntryCount[owner]--;
                break;
            }
        }
    }
}
