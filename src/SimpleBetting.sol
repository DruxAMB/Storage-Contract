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
    enum PoolState { OPEN, RESOLVED, CANCELLED }
    
    // Betting outcomes
    enum Outcome { NONE, OPTION_A, OPTION_B }
    
    // Simplified betting pool struct
    struct BettingPool {
        string title;
        string optionA;
        string optionB;
        address creator;
        uint256 bettingDeadline;
        PoolState state;
        Outcome result;
        uint256 totalBetsA;
        uint256 totalBetsB;
        bool resolved;
        mapping(address => uint256) betsA;
        mapping(address => uint256) betsB;
        mapping(address => bool) hasClaimed;
    }
    
    // State variables
    uint256 public poolCount;
    uint256 public platformFee = 250; // 2.5% in basis points
    uint256 public minBet = 0.001 ether;
    uint256 public maxBet = 10 ether;
    
    // Mappings
    mapping(uint256 => BettingPool) public pools;
    mapping(address => uint256[]) public userPools;
    
    // Events
    event PoolCreated(uint256 indexed poolId, address indexed creator, string title);
    event BetPlaced(uint256 indexed poolId, address indexed bettor, Outcome outcome, uint256 amount);
    event PoolResolved(uint256 indexed poolId, Outcome result);
    event WinningsClaimed(uint256 indexed poolId, address indexed winner, uint256 amount);
    event PoolCancelled(uint256 indexed poolId);
    
    /**
     * @dev Constructor
     */
    constructor() Ownable() {}
    
    /**
     * @dev Create a new betting pool
     * @param title Title of the betting pool
     * @param optionA First betting option
     * @param optionB Second betting option
     * @param bettingDuration Duration for betting in seconds
     * @return poolId ID of the created pool
     */
    function createPool(
        string memory title,
        string memory optionA,
        string memory optionB,
        uint256 bettingDuration
    ) external returns (uint256 poolId) {
        require(bytes(title).length > 0, "Title cannot be empty");
        require(bytes(optionA).length > 0, "Option A cannot be empty");
        require(bytes(optionB).length > 0, "Option B cannot be empty");
        require(bettingDuration > 0, "Duration must be positive");
        require(bettingDuration <= 30 days, "Duration too long");
        
        poolId = poolCount++;
        
        BettingPool storage pool = pools[poolId];
        pool.title = title;
        pool.optionA = optionA;
        pool.optionB = optionB;
        pool.creator = msg.sender;
        pool.bettingDeadline = block.timestamp + bettingDuration;
        pool.state = PoolState.OPEN;
        pool.result = Outcome.NONE;
        
        userPools[msg.sender].push(poolId);
        
        emit PoolCreated(poolId, msg.sender, title);
        
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
        require(msg.value >= minBet, "Bet too small");
        require(msg.value <= maxBet, "Bet too large");
        
        BettingPool storage pool = pools[poolId];
        require(pool.state == PoolState.OPEN, "Pool not open");
        require(block.timestamp <= pool.bettingDeadline, "Betting ended");
        
        if (outcome == Outcome.OPTION_A) {
            pool.betsA[msg.sender] += msg.value;
            pool.totalBetsA += msg.value;
        } else {
            pool.betsB[msg.sender] += msg.value;
            pool.totalBetsB += msg.value;
        }
        
        emit BetPlaced(poolId, msg.sender, outcome, msg.value);
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
        require(pool.state == PoolState.OPEN, "Pool not open");
        require(block.timestamp > pool.bettingDeadline, "Betting not ended");
        require(!pool.resolved, "Already resolved");
        
        pool.result = result;
        pool.resolved = true;
        pool.state = PoolState.RESOLVED;
        
        emit PoolResolved(poolId, result);
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
        
        require(userBet > 0, "No winning bet");
        
        uint256 totalPool = pool.totalBetsA + pool.totalBetsB;
        uint256 feeAmount = (totalPool * platformFee) / 10000;
        uint256 netPool = totalPool - feeAmount;
        
        uint256 userWinnings = (userBet * netPool) / winningPool;
        
        pool.hasClaimed[msg.sender] = true;
        
        payable(msg.sender).transfer(userWinnings);
        
        emit WinningsClaimed(poolId, msg.sender, userWinnings);
    }
    
    /**
     * @dev Cancel a betting pool and refund all bets
     * @param poolId ID of the betting pool
     */
    function cancelPool(uint256 poolId) external nonReentrant {
        require(poolId < poolCount, "Pool does not exist");
        
        BettingPool storage pool = pools[poolId];
        require(msg.sender == pool.creator || msg.sender == owner(), "Not authorized");
        require(pool.state == PoolState.OPEN, "Pool not open");
        require(!pool.resolved, "Already resolved");
        
        pool.state = PoolState.CANCELLED;
        
        emit PoolCancelled(poolId);
    }
    
    /**
     * @dev Get current odds for a betting pool
     * @param poolId ID of the betting pool
     * @return oddsA Odds for option A (multiplied by 100)
     * @return oddsB Odds for option B (multiplied by 100)
     */
    function getOdds(uint256 poolId) external view returns (uint256 oddsA, uint256 oddsB) {
        require(poolId < poolCount, "Pool does not exist");
        
        BettingPool storage pool = pools[poolId];
        uint256 totalPool = pool.totalBetsA + pool.totalBetsB;
        
        if (totalPool == 0) {
            return (100, 100);
        }
        
        oddsA = pool.totalBetsA > 0 ? (totalPool * 100) / pool.totalBetsA : 0;
        oddsB = pool.totalBetsB > 0 ? (totalPool * 100) / pool.totalBetsB : 0;
        
        return (oddsA, oddsB);
    }
    
    /**
     * @dev Get betting pool basic information
     * @param poolId ID of the betting pool
     * @return title Pool title
     * @return optionA First option
     * @return optionB Second option
     * @return creator Pool creator
     * @return deadline Betting deadline
     */
    function getPoolInfo(uint256 poolId) external view returns (
        string memory title,
        string memory optionA,
        string memory optionB,
        address creator,
        uint256 deadline
    ) {
        require(poolId < poolCount, "Pool does not exist");
        
        BettingPool storage pool = pools[poolId];
        return (pool.title, pool.optionA, pool.optionB, pool.creator, pool.bettingDeadline);
    }
    
    /**
     * @dev Get betting pool statistics
     * @param poolId ID of the betting pool
     * @return totalBetsA Total bets on option A
     * @return totalBetsB Total bets on option B
     * @return state Pool state
     * @return result Pool result
     * @return resolved Whether resolved
     */
    function getPoolStats(uint256 poolId) external view returns (
        uint256 totalBetsA,
        uint256 totalBetsB,
        PoolState state,
        Outcome result,
        bool resolved
    ) {
        require(poolId < poolCount, "Pool does not exist");
        
        BettingPool storage pool = pools[poolId];
        return (pool.totalBetsA, pool.totalBetsB, pool.state, pool.result, pool.resolved);
    }
    
    /**
     * @dev Get user's bets for a specific pool
     * @param poolId ID of the betting pool
     * @param user Address of the user
     * @return betA Amount bet on option A
     * @return betB Amount bet on option B
     * @return claimed Whether user has claimed
     */
    function getUserBets(uint256 poolId, address user) external view returns (
        uint256 betA,
        uint256 betB,
        bool claimed
    ) {
        require(poolId < poolCount, "Pool does not exist");
        
        BettingPool storage pool = pools[poolId];
        return (pool.betsA[user], pool.betsB[user], pool.hasClaimed[user]);
    }
    
    /**
     * @dev Get pools created by a user
     * @param user Address of the user
     * @return Array of pool IDs
     */
    function getUserPools(address user) external view returns (uint256[] memory) {
        return userPools[user];
    }
    
    /**
     * @dev Update platform fee (owner only)
     * @param newFee New platform fee in basis points
     */
    function updatePlatformFee(uint256 newFee) external onlyOwner {
        require(newFee <= 1000, "Fee too high");
        platformFee = newFee;
    }
    
    /**
     * @dev Update betting limits (owner only)
     * @param newMinBet New minimum bet
     * @param newMaxBet New maximum bet
     */
    function updateBetLimits(uint256 newMinBet, uint256 newMaxBet) external onlyOwner {
        require(newMinBet < newMaxBet, "Invalid limits");
        minBet = newMinBet;
        maxBet = newMaxBet;
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
     * @return Current balance
     */
    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
