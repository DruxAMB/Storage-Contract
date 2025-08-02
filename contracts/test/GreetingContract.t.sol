// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/GreetingContract.sol";

contract GreetingContractTest is Test {
    GreetingContract public greetingContract;
    address public owner;
    address public user1;
    address public user2;
    
    string constant DEFAULT_GREETING = "Hello, Base!";
    string constant USER1_GREETING = "GM from user1!";
    string constant USER2_GREETING = "Building on Base is awesome!";

    function setUp() public {
        owner = address(this);
        user1 = address(0x1);
        user2 = address(0x2);
        
        greetingContract = new GreetingContract(DEFAULT_GREETING);
    }

    function testInitialState() public {
        assertEq(greetingContract.defaultGreeting(), DEFAULT_GREETING);
        assertEq(greetingContract.owner(), owner);
        assertEq(greetingContract.totalGreetings(), 0);
    }

    function testSetGreeting() public {
        vm.prank(user1);
        greetingContract.setGreeting(USER1_GREETING);
        
        assertEq(greetingContract.getGreeting(user1), USER1_GREETING);
        assertEq(greetingContract.getTotalGreeters(), 1);
        assertTrue(greetingContract.hasCustomGreeting(user1));
    }

    function testGetDefaultGreeting() public {
        // User without custom greeting should get default
        assertEq(greetingContract.getGreeting(user1), DEFAULT_GREETING);
        assertFalse(greetingContract.hasCustomGreeting(user1));
    }

    function testMultipleUsers() public {
        vm.prank(user1);
        greetingContract.setGreeting(USER1_GREETING);
        
        vm.prank(user2);
        greetingContract.setGreeting(USER2_GREETING);
        
        assertEq(greetingContract.getGreeting(user1), USER1_GREETING);
        assertEq(greetingContract.getGreeting(user2), USER2_GREETING);
        assertEq(greetingContract.getTotalGreeters(), 2);
    }

    function testGetMyGreeting() public {
        vm.prank(user1);
        greetingContract.setGreeting(USER1_GREETING);
        
        vm.prank(user1);
        assertEq(greetingContract.getMyGreeting(), USER1_GREETING);
    }

    function testGreetingInfo() public {
        vm.prank(user1);
        greetingContract.setGreeting(USER1_GREETING);
        
        (string memory greeting, uint256 timestamp, bool hasCustom) = 
            greetingContract.getGreetingInfo(user1);
        
        assertEq(greeting, USER1_GREETING);
        assertTrue(hasCustom);
        assertGt(timestamp, 0);
    }

    function testUpdateDefaultGreeting() public {
        string memory newDefault = "Welcome to Base!";
        greetingContract.updateDefaultGreeting(newDefault);
        
        assertEq(greetingContract.defaultGreeting(), newDefault);
    }

    function testOnlyOwnerCanUpdateDefault() public {
        vm.prank(user1);
        vm.expectRevert("Only owner can update default greeting");
        greetingContract.updateDefaultGreeting("Unauthorized update");
    }

    function testEmptyGreetingReverts() public {
        vm.prank(user1);
        vm.expectRevert("Greeting cannot be empty");
        greetingContract.setGreeting("");
    }

    function testLongGreetingReverts() public {
        string memory longGreeting = "This is a very long greeting that exceeds the maximum allowed length of 280 characters. It should revert when trying to set it as a greeting. This message is intentionally made long to test the length validation in the smart contract. The contract should reject this message.";
        
        vm.prank(user1);
        vm.expectRevert("Greeting too long (max 280 characters)");
        greetingContract.setGreeting(longGreeting);
    }

    function testGetAllGreeters() public {
        vm.prank(user1);
        greetingContract.setGreeting(USER1_GREETING);
        
        vm.prank(user2);
        greetingContract.setGreeting(USER2_GREETING);
        
        address[] memory greeters = greetingContract.getAllGreeters();
        assertEq(greeters.length, 2);
        assertEq(greeters[0], user1);
        assertEq(greeters[1], user2);
    }

    function testGetContractInfo() public {
        vm.prank(user1);
        greetingContract.setGreeting(USER1_GREETING);
        
        (uint256 totalUsers, address contractOwner, string memory defaultMsg) = 
            greetingContract.getContractInfo();
        
        assertEq(totalUsers, 1);
        assertEq(contractOwner, owner);
        assertEq(defaultMsg, DEFAULT_GREETING);
    }

    function testGreetingSetEvent() public {
        vm.prank(user1);
        vm.expectEmit(true, false, false, true);
        emit GreetingContract.GreetingSet(user1, USER1_GREETING, block.timestamp);
        greetingContract.setGreeting(USER1_GREETING);
    }

    function testDefaultGreetingUpdatedEvent() public {
        string memory newDefault = "New default greeting";
        vm.expectEmit(false, false, false, true);
        emit GreetingContract.DefaultGreetingUpdated(newDefault, owner);
        greetingContract.updateDefaultGreeting(newDefault);
    }
}
