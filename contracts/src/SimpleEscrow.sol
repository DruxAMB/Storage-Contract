// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v4.8.0/contracts/security/ReentrancyGuard.sol";

/**
 * @title SimpleEscrow
 * @dev A contract to hold funds for a transaction between a buyer and a seller.
 * @notice An arbiter can resolve disputes. Funds are released upon buyer confirmation.
 */
contract SimpleEscrow is ReentrancyGuard {

    // Enum for escrow status
    enum Status { AWAITING_DELIVERY, COMPLETE, DISPUTED, RESOLVED }

    // Struct for an escrow agreement
    struct Escrow {
        address payable buyer;
        address payable seller;
        address arbiter;
        uint256 amount;
        Status status;
    }

    // State variables
    uint256 public escrowCount;
    mapping(uint256 => Escrow) public escrows;

    // Events
    event EscrowCreated(uint256 indexed escrowId, address indexed buyer, address indexed seller, address arbiter, uint256 amount);
    event FundsReleased(uint256 indexed escrowId, address indexed receiver, uint256 amount);
    event DisputeRaised(uint256 indexed escrowId);
    event DisputeResolved(uint256 indexed escrowId, address indexed receiver, uint256 amount);

    /**
     * @notice Creates a new escrow agreement. The sender is the buyer.
     * @param _seller The address of the seller.
     * @param _arbiter The address of the arbiter for dispute resolution.
     * @return The ID of the new escrow.
     */
    function createEscrow(address _seller, address _arbiter) external payable returns (uint256) {
        require(msg.value > 0, "Amount must be positive");
        require(_seller != address(0) && _seller != msg.sender, "Invalid seller");
        require(_arbiter != address(0) && _arbiter != msg.sender && _arbiter != _seller, "Invalid arbiter");

        uint256 escrowId = escrowCount;
        escrows[escrowId] = Escrow({
            buyer: payable(msg.sender),
            seller: payable(_seller),
            arbiter: _arbiter,
            amount: msg.value,
            status: Status.AWAITING_DELIVERY
        });

        escrowCount++;
        emit EscrowCreated(escrowId, msg.sender, _seller, _arbiter, msg.value);
        return escrowId;
    }

    /**
     * @notice The buyer confirms delivery, releasing funds to the seller.
     * @param _escrowId The ID of the escrow.
     */
    function confirmDelivery(uint256 _escrowId) external nonReentrant {
        Escrow storage e = escrows[_escrowId];
        require(msg.sender == e.buyer, "Only buyer can confirm");
        require(e.status == Status.AWAITING_DELIVERY, "Escrow not awaiting delivery");

        e.status = Status.COMPLETE;
        e.seller.transfer(e.amount);

        emit FundsReleased(_escrowId, e.seller, e.amount);
    }

    /**
     * @notice Raises a dispute. Can be called by buyer or seller.
     * @param _escrowId The ID of the escrow.
     */
    function raiseDispute(uint256 _escrowId) external {
        Escrow storage e = escrows[_escrowId];
        require(msg.sender == e.buyer || msg.sender == e.seller, "Only buyer or seller can dispute");
        require(e.status == Status.AWAITING_DELIVERY, "Escrow not awaiting delivery");

        e.status = Status.DISPUTED;
        emit DisputeRaised(_escrowId);
    }

    /**
     * @notice The arbiter resolves a dispute.
     * @param _escrowId The ID of the escrow.
     * @param _releaseToSeller If true, funds go to seller. If false, funds go to buyer.
     */
    function resolveDispute(uint256 _escrowId, bool _releaseToSeller) external nonReentrant {
        Escrow storage e = escrows[_escrowId];
        require(msg.sender == e.arbiter, "Only arbiter can resolve");
        require(e.status == Status.DISPUTED, "Escrow not in dispute");

        e.status = Status.RESOLVED;
        address payable receiver = _releaseToSeller ? e.seller : e.buyer;
        receiver.transfer(e.amount);

        emit DisputeResolved(_escrowId, receiver, e.amount);
    }
}
