// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Attendance {
    address public owner;
    mapping(address => bool) public isPresent;

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function markPresent(address student) public onlyOwner {
        isPresent[student] = true;
    }

    function checkAttendance(address student) public view returns (bool) {
        return isPresent[student];
    }
} 