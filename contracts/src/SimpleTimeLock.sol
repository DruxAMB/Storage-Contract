// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v4.8.0/contracts/security/ReentrancyGuard.sol";

/**
 * @title SimpleTimeLock
 * @dev A contract that allows users to lock ETH until a specified time.
 * @notice Users can deposit funds and can only withdraw them after the unlock time has passed.
 */
contract SimpleTimeLock is ReentrancyGuard {

    // Struct to hold lock information
    struct Lock {
        uint256 amount;
        uint256 unlockTime;
    }

    // Mapping from an address to their lock
    mapping(address => Lock) public locks;

    // Events
    event Deposited(address indexed user, uint256 amount, uint256 unlockTime);
    event Withdrawn(address indexed user, uint256 amount);

    /**
     * @notice Deposits ETH into a time lock.
     * @dev A user can only have one active lock at a time. A new deposit will overwrite an old one if the old one was already withdrawn.
     * @param _unlockTime The timestamp (in seconds) when the funds can be withdrawn.
     */
    function deposit(uint256 _unlockTime) external payable nonReentrant {
        require(msg.value > 0, "Deposit amount must be positive");
        require(_unlockTime > block.timestamp, "Unlock time must be in the future");

        // A user can only create a new lock if their previous one is empty.
        require(locks[msg.sender].amount == 0, "You already have an active lock");

        locks[msg.sender] = Lock({
            amount: msg.value,
            unlockTime: _unlockTime
        });

        emit Deposited(msg.sender, msg.value, _unlockTime);
    }

    /**
     * @notice Withdraws the locked ETH after the unlock time has passed.
     */
    function withdraw() external nonReentrant {
        Lock storage userLock = locks[msg.sender];
        require(userLock.amount > 0, "No funds locked");
        require(block.timestamp >= userLock.unlockTime, "Lock time has not passed");

        uint256 amount = userLock.amount;
        userLock.amount = 0; // Prevent re-entrancy

        payable(msg.sender).transfer(amount);

        emit Withdrawn(msg.sender, amount);
    }

    /**
     * @notice Gets the lock details for the calling address.
     * @return The amount locked and the unlock timestamp.
     */
    function getMyLock() external view returns (uint256 amount, uint256 unlockTime) {
        Lock storage userLock = locks[msg.sender];
        return (userLock.amount, userLock.unlockTime);
    }
}
