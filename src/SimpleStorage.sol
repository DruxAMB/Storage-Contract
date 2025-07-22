// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title SimpleStorage
 * @dev A simple contract to store and retrieve a value on Base
 */
contract SimpleStorage {
    uint256 private storedValue;
    address public owner;
    
    event ValueUpdated(uint256 newValue, address updatedBy);
    
    constructor() {
        owner = msg.sender;
        storedValue = 0;
    }
    
    /**
     * @dev Store a value
     * @param _value The value to store
     */
    function store(uint256 _value) public {
        storedValue = _value;
        emit ValueUpdated(_value, msg.sender);
    }
    
    /**
     * @dev Retrieve the stored value
     * @return The stored value
     */
    function retrieve() public view returns (uint256) {
        return storedValue;
    }
    
    /**
     * @dev Increment the stored value by 1
     */
    function increment() public {
        storedValue += 1;
        emit ValueUpdated(storedValue, msg.sender);
    }
    
    /**
     * @dev Get contract info
     * @return value The current stored value
     * @return contractOwner The address of the contract owner
     */
    function getInfo() public view returns (uint256 value, address contractOwner) {
        return (storedValue, owner);
    }
}
