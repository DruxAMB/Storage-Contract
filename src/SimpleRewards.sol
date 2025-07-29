// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title SimpleRewards
 * @dev A simple points/rewards system for user engagement
 * @notice Allows users to earn points and redeem rewards with leaderboards
 */
contract SimpleRewards {
    
    // Structs
    struct User {
        uint256 totalPoints;
        uint256 availablePoints;
        uint256 redeemedPoints;
        uint256 lastActivity;
        bool isActive;
    }
    
    struct Reward {
        uint256 id;
        string name;
        string description;
        uint256 pointsCost;
        uint256 totalRedeemed;
        bool isActive;
        address creator;
    }
    
    struct Redemption {
        uint256 id;
        address user;
        uint256 rewardId;
        uint256 pointsSpent;
        uint256 timestamp;
        bool fulfilled;
    }
    
    // State variables
    mapping(address => User) public users;
    mapping(uint256 => Reward) public rewards;
    mapping(uint256 => Redemption) public redemptions;
    mapping(address => uint256[]) public userRedemptions;
    
    address[] public activeUsers;
    uint256 public rewardCount;
    uint256 public redemptionCount;
    address public owner;
    
    // Constants
    uint256 public constant DAILY_BONUS = 10;
    uint256 public constant ACTIVITY_BONUS = 5;
    uint256 public constant MIN_ACTIVITY_GAP = 1 hours;
    
    // Events
    event PointsEarned(
        address indexed user,
        uint256 points,
        string reason,
        uint256 timestamp
    );
    
    event RewardCreated(
        uint256 indexed rewardId,
        string name,
        uint256 pointsCost,
        address indexed creator
    );
    
    event RewardRedeemed(
        uint256 indexed redemptionId,
        address indexed user,
        uint256 indexed rewardId,
        uint256 pointsSpent,
        uint256 timestamp
    );
    
    event RedemptionFulfilled(
        uint256 indexed redemptionId,
        address indexed user,
        uint256 timestamp
    );
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }
    
    modifier validReward(uint256 rewardId) {
        require(rewardId < rewardCount, "Reward does not exist");
        require(rewards[rewardId].isActive, "Reward is not active");
        _;
    }
    
    constructor() {
        owner = msg.sender;
    }
    
    /**
     * @dev Award points to a user for activity
     * @param user User address to award points
     * @param points Number of points to award
     * @param reason Reason for awarding points
     */
    function awardPoints(address user, uint256 points, string memory reason) external onlyOwner {
        require(user != address(0), "Invalid user address");
        require(points > 0, "Points must be greater than 0");
        require(bytes(reason).length > 0, "Reason cannot be empty");
        
        User storage userData = users[user];
        
        // Initialize user if first time
        if (!userData.isActive) {
            userData.isActive = true;
            activeUsers.push(user);
        }
        
        userData.totalPoints += points;
        userData.availablePoints += points;
        userData.lastActivity = block.timestamp;
        
        emit PointsEarned(user, points, reason, block.timestamp);
    }
    
    /**
     * @dev Claim daily bonus points (once per day)
     */
    function claimDailyBonus() external {
        User storage userData = users[msg.sender];
        
        require(
            block.timestamp >= userData.lastActivity + 1 days || userData.lastActivity == 0,
            "Daily bonus already claimed"
        );
        
        // Initialize user if first time
        if (!userData.isActive) {
            userData.isActive = true;
            activeUsers.push(msg.sender);
        }
        
        userData.totalPoints += DAILY_BONUS;
        userData.availablePoints += DAILY_BONUS;
        userData.lastActivity = block.timestamp;
        
        emit PointsEarned(msg.sender, DAILY_BONUS, "Daily bonus", block.timestamp);
    }
    
    /**
     * @dev Earn activity bonus for engagement (limited frequency)
     */
    function earnActivityBonus() external {
        User storage userData = users[msg.sender];
        
        require(
            block.timestamp >= userData.lastActivity + MIN_ACTIVITY_GAP,
            "Activity bonus on cooldown"
        );
        
        // Initialize user if first time
        if (!userData.isActive) {
            userData.isActive = true;
            activeUsers.push(msg.sender);
        }
        
        userData.totalPoints += ACTIVITY_BONUS;
        userData.availablePoints += ACTIVITY_BONUS;
        userData.lastActivity = block.timestamp;
        
        emit PointsEarned(msg.sender, ACTIVITY_BONUS, "Activity bonus", block.timestamp);
    }
    
    /**
     * @dev Create a new reward (owner only)
     * @param name Reward name
     * @param description Reward description
     * @param pointsCost Points required to redeem
     * @return rewardId The ID of the created reward
     */
    function createReward(
        string memory name,
        string memory description,
        uint256 pointsCost
    ) external onlyOwner returns (uint256 rewardId) {
        require(bytes(name).length > 0, "Name cannot be empty");
        require(bytes(description).length > 0, "Description cannot be empty");
        require(pointsCost > 0, "Points cost must be greater than 0");
        
        rewardId = rewardCount++;
        
        rewards[rewardId] = Reward({
            id: rewardId,
            name: name,
            description: description,
            pointsCost: pointsCost,
            totalRedeemed: 0,
            isActive: true,
            creator: msg.sender
        });
        
        emit RewardCreated(rewardId, name, pointsCost, msg.sender);
    }
    
    /**
     * @dev Redeem a reward with points
     * @param rewardId The reward ID to redeem
     * @return redemptionId The ID of the redemption
     */
    function redeemReward(uint256 rewardId) external validReward(rewardId) returns (uint256 redemptionId) {
        User storage userData = users[msg.sender];
        Reward storage reward = rewards[rewardId];
        
        require(userData.isActive, "User not active");
        require(userData.availablePoints >= reward.pointsCost, "Insufficient points");
        
        // Deduct points
        userData.availablePoints -= reward.pointsCost;
        userData.redeemedPoints += reward.pointsCost;
        
        // Update reward stats
        reward.totalRedeemed++;
        
        // Create redemption record
        redemptionId = redemptionCount++;
        redemptions[redemptionId] = Redemption({
            id: redemptionId,
            user: msg.sender,
            rewardId: rewardId,
            pointsSpent: reward.pointsCost,
            timestamp: block.timestamp,
            fulfilled: false
        });
        
        userRedemptions[msg.sender].push(redemptionId);
        
        emit RewardRedeemed(redemptionId, msg.sender, rewardId, reward.pointsCost, block.timestamp);
    }
    
    /**
     * @dev Mark a redemption as fulfilled (owner only)
     * @param redemptionId The redemption ID to fulfill
     */
    function fulfillRedemption(uint256 redemptionId) external onlyOwner {
        require(redemptionId < redemptionCount, "Redemption does not exist");
        
        Redemption storage redemption = redemptions[redemptionId];
        require(!redemption.fulfilled, "Redemption already fulfilled");
        
        redemption.fulfilled = true;
        
        emit RedemptionFulfilled(redemptionId, redemption.user, block.timestamp);
    }
    
    /**
     * @dev Deactivate a reward (owner only)
     * @param rewardId The reward ID to deactivate
     */
    function deactivateReward(uint256 rewardId) external onlyOwner {
        require(rewardId < rewardCount, "Reward does not exist");
        rewards[rewardId].isActive = false;
    }
    
    /**
     * @dev Get user information
     * @param user User address
     * @return totalPoints Total points earned
     * @return availablePoints Points available to spend
     * @return redeemedPoints Points already redeemed
     * @return lastActivity Last activity timestamp
     * @return isActive Whether user is active
     */
    function getUser(address user) external view returns (
        uint256 totalPoints,
        uint256 availablePoints,
        uint256 redeemedPoints,
        uint256 lastActivity,
        bool isActive
    ) {
        User storage userData = users[user];
        return (
            userData.totalPoints,
            userData.availablePoints,
            userData.redeemedPoints,
            userData.lastActivity,
            userData.isActive
        );
    }
    
    /**
     * @dev Get reward information
     * @param rewardId Reward ID
     * @return name Reward name
     * @return description Reward description
     * @return pointsCost Points required
     * @return totalRedeemed Total times redeemed
     * @return isActive Whether reward is active
     */
    function getReward(uint256 rewardId) external view returns (
        string memory name,
        string memory description,
        uint256 pointsCost,
        uint256 totalRedeemed,
        bool isActive
    ) {
        require(rewardId < rewardCount, "Reward does not exist");
        
        Reward storage reward = rewards[rewardId];
        return (
            reward.name,
            reward.description,
            reward.pointsCost,
            reward.totalRedeemed,
            reward.isActive
        );
    }
    
    /**
     * @dev Get user's redemption history
     * @param user User address
     * @return redemptionIds Array of redemption IDs
     */
    function getUserRedemptions(address user) external view returns (uint256[] memory redemptionIds) {
        return userRedemptions[user];
    }
    
    /**
     * @dev Get leaderboard (top users by total points)
     * @param limit Number of top users to return
     * @return topUsers Array of user addresses
     * @return topPoints Array of corresponding point totals
     */
    function getLeaderboard(uint256 limit) external view returns (
        address[] memory topUsers,
        uint256[] memory topPoints
    ) {
        uint256 userCount = activeUsers.length;
        if (limit > userCount) {
            limit = userCount;
        }
        
        topUsers = new address[](limit);
        topPoints = new uint256[](limit);
        
        // Simple sorting for top users (gas-efficient for small lists)
        for (uint256 i = 0; i < limit; i++) {
            uint256 maxPoints = 0;
            address maxUser = address(0);
            
            for (uint256 j = 0; j < userCount; j++) {
                address currentUser = activeUsers[j];
                uint256 currentPoints = users[currentUser].totalPoints;
                
                // Check if this user is already in the results
                bool alreadyIncluded = false;
                for (uint256 k = 0; k < i; k++) {
                    if (topUsers[k] == currentUser) {
                        alreadyIncluded = true;
                        break;
                    }
                }
                
                if (!alreadyIncluded && currentPoints > maxPoints) {
                    maxPoints = currentPoints;
                    maxUser = currentUser;
                }
            }
            
            if (maxUser != address(0)) {
                topUsers[i] = maxUser;
                topPoints[i] = maxPoints;
            }
        }
    }
    
    /**
     * @dev Get total number of active users
     * @return count Number of active users
     */
    function getActiveUserCount() external view returns (uint256 count) {
        return activeUsers.length;
    }
    
    /**
     * @dev Get total number of rewards
     * @return count Number of rewards created
     */
    function getTotalRewards() external view returns (uint256 count) {
        return rewardCount;
    }
    
    /**
     * @dev Check if user can claim daily bonus
     * @param user User address
     * @return canClaim Whether user can claim daily bonus
     */
    function canClaimDailyBonus(address user) external view returns (bool canClaim) {
        User storage userData = users[user];
        return block.timestamp >= userData.lastActivity + 1 days || userData.lastActivity == 0;
    }
    
    /**
     * @dev Check if user can earn activity bonus
     * @param user User address
     * @return canEarn Whether user can earn activity bonus
     */
    function canEarnActivityBonus(address user) external view returns (bool canEarn) {
        User storage userData = users[user];
        return block.timestamp >= userData.lastActivity + MIN_ACTIVITY_GAP;
    }
}
