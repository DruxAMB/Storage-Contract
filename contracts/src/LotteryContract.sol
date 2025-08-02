// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title LotteryContract
 * @dev Fair lottery system with random winner selection and automatic prize distribution
 * @notice Buy tickets, participate in draws, and win ETH prizes in a transparent lottery system
 */
contract LotteryContract {
    // Structs
    struct Lottery {
        uint256 id;
        string name;
        uint256 ticketPrice;
        uint256 maxTickets;
        uint256 ticketsSold;
        uint256 prizePool;
        uint256 startTime;
        uint256 endTime;
        address winner;
        bool drawn;
        bool prizeDistributed;
        address[] participants;
        mapping(address => uint256) ticketCount;
    }

    struct Ticket {
        uint256 lotteryId;
        address owner;
        uint256 ticketNumber;
        uint256 purchaseTime;
    }

    // State variables
    mapping(uint256 => Lottery) public lotteries;
    mapping(uint256 => Ticket) public tickets;
    mapping(address => uint256[]) public userLotteries;
    mapping(address => uint256) public totalWinnings;
    
    uint256 public lotteryCount;
    uint256 public ticketCount;
    address public owner;
    uint256 public platformFeePercent; // in basis points
    uint256 public totalFeesCollected;
    
    // Randomness (simple implementation - in production use Chainlink VRF)
    uint256 private nonce;

    // Events
    event LotteryCreated(
        uint256 indexed lotteryId,
        string name,
        uint256 ticketPrice,
        uint256 maxTickets,
        uint256 startTime,
        uint256 endTime
    );
    event TicketPurchased(
        uint256 indexed lotteryId,
        address indexed buyer,
        uint256 indexed ticketId,
        uint256 ticketNumber
    );
    event LotteryDrawn(
        uint256 indexed lotteryId,
        address indexed winner,
        uint256 prizeAmount,
        uint256 winningTicket
    );
    event PrizeDistributed(
        uint256 indexed lotteryId,
        address indexed winner,
        uint256 amount
    );
    event LotteryCancelled(uint256 indexed lotteryId, string reason);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }
    
    modifier lotteryExists(uint256 lotteryId) {
        require(lotteryId < lotteryCount, "Lottery does not exist");
        _;
    }
    
    modifier lotteryActive(uint256 lotteryId) {
        Lottery storage lottery = lotteries[lotteryId];
        require(block.timestamp >= lottery.startTime, "Lottery not started");
        require(block.timestamp <= lottery.endTime, "Lottery ended");
        require(!lottery.drawn, "Lottery already drawn");
        require(lottery.ticketsSold < lottery.maxTickets, "Lottery sold out");
        _;
    }

    /**
     * @dev Constructor sets platform fee and owner
     * @param _platformFeePercent Platform fee in basis points (e.g., 500 = 5%)
     */
    constructor(uint256 _platformFeePercent) {
        require(_platformFeePercent <= 1000, "Platform fee too high"); // Max 10%
        owner = msg.sender;
        platformFeePercent = _platformFeePercent;
        nonce = block.timestamp;
    }

    /**
     * @dev Create a new lottery
     * @param name Lottery name
     * @param ticketPrice Price per ticket in wei
     * @param maxTickets Maximum number of tickets
     * @param durationHours Duration in hours
     * @return lotteryId The created lottery ID
     */
    function createLottery(
        string memory name,
        uint256 ticketPrice,
        uint256 maxTickets,
        uint256 durationHours
    ) external onlyOwner returns (uint256 lotteryId) {
        require(bytes(name).length > 0, "Name cannot be empty");
        require(ticketPrice > 0, "Ticket price must be positive");
        require(maxTickets > 1, "Must allow at least 2 tickets");
        require(durationHours > 0 && durationHours <= 8760, "Invalid duration"); // Max 1 year

        lotteryId = lotteryCount++;
        
        Lottery storage newLottery = lotteries[lotteryId];
        newLottery.id = lotteryId;
        newLottery.name = name;
        newLottery.ticketPrice = ticketPrice;
        newLottery.maxTickets = maxTickets;
        newLottery.startTime = block.timestamp;
        newLottery.endTime = block.timestamp + (durationHours * 1 hours);
        newLottery.ticketsSold = 0;
        newLottery.prizePool = 0;
        newLottery.drawn = false;
        newLottery.prizeDistributed = false;

        emit LotteryCreated(
            lotteryId,
            name,
            ticketPrice,
            maxTickets,
            newLottery.startTime,
            newLottery.endTime
        );
    }

    /**
     * @dev Buy tickets for a lottery
     * @param lotteryId Lottery ID
     * @param numTickets Number of tickets to buy
     */
    function buyTickets(uint256 lotteryId, uint256 numTickets) 
        external 
        payable 
        lotteryExists(lotteryId) 
        lotteryActive(lotteryId) 
    {
        require(numTickets > 0, "Must buy at least 1 ticket");
        
        Lottery storage lottery = lotteries[lotteryId];
        require(lottery.ticketsSold + numTickets <= lottery.maxTickets, "Not enough tickets available");
        
        uint256 totalCost = lottery.ticketPrice * numTickets;
        require(msg.value == totalCost, "Incorrect payment amount");

        // Add to participants list if first time
        if (lottery.ticketCount[msg.sender] == 0) {
            lottery.participants.push(msg.sender);
            userLotteries[msg.sender].push(lotteryId);
        }

        // Create tickets
        for (uint256 i = 0; i < numTickets; i++) {
            uint256 ticketId = ticketCount++;
            uint256 ticketNumber = lottery.ticketsSold + i + 1;
            
            tickets[ticketId] = Ticket({
                lotteryId: lotteryId,
                owner: msg.sender,
                ticketNumber: ticketNumber,
                purchaseTime: block.timestamp
            });

            emit TicketPurchased(lotteryId, msg.sender, ticketId, ticketNumber);
        }

        lottery.ticketCount[msg.sender] += numTickets;
        lottery.ticketsSold += numTickets;
        lottery.prizePool += msg.value;
    }

    /**
     * @dev Draw lottery winner (can be called by anyone after end time)
     * @param lotteryId Lottery ID
     */
    function drawLottery(uint256 lotteryId) 
        external 
        lotteryExists(lotteryId) 
    {
        Lottery storage lottery = lotteries[lotteryId];
        require(block.timestamp > lottery.endTime, "Lottery still active");
        require(!lottery.drawn, "Lottery already drawn");
        require(lottery.ticketsSold > 0, "No tickets sold");

        // Generate random winning ticket number
        uint256 winningTicketNumber = _generateRandomNumber(lottery.ticketsSold) + 1;
        
        // Find winner by iterating through tickets
        address winner = _findTicketOwner(lotteryId, winningTicketNumber);
        require(winner != address(0), "Winner not found");

        lottery.winner = winner;
        lottery.drawn = true;

        emit LotteryDrawn(lotteryId, winner, lottery.prizePool, winningTicketNumber);
    }

    /**
     * @dev Distribute prize to winner
     * @param lotteryId Lottery ID
     */
    function distributePrize(uint256 lotteryId) 
        external 
        lotteryExists(lotteryId) 
    {
        Lottery storage lottery = lotteries[lotteryId];
        require(lottery.drawn, "Lottery not drawn yet");
        require(!lottery.prizeDistributed, "Prize already distributed");
        require(lottery.winner != address(0), "No winner found");

        uint256 prizePool = lottery.prizePool;
        uint256 platformFee = (prizePool * platformFeePercent) / 10000;
        uint256 winnerPrize = prizePool - platformFee;

        lottery.prizeDistributed = true;
        totalWinnings[lottery.winner] += winnerPrize;
        totalFeesCollected += platformFee;

        // Transfer prize to winner
        payable(lottery.winner).transfer(winnerPrize);

        emit PrizeDistributed(lotteryId, lottery.winner, winnerPrize);
    }

    /**
     * @dev Cancel lottery and refund participants (owner only, before draw)
     * @param lotteryId Lottery ID
     * @param reason Cancellation reason
     */
    function cancelLottery(uint256 lotteryId, string memory reason) 
        external 
        onlyOwner 
        lotteryExists(lotteryId) 
    {
        Lottery storage lottery = lotteries[lotteryId];
        require(!lottery.drawn, "Cannot cancel drawn lottery");
        require(bytes(reason).length > 0, "Reason required");

        // Refund all participants
        for (uint256 i = 0; i < lottery.participants.length; i++) {
            address participant = lottery.participants[i];
            uint256 refundAmount = lottery.ticketCount[participant] * lottery.ticketPrice;
            
            if (refundAmount > 0) {
                payable(participant).transfer(refundAmount);
            }
        }

        lottery.drawn = true; // Prevent further operations
        lottery.prizeDistributed = true;

        emit LotteryCancelled(lotteryId, reason);
    }

    /**
     * @dev Internal function to generate pseudo-random number
     * @param max Maximum value (exclusive)
     * @return Random number between 0 and max-1
     */
    function _generateRandomNumber(uint256 max) internal returns (uint256) {
        nonce++;
        return uint256(keccak256(abi.encodePacked(
            block.timestamp,
            block.prevrandao,
            msg.sender,
            nonce
        ))) % max;
    }

    /**
     * @dev Internal function to find ticket owner by ticket number
     * @param lotteryId Lottery ID
     * @param ticketNumber Ticket number to find
     * @return ticketOwner Address of ticket owner
     */
    function _findTicketOwner(uint256 lotteryId, uint256 ticketNumber) 
        internal 
        view 
        returns (address ticketOwner) 
    {
        for (uint256 i = 0; i < ticketCount; i++) {
            if (tickets[i].lotteryId == lotteryId && 
                tickets[i].ticketNumber == ticketNumber) {
                return tickets[i].owner;
            }
        }
        return address(0);
    }

    /**
     * @dev Owner withdraw collected fees
     */
    function withdrawFees() external onlyOwner {
        require(totalFeesCollected > 0, "No fees to withdraw");
        uint256 amount = totalFeesCollected;
        totalFeesCollected = 0;
        payable(owner).transfer(amount);
    }

    /**
     * @dev Transfer ownership
     * @param newOwner New owner address
     */
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "New owner cannot be zero address");
        address previousOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(previousOwner, newOwner);
    }

    /**
     * @dev Get lottery details
     * @param lotteryId Lottery ID
     * @return id Lottery ID
     * @return name Lottery name
     * @return ticketPrice Price per ticket
     * @return maxTickets Maximum tickets
     * @return ticketsSold Tickets sold
     * @return prizePool Current prize pool
     * @return startTime Start timestamp
     * @return endTime End timestamp
     */
    function getLottery(uint256 lotteryId) 
        external 
        view 
        lotteryExists(lotteryId) 
        returns (
            uint256 id,
            string memory name,
            uint256 ticketPrice,
            uint256 maxTickets,
            uint256 ticketsSold,
            uint256 prizePool,
            uint256 startTime,
            uint256 endTime
        ) 
    {
        Lottery storage lottery = lotteries[lotteryId];
        return (
            lottery.id,
            lottery.name,
            lottery.ticketPrice,
            lottery.maxTickets,
            lottery.ticketsSold,
            lottery.prizePool,
            lottery.startTime,
            lottery.endTime
        );
    }

    /**
     * @dev Get lottery status
     * @param lotteryId Lottery ID
     * @return winner Winner address (if drawn)
     * @return drawn Whether lottery is drawn
     * @return prizeDistributed Whether prize is distributed
     * @return participantCount Number of participants
     */
    function getLotteryStatus(uint256 lotteryId) 
        external 
        view 
        lotteryExists(lotteryId) 
        returns (
            address winner,
            bool drawn,
            bool prizeDistributed,
            uint256 participantCount
        ) 
    {
        Lottery storage lottery = lotteries[lotteryId];
        return (
            lottery.winner,
            lottery.drawn,
            lottery.prizeDistributed,
            lottery.participants.length
        );
    }

    /**
     * @dev Get user's ticket count for a lottery
     * @param lotteryId Lottery ID
     * @param user User address
     * @return userTicketCount Number of tickets owned
     */
    function getUserTicketCount(uint256 lotteryId, address user) 
        external 
        view 
        lotteryExists(lotteryId) 
        returns (uint256 userTicketCount) 
    {
        return lotteries[lotteryId].ticketCount[user];
    }

    /**
     * @dev Get user's participated lotteries
     * @param user User address
     * @return lotteryIds Array of lottery IDs user participated in
     */
    function getUserLotteries(address user) 
        external 
        view 
        returns (uint256[] memory lotteryIds) 
    {
        return userLotteries[user];
    }

    /**
     * @dev Get active lotteries (not drawn and not ended)
     * @return activeLotteries Array of active lottery IDs
     */
    function getActiveLotteries() 
        external 
        view 
        returns (uint256[] memory activeLotteries) 
    {
        uint256 activeCount = 0;
        
        // Count active lotteries
        for (uint256 i = 0; i < lotteryCount; i++) {
            if (!lotteries[i].drawn && block.timestamp <= lotteries[i].endTime) {
                activeCount++;
            }
        }
        
        // Create array of active lottery IDs
        activeLotteries = new uint256[](activeCount);
        uint256 index = 0;
        
        for (uint256 i = 0; i < lotteryCount; i++) {
            if (!lotteries[i].drawn && block.timestamp <= lotteries[i].endTime) {
                activeLotteries[index] = i;
                index++;
            }
        }
    }

    /**
     * @dev Get contract statistics
     * @return totalLotteries Total number of lotteries created
     * @return totalTicketsSold Total tickets sold across all lotteries
     * @return totalPrizesDistributed Total prize money distributed
     * @return platformFeesCollected Total platform fees collected
     * @return contractBalance Current contract balance
     */
    function getContractStats() 
        external 
        view 
        returns (
            uint256 totalLotteries,
            uint256 totalTicketsSold,
            uint256 totalPrizesDistributed,
            uint256 platformFeesCollected,
            uint256 contractBalance
        ) 
    {
        uint256 totalPrizes = 0;
        
        for (uint256 i = 0; i < lotteryCount; i++) {
            if (lotteries[i].prizeDistributed) {
                totalPrizes += lotteries[i].prizePool;
            }
        }
        
        return (
            lotteryCount,
            ticketCount,
            totalPrizes,
            totalFeesCollected,
            address(this).balance
        );
    }

    /**
     * @dev Check if lottery can be drawn
     * @param lotteryId Lottery ID
     * @return canDraw Whether lottery can be drawn
     * @return reason Reason if cannot draw
     */
    function canDrawLottery(uint256 lotteryId) 
        external 
        view 
        lotteryExists(lotteryId) 
        returns (bool canDraw, string memory reason) 
    {
        Lottery storage lottery = lotteries[lotteryId];
        
        if (lottery.drawn) {
            return (false, "Already drawn");
        }
        
        if (block.timestamp <= lottery.endTime) {
            return (false, "Lottery still active");
        }
        
        if (lottery.ticketsSold == 0) {
            return (false, "No tickets sold");
        }
        
        return (true, "Ready to draw");
    }
}
