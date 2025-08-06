// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v4.8.0/contracts/access/Ownable.sol";
import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v4.8.0/contracts/security/ReentrancyGuard.sol";

/**
 * @title SimpleSubscription
 * @dev A contract for a basic time-based subscription service.
 * @notice Users can pay a fee to become a subscriber for a fixed duration.
 */
contract SimpleSubscription is Ownable, ReentrancyGuard {

    // Struct to hold subscription details
    struct Subscription {
        uint256 expiresAt;
        bool isActive;
    }

    // State variables
    uint256 public subscriptionFee = 0.01 ether;
    uint256 public subscriptionDuration = 30 days;
    mapping(address => Subscription) public subscribers;

    // Events
    event Subscribed(address indexed user, uint256 expiresAt);
    event FeeUpdated(uint256 newFee);
    event DurationUpdated(uint256 newDuration);

    /**
     * @dev Constructor.
     */
    constructor() Ownable() {}

    /**
     * @notice Pays the fee to become a subscriber or renew a subscription.
     */
    function subscribe() external payable nonReentrant {
        require(msg.value == subscriptionFee, "Incorrect subscription fee");

        uint256 currentExpiration = subscribers[msg.sender].expiresAt;
        uint256 newExpiration;

        // If subscription is active, extend it. Otherwise, start a new one.
        if (currentExpiration > block.timestamp) {
            newExpiration = currentExpiration + subscriptionDuration;
        } else {
            newExpiration = block.timestamp + subscriptionDuration;
        }

        subscribers[msg.sender] = Subscription({
            expiresAt: newExpiration,
            isActive: true
        });

        emit Subscribed(msg.sender, newExpiration);
    }

    /**
     * @notice Checks if a user's subscription is currently active.
     * @param _user The address of the user to check.
     * @return True if the subscription is active, false otherwise.
     */
    function isSubscriptionActive(address _user) external view returns (bool) {
        return subscribers[_user].isActive && subscribers[_user].expiresAt > block.timestamp;
    }

    /**
     * @notice Allows the owner to withdraw collected fees.
     */
    function withdrawFees() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No fees to withdraw");
        payable(owner()).transfer(balance);
    }

    // --- Admin Functions ---

    /**
     * @notice Updates the subscription fee (owner only).
     * @param _newFee The new fee in wei.
     */
    function setSubscriptionFee(uint256 _newFee) external onlyOwner {
        subscriptionFee = _newFee;
        emit FeeUpdated(_newFee);
    }

    /**
     * @notice Updates the subscription duration (owner only).
     * @param _newDuration The new duration in seconds.
     */
    function setSubscriptionDuration(uint256 _newDuration) external onlyOwner {
        subscriptionDuration = _newDuration;
        emit DurationUpdated(_newDuration);
    }
}
