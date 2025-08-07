// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v4.8.0/contracts/access/Ownable.sol";
import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v4.8.0/contracts/security/ReentrancyGuard.sol";

/**
 * @title DigitalWill
 * @dev A contract that transfers funds to an heir if the owner is inactive.
 * @notice The owner must check in periodically to prevent the heir from claiming funds.
 */
contract DigitalWill is Ownable, ReentrancyGuard {

    // State variables
    address public heir;
    uint256 public lastCheckIn;
    uint256 public inactivityPeriod; // in seconds

    // Events
    event HeirChanged(address indexed newHeir);
    event InactivityPeriodChanged(uint256 newPeriod);
    event CheckedIn(address indexed owner, uint256 timestamp);
    event InheritanceClaimed(address indexed heir, uint256 amount);
    event FundsDeposited(uint256 amount);

    /**
     * @notice Constructor to set up the will.
     * @param _heir The address of the designated heir.
     * @param _inactivityPeriodInDays The number of days of inactivity before the heir can claim.
     */
    constructor(address _heir, uint256 _inactivityPeriodInDays) Ownable() {
        require(_heir != address(0), "Heir cannot be zero address");
        require(_inactivityPeriodInDays > 0, "Inactivity period must be positive");
        heir = _heir;
        inactivityPeriod = _inactivityPeriodInDays * 1 days;
        lastCheckIn = block.timestamp;
        emit HeirChanged(_heir);
        emit InactivityPeriodChanged(inactivityPeriod);
    }

    /**
     * @notice Allows the owner to deposit ETH into the will.
     */
    function deposit() external payable onlyOwner {
        require(msg.value > 0, "Deposit amount must be positive");
        emit FundsDeposited(msg.value);
    }

    /**
     * @notice Owner checks in to reset the inactivity timer.
     */
    function checkIn() external onlyOwner {
        lastCheckIn = block.timestamp;
        emit CheckedIn(owner(), block.timestamp);
    }

    /**
     * @notice Allows the heir to claim the funds after the inactivity period has passed.
     */
    function claimInheritance() external nonReentrant {
        require(msg.sender == heir, "Only the heir can claim");
        require(block.timestamp > lastCheckIn + inactivityPeriod, "Inactivity period has not passed");

        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to claim");

        payable(heir).transfer(balance);
        emit InheritanceClaimed(heir, balance);
    }

    // --- Admin Functions ---

    /**
     * @notice Allows the owner to change the designated heir.
     * @param _newHeir The address of the new heir.
     */
    function setHeir(address _newHeir) external onlyOwner {
        require(_newHeir != address(0), "Heir cannot be zero address");
        heir = _newHeir;
        emit HeirChanged(_newHeir);
    }

    /**
     * @notice Allows the owner to update the inactivity period.
     * @param _newInactivityPeriodInDays The new period in days.
     */
    function setInactivityPeriod(uint256 _newInactivityPeriodInDays) external onlyOwner {
        require(_newInactivityPeriodInDays > 0, "Inactivity period must be positive");
        inactivityPeriod = _newInactivityPeriodInDays * 1 days;
        emit InactivityPeriodChanged(inactivityPeriod);
    }
}
