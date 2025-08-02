// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v4.8.0/contracts/access/Ownable.sol";
import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v4.8.0/contracts/security/ReentrancyGuard.sol";

/**
 * @title SimpleGifting
 * @dev A contract for sending and claiming on-chain ETH gifts.
 * @notice Allows users to send ETH with a message to a recipient, who can then claim it.
 */
contract SimpleGifting is Ownable, ReentrancyGuard {

    // Enum for the status of a gift
    enum GiftStatus { PENDING, CLAIMED, CANCELED }

    // Struct to hold gift information
    struct Gift {
        address sender;
        address recipient;
        uint256 amount;
        string message;
        uint256 createdAt;
        GiftStatus status;
        bool exists;
    }

    // State variables
    uint256 public giftCount;
    mapping(uint256 => Gift) public gifts;
    mapping(address => uint256[]) public giftsSent;
    mapping(address => uint256[]) public giftsReceived;

    // Events
    event GiftSent(
        uint256 indexed giftId,
        address indexed sender,
        address indexed recipient,
        uint256 amount,
        string message
    );

    event GiftClaimed(uint256 indexed giftId, address indexed recipient, uint256 amount);
    event GiftCanceled(uint256 indexed giftId, address indexed sender, uint256 amount);

    /**
     * @dev Constructor.
     */
    constructor() Ownable() {}

    /**
     * @notice Sends a gift to a recipient.
     * @param _recipient The address of the gift recipient.
     * @param _message A message to include with the gift.
     * @return The ID of the newly created gift.
     */
    function sendGift(address _recipient, string memory _message)
        external
        payable
        nonReentrant
        returns (uint256)
    {
        require(_recipient != address(0), "Invalid recipient");
        require(msg.value > 0, "Gift amount must be positive");

        uint256 giftId = giftCount;
        gifts[giftId] = Gift({
            sender: msg.sender,
            recipient: _recipient,
            amount: msg.value,
            message: _message,
            createdAt: block.timestamp,
            status: GiftStatus.PENDING,
            exists: true
        });

        giftsSent[msg.sender].push(giftId);
        giftsReceived[_recipient].push(giftId);
        giftCount++;

        emit GiftSent(giftId, msg.sender, _recipient, msg.value, _message);

        return giftId;
    }

    /**
     * @notice Claims a pending gift.
     * @param _giftId The ID of the gift to claim.
     */
    function claimGift(uint256 _giftId) external nonReentrant {
        require(_giftId < giftCount && gifts[_giftId].exists, "Gift does not exist");
        Gift storage gift = gifts[_giftId];

        require(msg.sender == gift.recipient, "Not the recipient");
        require(gift.status == GiftStatus.PENDING, "Gift not pending");

        gift.status = GiftStatus.CLAIMED;
        uint256 amount = gift.amount;

        // Transfer the gift amount to the recipient
        payable(gift.recipient).transfer(amount);

        emit GiftClaimed(_giftId, gift.recipient, amount);
    }

    /**
     * @notice Cancels a pending gift and refunds the sender.
     * @param _giftId The ID of the gift to cancel.
     */
    function cancelGift(uint256 _giftId) external nonReentrant {
        require(_giftId < giftCount && gifts[_giftId].exists, "Gift does not exist");
        Gift storage gift = gifts[_giftId];

        require(msg.sender == gift.sender, "Not the sender");
        require(gift.status == GiftStatus.PENDING, "Gift not pending");

        gift.status = GiftStatus.CANCELED;
        uint256 amount = gift.amount;

        // Refund the gift amount to the sender
        payable(gift.sender).transfer(amount);

        emit GiftCanceled(_giftId, gift.sender, amount);
    }

    /**
     * @notice Gets the details of a specific gift.
     * @param _giftId The ID of the gift.
     * @return All details of the gift struct.
     */
    function getGiftDetails(uint256 _giftId)
        external
        view
        returns (
            address sender,
            address recipient,
            uint256 amount,
            string memory message,
            uint256 createdAt,
            GiftStatus status
        )
    {
        require(_giftId < giftCount && gifts[_giftId].exists, "Gift does not exist");
        Gift storage gift = gifts[_giftId];
        return (
            gift.sender,
            gift.recipient,
            gift.amount,
            gift.message,
            gift.createdAt,
            gift.status
        );
    }

    /**
     * @notice Gets all gift IDs sent by a specific address.
     * @param _sender The address of the sender.
     * @return An array of gift IDs.
     */
    function getGiftsSentBy(address _sender) external view returns (uint256[] memory) {
        return giftsSent[_sender];
    }

    /**
     * @notice Gets all gift IDs received by a specific address.
     * @param _recipient The address of the recipient.
     * @return An array of gift IDs.
     */
    function getGiftsReceivedBy(address _recipient) external view returns (uint256[] memory) {
        return giftsReceived[_recipient];
    }
}
