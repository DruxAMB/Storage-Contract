// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title EscrowContract
 * @dev Secure escrow service for payments between parties with dispute resolution
 * @notice Perfect for marketplace transactions with built-in arbitration system
 */
contract EscrowContract {
    // Enums
    enum EscrowState {
        AWAITING_PAYMENT,
        AWAITING_DELIVERY,
        COMPLETE,
        DISPUTED,
        REFUNDED
    }

    // Structs
    struct Escrow {
        uint256 id;
        address buyer;
        address seller;
        address arbiter;
        uint256 amount;
        string description;
        EscrowState state;
        uint256 createdAt;
        uint256 deliveryDeadline;
        bool buyerApproved;
        bool sellerConfirmed;
        uint256 disputeRaisedAt;
        string disputeReason;
    }

    // State variables
    mapping(uint256 => Escrow) public escrows;
    mapping(address => uint256[]) public buyerEscrows;
    mapping(address => uint256[]) public sellerEscrows;
    mapping(address => uint256[]) public arbiterEscrows;
    
    uint256 public escrowCount;
    uint256 public arbiterFeePercent; // Fee percentage (in basis points, e.g., 250 = 2.5%)
    address public platformOwner;
    uint256 public platformFeePercent; // Platform fee (in basis points)
    
    mapping(address => bool) public approvedArbiters;
    mapping(address => uint256) public arbiterFees; // Collected fees for arbiters
    mapping(address => uint256) public platformFees; // Collected platform fees

    // Events
    event EscrowCreated(
        uint256 indexed escrowId,
        address indexed buyer,
        address indexed seller,
        address arbiter,
        uint256 amount,
        string description
    );
    event PaymentDeposited(uint256 indexed escrowId, address indexed buyer, uint256 amount);
    event DeliveryConfirmed(uint256 indexed escrowId, address indexed seller);
    event PaymentApproved(uint256 indexed escrowId, address indexed buyer);
    event PaymentReleased(uint256 indexed escrowId, address indexed seller, uint256 amount);
    event DisputeRaised(uint256 indexed escrowId, address indexed raiser, string reason);
    event DisputeResolved(uint256 indexed escrowId, address indexed arbiter, bool buyerWins);
    event EscrowRefunded(uint256 indexed escrowId, address indexed buyer, uint256 amount);
    event ArbiterAdded(address indexed arbiter);
    event ArbiterRemoved(address indexed arbiter);
    event FeesWithdrawn(address indexed recipient, uint256 amount);

    // Modifiers
    modifier onlyPlatformOwner() {
        require(msg.sender == platformOwner, "Not platform owner");
        _;
    }
    
    modifier onlyBuyer(uint256 _escrowId) {
        require(msg.sender == escrows[_escrowId].buyer, "Not the buyer");
        _;
    }
    
    modifier onlySeller(uint256 _escrowId) {
        require(msg.sender == escrows[_escrowId].seller, "Not the seller");
        _;
    }
    
    modifier onlyArbiter(uint256 _escrowId) {
        require(msg.sender == escrows[_escrowId].arbiter, "Not the arbiter");
        _;
    }
    
    modifier onlyApprovedArbiter() {
        require(approvedArbiters[msg.sender], "Not an approved arbiter");
        _;
    }
    
    modifier escrowExists(uint256 _escrowId) {
        require(_escrowId < escrowCount, "Escrow does not exist");
        _;
    }
    
    modifier inState(uint256 _escrowId, EscrowState _state) {
        require(escrows[_escrowId].state == _state, "Invalid escrow state");
        _;
    }

    /**
     * @dev Constructor sets platform owner and fee structure
     * @param _arbiterFeePercent Arbiter fee percentage in basis points
     * @param _platformFeePercent Platform fee percentage in basis points
     */
    constructor(uint256 _arbiterFeePercent, uint256 _platformFeePercent) {
        require(_arbiterFeePercent <= 1000, "Arbiter fee too high"); // Max 10%
        require(_platformFeePercent <= 500, "Platform fee too high"); // Max 5%
        
        platformOwner = msg.sender;
        arbiterFeePercent = _arbiterFeePercent;
        platformFeePercent = _platformFeePercent;
        
        // Platform owner is automatically an approved arbiter
        approvedArbiters[msg.sender] = true;
        emit ArbiterAdded(msg.sender);
    }

    /**
     * @dev Create a new escrow
     * @param _seller Seller address
     * @param _arbiter Arbiter address
     * @param _description Description of the transaction
     * @param _deliveryDays Number of days for delivery deadline
     * @return escrowId The created escrow ID
     */
    function createEscrow(
        address _seller,
        address _arbiter,
        string memory _description,
        uint256 _deliveryDays
    ) external payable returns (uint256 escrowId) {
        require(_seller != address(0), "Invalid seller address");
        require(_arbiter != address(0), "Invalid arbiter address");
        require(approvedArbiters[_arbiter], "Arbiter not approved");
        require(msg.value > 0, "Payment required");
        require(_deliveryDays > 0 && _deliveryDays <= 365, "Invalid delivery days");
        require(_seller != msg.sender, "Buyer cannot be seller");
        require(_arbiter != msg.sender && _arbiter != _seller, "Invalid arbiter");

        escrowId = escrowCount++;
        
        escrows[escrowId] = Escrow({
            id: escrowId,
            buyer: msg.sender,
            seller: _seller,
            arbiter: _arbiter,
            amount: msg.value,
            description: _description,
            state: EscrowState.AWAITING_DELIVERY,
            createdAt: block.timestamp,
            deliveryDeadline: block.timestamp + (_deliveryDays * 1 days),
            buyerApproved: false,
            sellerConfirmed: false,
            disputeRaisedAt: 0,
            disputeReason: ""
        });

        buyerEscrows[msg.sender].push(escrowId);
        sellerEscrows[_seller].push(escrowId);
        arbiterEscrows[_arbiter].push(escrowId);

        emit EscrowCreated(escrowId, msg.sender, _seller, _arbiter, msg.value, _description);
        emit PaymentDeposited(escrowId, msg.sender, msg.value);
    }

    /**
     * @dev Seller confirms delivery
     * @param _escrowId Escrow ID
     */
    function confirmDelivery(uint256 _escrowId)
        external
        escrowExists(_escrowId)
        onlySeller(_escrowId)
        inState(_escrowId, EscrowState.AWAITING_DELIVERY)
    {
        escrows[_escrowId].sellerConfirmed = true;
        emit DeliveryConfirmed(_escrowId, msg.sender);
    }

    /**
     * @dev Buyer approves payment release
     * @param _escrowId Escrow ID
     */
    function approvePayment(uint256 _escrowId)
        external
        escrowExists(_escrowId)
        onlyBuyer(_escrowId)
        inState(_escrowId, EscrowState.AWAITING_DELIVERY)
    {
        escrows[_escrowId].buyerApproved = true;
        emit PaymentApproved(_escrowId, msg.sender);
        
        // Auto-release if both parties agree
        if (escrows[_escrowId].sellerConfirmed) {
            _releasePayment(_escrowId);
        }
    }

    /**
     * @dev Release payment to seller (internal)
     * @param _escrowId Escrow ID
     */
    function _releasePayment(uint256 _escrowId) internal {
        Escrow storage escrow = escrows[_escrowId];
        escrow.state = EscrowState.COMPLETE;
        
        uint256 amount = escrow.amount;
        uint256 platformFee = (amount * platformFeePercent) / 10000;
        uint256 sellerAmount = amount - platformFee;
        
        platformFees[platformOwner] += platformFee;
        
        payable(escrow.seller).transfer(sellerAmount);
        emit PaymentReleased(_escrowId, escrow.seller, sellerAmount);
    }

    /**
     * @dev Raise a dispute
     * @param _escrowId Escrow ID
     * @param _reason Reason for dispute
     */
    function raiseDispute(uint256 _escrowId, string memory _reason)
        external
        escrowExists(_escrowId)
        inState(_escrowId, EscrowState.AWAITING_DELIVERY)
    {
        require(
            msg.sender == escrows[_escrowId].buyer || msg.sender == escrows[_escrowId].seller,
            "Only buyer or seller can raise dispute"
        );
        require(bytes(_reason).length > 0, "Dispute reason required");

        escrows[_escrowId].state = EscrowState.DISPUTED;
        escrows[_escrowId].disputeRaisedAt = block.timestamp;
        escrows[_escrowId].disputeReason = _reason;

        emit DisputeRaised(_escrowId, msg.sender, _reason);
    }

    /**
     * @dev Resolve dispute (arbiter only)
     * @param _escrowId Escrow ID
     * @param _buyerWins Whether buyer wins the dispute
     */
    function resolveDispute(uint256 _escrowId, bool _buyerWins)
        external
        escrowExists(_escrowId)
        onlyArbiter(_escrowId)
        inState(_escrowId, EscrowState.DISPUTED)
    {
        Escrow storage escrow = escrows[_escrowId];
        uint256 amount = escrow.amount;
        
        uint256 arbiterFee = (amount * arbiterFeePercent) / 10000;
        uint256 platformFee = (amount * platformFeePercent) / 10000;
        uint256 remainingAmount = amount - arbiterFee - platformFee;
        
        arbiterFees[escrow.arbiter] += arbiterFee;
        platformFees[platformOwner] += platformFee;

        if (_buyerWins) {
            escrow.state = EscrowState.REFUNDED;
            payable(escrow.buyer).transfer(remainingAmount);
            emit EscrowRefunded(_escrowId, escrow.buyer, remainingAmount);
        } else {
            escrow.state = EscrowState.COMPLETE;
            payable(escrow.seller).transfer(remainingAmount);
            emit PaymentReleased(_escrowId, escrow.seller, remainingAmount);
        }

        emit DisputeResolved(_escrowId, msg.sender, _buyerWins);
    }

    /**
     * @dev Emergency refund (buyer only, after deadline + grace period)
     * @param _escrowId Escrow ID
     */
    function emergencyRefund(uint256 _escrowId)
        external
        escrowExists(_escrowId)
        onlyBuyer(_escrowId)
        inState(_escrowId, EscrowState.AWAITING_DELIVERY)
    {
        Escrow storage escrow = escrows[_escrowId];
        require(
            block.timestamp > escrow.deliveryDeadline + 7 days,
            "Emergency refund not available yet"
        );
        require(!escrow.sellerConfirmed, "Seller already confirmed delivery");

        escrow.state = EscrowState.REFUNDED;
        uint256 amount = escrow.amount;
        
        payable(escrow.buyer).transfer(amount);
        emit EscrowRefunded(_escrowId, escrow.buyer, amount);
    }

    /**
     * @dev Add approved arbiter
     * @param _arbiter Arbiter address
     */
    function addArbiter(address _arbiter) external onlyPlatformOwner {
        require(_arbiter != address(0), "Invalid arbiter address");
        require(!approvedArbiters[_arbiter], "Already approved arbiter");
        
        approvedArbiters[_arbiter] = true;
        emit ArbiterAdded(_arbiter);
    }

    /**
     * @dev Remove approved arbiter
     * @param _arbiter Arbiter address
     */
    function removeArbiter(address _arbiter) external onlyPlatformOwner {
        require(_arbiter != platformOwner, "Cannot remove platform owner");
        require(approvedArbiters[_arbiter], "Not an approved arbiter");
        
        approvedArbiters[_arbiter] = false;
        emit ArbiterRemoved(_arbiter);
    }

    /**
     * @dev Withdraw collected fees
     */
    function withdrawFees() external {
        uint256 amount = arbiterFees[msg.sender] + platformFees[msg.sender];
        require(amount > 0, "No fees to withdraw");
        
        arbiterFees[msg.sender] = 0;
        platformFees[msg.sender] = 0;
        
        payable(msg.sender).transfer(amount);
        emit FeesWithdrawn(msg.sender, amount);
    }

    /**
     * @dev Get escrow details
     * @param _escrowId Escrow ID
     * @return id Escrow ID
     * @return buyer Buyer address
     * @return seller Seller address
     * @return arbiter Arbiter address
     * @return amount Escrow amount
     * @return state Current state
     * @return createdAt Creation timestamp
     * @return deliveryDeadline Delivery deadline
     */
    function getEscrow(uint256 _escrowId)
        external
        view
        escrowExists(_escrowId)
        returns (
            uint256 id,
            address buyer,
            address seller,
            address arbiter,
            uint256 amount,
            EscrowState state,
            uint256 createdAt,
            uint256 deliveryDeadline
        )
    {
        Escrow storage escrow = escrows[_escrowId];
        return (
            escrow.id,
            escrow.buyer,
            escrow.seller,
            escrow.arbiter,
            escrow.amount,
            escrow.state,
            escrow.createdAt,
            escrow.deliveryDeadline
        );
    }

    /**
     * @dev Get escrow status details
     * @param _escrowId Escrow ID
     * @return description Transaction description
     * @return buyerApproved Whether buyer approved
     * @return sellerConfirmed Whether seller confirmed
     * @return disputeReason Dispute reason (if any)
     * @return disputeRaisedAt Dispute timestamp
     */
    function getEscrowStatus(uint256 _escrowId)
        external
        view
        escrowExists(_escrowId)
        returns (
            string memory description,
            bool buyerApproved,
            bool sellerConfirmed,
            string memory disputeReason,
            uint256 disputeRaisedAt
        )
    {
        Escrow storage escrow = escrows[_escrowId];
        return (
            escrow.description,
            escrow.buyerApproved,
            escrow.sellerConfirmed,
            escrow.disputeReason,
            escrow.disputeRaisedAt
        );
    }

    /**
     * @dev Get user's escrows
     * @param _user User address
     * @return buyerEscrowIds Escrows where user is buyer
     * @return sellerEscrowIds Escrows where user is seller
     * @return arbiterEscrowIds Escrows where user is arbiter
     */
    function getUserEscrows(address _user)
        external
        view
        returns (
            uint256[] memory buyerEscrowIds,
            uint256[] memory sellerEscrowIds,
            uint256[] memory arbiterEscrowIds
        )
    {
        return (
            buyerEscrows[_user],
            sellerEscrows[_user],
            arbiterEscrows[_user]
        );
    }

    /**
     * @dev Get platform information
     * @return owner Platform owner
     * @return totalEscrows Total number of escrows
     * @return arbiterFee Arbiter fee percentage
     * @return platformFee Platform fee percentage
     */
    function getPlatformInfo()
        external
        view
        returns (
            address owner,
            uint256 totalEscrows,
            uint256 arbiterFee,
            uint256 platformFee
        )
    {
        return (platformOwner, escrowCount, arbiterFeePercent, platformFeePercent);
    }

    /**
     * @dev Get available fees for withdrawal
     * @param _user User address
     * @return arbiterFeeAmount Available arbiter fees
     * @return platformFeeAmount Available platform fees
     */
    function getAvailableFees(address _user)
        external
        view
        returns (uint256 arbiterFeeAmount, uint256 platformFeeAmount)
    {
        return (arbiterFees[_user], platformFees[_user]);
    }
}
