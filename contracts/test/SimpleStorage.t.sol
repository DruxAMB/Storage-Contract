// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/SimpleStorage.sol";

contract SimpleStorageTest is Test {
    SimpleStorage public simpleStorage;
    address public owner;
    address public user1;

    function setUp() public {
        owner = address(this);
        user1 = address(0x1);
        simpleStorage = new SimpleStorage();
    }

    function testInitialValue() public {
        assertEq(simpleStorage.retrieve(), 0);
    }

    function testStore() public {
        simpleStorage.store(42);
        assertEq(simpleStorage.retrieve(), 42);
    }

    function testIncrement() public {
        simpleStorage.store(10);
        simpleStorage.increment();
        assertEq(simpleStorage.retrieve(), 11);
    }

    function testGetInfo() public {
        simpleStorage.store(100);
        (uint256 value, address contractOwner) = simpleStorage.getInfo();
        assertEq(value, 100);
        assertEq(contractOwner, owner);
    }

    function testStoreEvent() public {
        vm.expectEmit(true, true, false, true);
        emit SimpleStorage.ValueUpdated(42, address(this));
        simpleStorage.store(42);
    }

    function testIncrementEvent() public {
        simpleStorage.store(5);
        vm.expectEmit(true, true, false, true);
        emit SimpleStorage.ValueUpdated(6, address(this));
        simpleStorage.increment();
    }
}
