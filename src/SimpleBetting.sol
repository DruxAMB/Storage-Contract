// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v4.8.0/contracts/security/ReentrancyGuard.sol";
import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v4.8.0/contracts/access/Ownable.sol";

/**
 * @title SimpleBetting
 * @dev Basic betting pool system for events with two outcomes
 * @notice Allows users to create betting pools and place bets on binary outcomes
 */
contract SimpleBetting is ReentrancyGuard, Ownable {
    // Betting pool states
    enum PoolState { OPEN, CLOSED, RESOLVED, CANCELLED }
    
    // Betting outcomes
    enum Outcome { NONE, OPTION_A, OPTION_B }
    
    // Betting pool struct
    struct BettingPool {
        string title;
        string description;
        string optionA;
        string optionB;
        address creator;
        uint256 createdAt;
        uint256 bettingDeadline;
        uint256 resolutionDeadline;
        PoolState state;
        Outcome result;
        uint256 totalBetsA;
        uint256 totalBetsB;
        uint256 totalPool;
        bool resolved;
        mapping(address => uint256) betsA;
        mapping(address => uint256) betsB;
        mapping(address => bool) hasClaimed;
        address[] bettors;
    }
    
    // State variables
    uint256 public poolCount;
    uint256 public platformFee = 250; // 2.5% in basis points
    uint256 public minBet = 0.001 ether;
    uint256 public maxBet = 10 ether;
    
    // Mappings
    mapping(uint256 => BettingPool) public pools;
    mapping(address => uint256[]) public userPools;
    mapping(address => uint256) public userPoolCount;
    
    // Events
    event PoolCreated(
        uint256 indexed poolId,
        address indexed creator,
        string title,
        string optionA,
        string optionB,
        uint256 bettingDeadline,
        uint256 resolutionDeadline
    );
    
    event BetPlaced(
        uint256 indexed poolId,
        address indexed bettor,
        Outcome outcome,
        uint256 amount,
        uint256 totalPoolA,
        uint256 totalPoolB
    );
    
    event PoolResolved(
        uint256 indexed poolId,
        Outcome result,
        uint256 totalWinnings,
        uint256 totalLosings
    );
    
    event WinningsClaimed(
        uint256 indexed poolId,
        address indexed winner,
        uint256 amount
    );
    
    event PoolCancelled(uint256 indexed poolId, string reason);
    event FeesUpdated(uint256 newPlatformFee);
    event BetLimitsUpdated(uint256 newMinBet, uint256 newMaxBet);
    
    /**
     * @dev Constructor
     */
    constructor() Ownable() {}
    
    /**
     * @dev Create a new betting pool
     * @param title Title of the betting pool
     * @param description Description of the event
     * @param optionA First betting option
     * @param optionB Second betting option
     * @param bettingDuration Duration for betting in seconds
     * @param resolutionDuration Duration for resolution after betting ends
     * @return poolId ID of the created pool
     */
    function createPool(
        string memory title,
        string memory description,
        string memory optionA,
        string memory optionB,
        uint256 bettingDuration,
        uint256 resolutionDuration
    ) external returns (uint256 poolId) {
        require(bytes(title).length > 0, "Title cannot be empty");
        require(bytes(optionA).length > 0, "Option A cannot be empty");
        require(bytes(optionB).length > 0, "Option B cannot be empty");
        require(bettingDuration > 0, "Betting duration must be positive");
        require(resolutionDuration > 0, "Resolution duration must be positive");
        require(bettingDuration <= 30 days, "Betting duration too long");
        require(resolutionDuration <= 7 days, "Resolution duration too long");
        
        poolId = poolCount++;
        
        BettingPool storage pool = pools[poolId];
        pool.title = title;
        pool.description = description;
        pool.optionA = optionA;
        pool.optionB = optionB;
        pool.creator = msg.sender;
        pool.createdAt = block.timestamp;
        pool.bettingDeadline = block.timestamp + bettingDuration;
        pool.resolutionDeadline = pool.bettingDeadline + resolutionDuration;
        pool.state = PoolState.OPEN;
        pool.result = Outcome.NONE;
        
        // Track user pools
        userPools[msg.sender].push(poolId);
        userPoolCount[msg.sender]++;
        
        emit PoolCreated(
            poolId,
            msg.sender,
            title,
            optionA,
            optionB,
            pool.bettingDeadline,
            pool.resolutionDeadline
        );
        
        return poolId;
    }
    
    /**
     * @dev Place a bet on a specific outcome
     * @param poolId ID of the betting pool
     * @param outcome The outcome to bet on (1 = Option A, 2 = Option B)
     */
    function placeBet(uint256 poolId, Outcome outcome) external payable nonReentrant {
        require(poolId < poolCount, "Pool does not exist");
        require(outcome == Outcome.OPTION_A || outcome == Outcome.OPTION_B, "Invalid outcome");
        require(msg.value >= minBet, "Bet amount too small");
        require(msg.value <= maxBet, "Bet amount too large");
        
        BettingPool storage pool = pools[poolId];
        require(pool.state == PoolState.OPEN, "Pool not open for betting");
        require(block.timestamp <= pool.bettingDeadline, "Betting period ended");
        
        // Track if this is a new bettor
        bool isNewBettor = (pool.betsA[msg.sender] == 0 && pool.betsB[msg.sender] == 0);
        
        if (outcome == Outcome.OPTION_A) {
            pool.betsA[msg.sender] += msg.value;
            pool.totalBetsA += msg.value;
        } else {
            pool.betsB[msg.sender] += msg.value;
            pool.totalBetsB += msg.value;
        }
        
        pool.totalPool += msg.value;
        
        // Add to bettors list if new
        if (isNewBettor) {
            pool.bettors.push(msg.sender);
        }
        
        emit BetPlaced(poolId, msg.sender, outcome, msg.value, pool.totalBetsA, pool.totalBetsB);
    }
    
    /**
     * @dev Resolve a betting pool with the final outcome
     * @param poolId ID of the betting pool
     * @param result The final outcome of the event
     */
    function resolvePool(uint256 poolId, Outcome result) external nonReentrant {
        require(poolId < poolCount, "Pool does not exist");
        require(result == Outcome.OPTION_A || result == Outcome.OPTION_B, "Invalid result");
        
        BettingPool storage pool = pools[poolId];
        require(msg.sender == pool.creator || msg.sender == owner(), "Not authorized");
        require(pool.state == PoolState.OPEN, "Pool not in open state");
        require(block.timestamp > pool.bettingDeadline, "Betting period not ended");
        require(block.timestamp <= pool.resolutionDeadline, "Resolution period expired");
        require(!pool.resolved, "Pool already resolved");
        
        pool.result = result;
        pool.resolved = true;
        pool.state = PoolState.RESOLVED;
        
        uint256 winningPool = (result == Outcome.OPTION_A) ? pool.totalBetsA : pool.totalBetsB;
        uint256 losingPool = (result == Outcome.OPTION_A) ? pool.totalBetsB : pool.totalBetsA;
        
        emit PoolResolved(poolId, result, winningPool, losingPool);
    }
    
    /**
     * @dev Claim winnings from a resolved betting pool
     * @param poolId ID of the betting pool
     */
    function claimWinnings(uint256 poolId) external nonReentrant {
        require(poolId < poolCount, "Pool does not exist");
        
        BettingPool storage pool = pools[poolId];
        require(pool.resolved, "Pool not resolved");
        require(!pool.hasClaimed[msg.sender], "Already claimed");
        
        uint256 userBet;
        uint256 winningPool;
        
        if (pool.result == Outcome.OPTION_A) {
            userBet = pool.betsA[msg.sender];
            winningPool = pool.totalBetsA;
        } else {
            userBet = pool.betsB[msg.sender];
            winningPool = pool.totalBetsB;
        }
        
        require(userBet > 0, "No winning bet found");
        
        // Calculate winnings
        uint256 totalPayout = pool.totalPool;
        uint256 platformFeeAmount = (totalPayout * platformFee) / 10000;
        uint256 netPayout = totalPayout - platformFeeAmount;
        
        uint256 userWinnings = (userBet * netPayout) / winningPool;
        
        pool.hasClaimed[msg.sender] = true;
        
        payable(msg.sender).transfer(userWinnings);
        
        emit WinningsClaimed(poolId, msg.sender, userWinnings);
    }
    
    /**
     * @dev Cancel a betting pool and refund all bets
     * @param poolId ID of the betting pool
     * @param reason Reason for cancellation
     */
    function cancelPool(uint256 poolId, string memory reason) external nonReentrant {
        require(poolId < poolCount, "Pool does not exist");
        
        BettingPool storage pool = pools[poolId];
        require(msg.sender == pool.creator || msg.sender == owner(), "Not authorized");
        require(pool.state == PoolState.OPEN, "Pool not in open state");
        require(!pool.resolved, "Pool already resolved");
        
        pool.state = PoolState.CANCELLED;
        
        // Refund all bettors
        for (uint256 i = 0; i < pool.bettors.length; i++) {
            address bettor = pool.bettors[i];
            uint256 refundAmount = pool.betsA[bettor] + pool.betsB[bettor];
            
            if (refundAmount > 0) {
                payable(bettor).transfer(refundAmount);
            }
        }
        
        emit PoolCancelled(poolId, reason);
    }
    
    /**
     * @dev Get current odds for a betting pool
     * @param poolId ID of the betting pool
     * @return oddsA Odds for option A (multiplied by 100 for precision)
     * @return oddsB Odds for option B (multiplied by 100 for precision)
     */
    function getOdds(uint256 poolId) external view returns (uint256 oddsA, uint256 oddsB) {
        require(poolId < poolCount, "Pool does not exist");
        
        BettingPool storage pool = pools[poolId];
        
        if (pool.totalPool == 0) {
            return (100, 100); // 1:1 odds if no bets
        }
        
        // Calculate odds based on pool distribution
        // Odds = (Total Pool / Outcome Pool) * 100
        oddsA = pool.totalBetsA > 0 ? (pool.totalPool * 100) / pool.totalBetsA : 0;
        oddsB = pool.totalBetsB > 0 ? (pool.totalPool * 100) / pool.totalBetsB : 0;
        
        return (oddsA, oddsB);
    }
    
    /**
     * @dev Get betting pool information
     * @param poolId ID of the betting pool
     * @return Basic pool information
     */
    function getPoolInfo(uint256 poolId) external view returns (
        string memory title,
        string memory description,
        string memory optionA,
        string memory optionB,
        address creator,
        uint256 bettingDeadline,
        PoolState state
    ) {
        require(poolId < poolCount, "Pool does not exist");
        
        BettingPool storage pool = pools[poolId];
        return (
            pool.title,
            pool.description,
            pool.optionA,
            pool.optionB,
            pool.creator,
            pool.bettingDeadline,
            pool.state
        );
    }
    
    /**
     * @dev Get betting pool statistics
     * @param poolId ID of the betting pool
     * @return Pool betting statistics
     */
    function getPoolStats(uint256 poolId) external view returns (
        uint256 totalBetsA,
        uint256 totalBetsB,
        uint256 totalPool,
        Outcome result,
        bool resolved,
        uint256 bettorCount
    ) {
        require(poolId < poolCount, "Pool does not exist");
        
        BettingPool storage pool = pools[poolId];
        return (
            pool.totalBetsA,
            pool.totalBetsB,
            pool.totalPool,
            pool.result,
            pool.resolved,
            pool.bettors.length
        );
    }
    
    /**
     * @dev Get user's bets for a specific pool
     * @param poolId ID of the betting pool
     * @param user Address of the user
     * @return betA Amount bet on option A
     * @return betB Amount bet on option B
     * @return hasClaimed Whether user has claimed winnings
     */
    function getUserBets(uint256 poolId, address user) external view returns (
        uint256 betA,
        uint256 betB,
        bool hasClaimed
    ) {
        require(poolId < poolCount, "Pool does not exist");
        
        BettingPool storage pool = pools[poolId];
        return (
            pool.betsA[user],
            pool.betsB[user],
            pool.hasClaimed[user]
        );
    }
    
    /**
     * @dev Get pools created by a user
     * @param user Address of the user
     * @return Array of pool IDs created by the user
     */
    function getUserPools(address user) external view returns (uint256[] memory) {
        return userPools[user];
    }
    
    /**
     * @dev Update platform fee (owner only)
     * @param newPlatformFee New platform fee in basis points
     */
    function updatePlatformFee(uint256 newPlatformFee) external onlyOwner {
        require(newPlatformFee <= 1000, "Fee too high"); // Max 10%
        platformFee = newPlatformFee;
        emit FeesUpdated(newPlatformFee);
    }
    
    /**
     * @dev Update betting limits (owner only)
     * @param newMinBet New minimum bet amount
     * @param newMaxBet New maximum bet amount
     */
    function updateBetLimits(uint256 newMinBet, uint256 newMaxBet) external onlyOwner {
        require(newMinBet < newMaxBet, "Min must be less than max");
        minBet = newMinBet;
        maxBet = newMaxBet;
        emit BetLimitsUpdated(newMinBet, newMaxBet);
    }
    
    /**
     * @dev Withdraw platform fees (owner only)
     */
    function withdrawFees() external onlyOwner nonReentrant {
        uint256 balance = address(this).balance;
        require(balance > 0, "No fees to withdraw");
        
        payable(owner()).transfer(balance);
    }
    
    /**
     * @dev Get contract balance
     * @return Current contract balance
     */
    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
