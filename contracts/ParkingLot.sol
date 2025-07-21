// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract ParkingLot {
    address public owner;
    uint256 public totalSpots;
    mapping(uint256 => address) public spotToUser;
    event Parked(uint256 indexed spot, address indexed user);
    event Left(uint256 indexed spot, address indexed user);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    constructor(uint256 _totalSpots) {
        owner = msg.sender;
        totalSpots = _totalSpots;
    }

    function park(uint256 spot) public {
        require(spot > 0 && spot <= totalSpots, "Invalid spot");
        require(spotToUser[spot] == address(0), "Spot occupied");
        spotToUser[spot] = msg.sender;
        emit Parked(spot, msg.sender);
    }

    function leave(uint256 spot) public {
        require(spotToUser[spot] == msg.sender, "Not your spot");
        spotToUser[spot] = address(0);
        emit Left(spot, msg.sender);
    }

    function isOccupied(uint256 spot) public view returns (bool) {
        return spotToUser[spot] != address(0);
    }
} 