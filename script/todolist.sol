// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
contract TodoList {
    // Owner of the contract
    address public owner;
    
    // Array to store todo items (max 5)
    string[5] public todos;
    
    // Number of current items
    uint public itemCount;
    
    // Events
    event ItemAdded(uint index, string item);
    event ItemUpdated(uint index, string item);
    event ItemRemoved(uint index);
    
    // Modifier to check if caller is the owner
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    // Constructor sets the owner
    function todoList() public {
        owner = msg.sender;
        itemCount = 0;
    }
    
    // Add a new todo item
    function addItem(string memory _item) public onlyOwner {
        require(itemCount < 5, "Maximum 5 items allowed");
        todos[itemCount] = _item;
        emit ItemAdded(itemCount, _item);
        itemCount++;
    }
    
    // Update an existing todo item
    function updateItem(uint _index, string memory _item) public onlyOwner {
        require(_index < itemCount, "Index out of bounds");
        todos[_index] = _item;
        emit ItemUpdated(_index, _item);
    }
    
    // Remove a todo item
    function removeItem(uint _index) public onlyOwner {
        require(_index < itemCount, "Index out of bounds");
        
        // Shift all items after the removed item one position left
        for(uint i = _index; i < itemCount - 1; i++) {
            todos[i] = todos[i + 1];
        }
        
        // Clear the last item
        todos[itemCount - 1] = "";
        itemCount--;
        
        emit ItemRemoved(_index);
    }
    
    // Get all todo items
    function getAllItems() public view returns (string[5] memory) {
        return todos;
    }
    
    // Get a specific todo item
    function getItem(uint _index) public view returns (string memory) {
        require(_index < itemCount, "Index out of bounds");
        return todos[_index];
    }
} 