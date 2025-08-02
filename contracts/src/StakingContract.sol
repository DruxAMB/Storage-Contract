// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title StakingContract
 * @dev Stake ETH to earn rewards with flexible lock periods and compound interest
 * @notice Earn passive income by staking ETH with various reward tiers and lock periods
 */
contract StakingContract {
    // Structs
    struct Stake {
        uint256 amount;
        uint256 startTime;
        uint256 lockPeriod; // in seconds
        uint256 rewardRate; // in basis points (e.g., 1000 = 10% APY)
        uint256 lastClaimTime;
        bool active;
        uint256 totalRewardsClaimed;
    }

    struct StakingTier {
        string name;
        uint256 minAmount;
        uint256 lockPeriod;
        uint256 rewardRate; // annual percentage in basis points
        bool active;
    }

    // State variables
    mapping(address => Stake[]) public userStakes;
    mapping(address => uint256) public totalStaked;
    mapping(address => uint256) public totalRewardsClaimed;
    
    StakingTier[] public stakingTiers;
    
    address public owner;
    uint256 public totalStakedAmount;
    uint256 public totalRewardsPaid;
    uint256 public contractBalance;
    uint256 public emergencyWithdrawPenalty; // in basis points
    bool public stakingEnabled;
    bool public emergencyMode;

    // Events
    event Staked(
        address indexed user,
        uint256 indexed stakeIndex,
        uint256 amount,
        uint256 lockPeriod,
        uint256 rewardRate
    );
    event Unstaked(
        address indexed user,
        uint256 indexed stakeIndex,
        uint256 amount,
        uint256 rewards
    );
    event RewardsClaimed(
        address indexed user,
        uint256 indexed stakeIndex,
        uint256 rewards
    );
    event EmergencyWithdraw(
        address indexed user,
        uint256 indexed stakeIndex,
        uint256 amount,
        uint256 penalty
    );
    event TierAdded(
        uint256 indexed tierId,
        string name,
        uint256 minAmount,
        uint256 lockPeriod,
        uint256 rewardRate
    );
    event TierUpdated(uint256 indexed tierId, bool active);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event StakingToggled(bool enabled);
    event EmergencyModeToggled(bool enabled);

    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }
    
    modifier stakingActive() {
        require(stakingEnabled && !emergencyMode, "Staking not available");
        _;
    }
    
    modifier validStake(address user, uint256 stakeIndex) {
        require(stakeIndex < userStakes[user].length, "Invalid stake index");
        require(userStakes[user][stakeIndex].active, "Stake not active");
        _;
    }

    /**
     * @dev Constructor sets up initial staking tiers and parameters
     * @param _emergencyWithdrawPenalty Penalty for emergency withdrawals (basis points)
     */
    constructor(uint256 _emergencyWithdrawPenalty) {
        owner = msg.sender;
        emergencyWithdrawPenalty = _emergencyWithdrawPenalty;
        stakingEnabled = true;
        emergencyMode = false;
        
        // Initialize default staking tiers
        _addTier("Bronze", 0.01 ether, 30 days, 500); // 5% APY, 30 days
        _addTier("Silver", 0.1 ether, 90 days, 800); // 8% APY, 90 days
        _addTier("Gold", 1 ether, 180 days, 1200); // 12% APY, 180 days
        _addTier("Platinum", 10 ether, 365 days, 1500); // 15% APY, 1 year
    }

    /**
     * @dev Stake ETH in a specific tier
     * @param tierIndex Index of the staking tier
     */
    function stake(uint256 tierIndex) external payable stakingActive {
        require(tierIndex < stakingTiers.length, "Invalid tier");
        require(stakingTiers[tierIndex].active, "Tier not active");
        require(msg.value >= stakingTiers[tierIndex].minAmount, "Amount below minimum");
        require(msg.value > 0, "Cannot stake 0 ETH");

        StakingTier memory tier = stakingTiers[tierIndex];
        
        userStakes[msg.sender].push(Stake({
            amount: msg.value,
            startTime: block.timestamp,
            lockPeriod: tier.lockPeriod,
            rewardRate: tier.rewardRate,
            lastClaimTime: block.timestamp,
            active: true,
            totalRewardsClaimed: 0
        }));

        totalStaked[msg.sender] += msg.value;
        totalStakedAmount += msg.value;
        contractBalance += msg.value;

        uint256 stakeIndex = userStakes[msg.sender].length - 1;
        
        emit Staked(
            msg.sender,
            stakeIndex,
            msg.value,
            tier.lockPeriod,
            tier.rewardRate
        );
    }

    /**
     * @dev Unstake after lock period ends
     * @param stakeIndex Index of the stake to unstake
     */
    function unstake(uint256 stakeIndex) 
        external 
        validStake(msg.sender, stakeIndex) 
    {
        Stake storage userStake = userStakes[msg.sender][stakeIndex];
        
        require(
            block.timestamp >= userStake.startTime + userStake.lockPeriod,
            "Lock period not ended"
        );

        uint256 stakedAmount = userStake.amount;
        uint256 pendingRewards = calculatePendingRewards(msg.sender, stakeIndex);
        uint256 totalPayout = stakedAmount + pendingRewards;

        require(address(this).balance >= totalPayout, "Insufficient contract balance");

        // Update state
        userStake.active = false;
        userStake.totalRewardsClaimed += pendingRewards;
        totalStaked[msg.sender] -= stakedAmount;
        totalStakedAmount -= stakedAmount;
        totalRewardsClaimed[msg.sender] += pendingRewards;
        totalRewardsPaid += pendingRewards;
        contractBalance -= stakedAmount;

        // Transfer funds
        payable(msg.sender).transfer(totalPayout);

        emit Unstaked(msg.sender, stakeIndex, stakedAmount, pendingRewards);
    }

    /**
     * @dev Claim rewards without unstaking
     * @param stakeIndex Index of the stake to claim rewards from
     */
    function claimRewards(uint256 stakeIndex) 
        external 
        validStake(msg.sender, stakeIndex) 
    {
        uint256 pendingRewards = calculatePendingRewards(msg.sender, stakeIndex);
        require(pendingRewards > 0, "No rewards to claim");
        require(address(this).balance >= pendingRewards, "Insufficient contract balance");

        Stake storage userStake = userStakes[msg.sender][stakeIndex];
        userStake.lastClaimTime = block.timestamp;
        userStake.totalRewardsClaimed += pendingRewards;
        
        totalRewardsClaimed[msg.sender] += pendingRewards;
        totalRewardsPaid += pendingRewards;

        payable(msg.sender).transfer(pendingRewards);

        emit RewardsClaimed(msg.sender, stakeIndex, pendingRewards);
    }

    /**
     * @dev Emergency withdraw with penalty (before lock period ends)
     * @param stakeIndex Index of the stake to emergency withdraw
     */
    function emergencyWithdraw(uint256 stakeIndex) 
        external 
        validStake(msg.sender, stakeIndex) 
    {
        Stake storage userStake = userStakes[msg.sender][stakeIndex];
        uint256 stakedAmount = userStake.amount;
        uint256 penalty = (stakedAmount * emergencyWithdrawPenalty) / 10000;
        uint256 withdrawAmount = stakedAmount - penalty;

        require(address(this).balance >= withdrawAmount, "Insufficient contract balance");

        // Update state
        userStake.active = false;
        totalStaked[msg.sender] -= stakedAmount;
        totalStakedAmount -= stakedAmount;
        contractBalance -= stakedAmount;

        // Transfer funds (minus penalty)
        payable(msg.sender).transfer(withdrawAmount);

        emit EmergencyWithdraw(msg.sender, stakeIndex, withdrawAmount, penalty);
    }

    /**
     * @dev Calculate pending rewards for a stake
     * @param user User address
     * @param stakeIndex Stake index
     * @return pendingRewards Amount of pending rewards
     */
    function calculatePendingRewards(address user, uint256 stakeIndex) 
        public 
        view 
        returns (uint256 pendingRewards) 
    {
        if (stakeIndex >= userStakes[user].length) return 0;
        
        Stake memory userStake = userStakes[user][stakeIndex];
        if (!userStake.active) return 0;

        uint256 timeStaked = block.timestamp - userStake.lastClaimTime;
        uint256 annualReward = (userStake.amount * userStake.rewardRate) / 10000;
        pendingRewards = (annualReward * timeStaked) / 365 days;
    }

    /**
     * @dev Add a new staking tier
     * @param name Tier name
     * @param minAmount Minimum stake amount
     * @param lockPeriod Lock period in seconds
     * @param rewardRate Annual reward rate in basis points
     */
    function addTier(
        string memory name,
        uint256 minAmount,
        uint256 lockPeriod,
        uint256 rewardRate
    ) external onlyOwner {
        _addTier(name, minAmount, lockPeriod, rewardRate);
    }

    /**
     * @dev Internal function to add tier
     */
    function _addTier(
        string memory name,
        uint256 minAmount,
        uint256 lockPeriod,
        uint256 rewardRate
    ) internal {
        require(minAmount > 0, "Minimum amount must be positive");
        require(lockPeriod > 0, "Lock period must be positive");
        require(rewardRate <= 5000, "Reward rate too high"); // Max 50% APY

        stakingTiers.push(StakingTier({
            name: name,
            minAmount: minAmount,
            lockPeriod: lockPeriod,
            rewardRate: rewardRate,
            active: true
        }));

        uint256 tierId = stakingTiers.length - 1;
        emit TierAdded(tierId, name, minAmount, lockPeriod, rewardRate);
    }

    /**
     * @dev Toggle tier active status
     * @param tierIndex Tier index
     * @param active New active status
     */
    function toggleTier(uint256 tierIndex, bool active) external onlyOwner {
        require(tierIndex < stakingTiers.length, "Invalid tier");
        stakingTiers[tierIndex].active = active;
        emit TierUpdated(tierIndex, active);
    }

    /**
     * @dev Toggle staking enabled/disabled
     */
    function toggleStaking() external onlyOwner {
        stakingEnabled = !stakingEnabled;
        emit StakingToggled(stakingEnabled);
    }

    /**
     * @dev Toggle emergency mode
     */
    function toggleEmergencyMode() external onlyOwner {
        emergencyMode = !emergencyMode;
        emit EmergencyModeToggled(emergencyMode);
    }

    /**
     * @dev Owner can add funds to contract for rewards
     */
    function addRewardFunds() external payable onlyOwner {
        require(msg.value > 0, "Must send ETH");
        contractBalance += msg.value;
    }

    /**
     * @dev Owner emergency withdraw (only excess funds)
     * @param amount Amount to withdraw
     */
    function ownerWithdraw(uint256 amount) external onlyOwner {
        uint256 excessFunds = address(this).balance - totalStakedAmount;
        require(amount <= excessFunds, "Cannot withdraw staked funds");
        require(amount > 0, "Amount must be positive");
        
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
     * @dev Get user's stakes
     * @param user User address
     * @return stakes Array of user's stakes
     */
    function getUserStakes(address user) 
        external 
        view 
        returns (Stake[] memory stakes) 
    {
        return userStakes[user];
    }

    /**
     * @dev Get staking tier details
     * @param tierIndex Tier index
     * @return name Tier name
     * @return minAmount Minimum stake amount
     * @return lockPeriod Lock period in seconds
     * @return rewardRate Annual reward rate in basis points
     * @return active Whether tier is active
     */
    function getTier(uint256 tierIndex) 
        external 
        view 
        returns (
            string memory name,
            uint256 minAmount,
            uint256 lockPeriod,
            uint256 rewardRate,
            bool active
        ) 
    {
        require(tierIndex < stakingTiers.length, "Invalid tier");
        StakingTier memory tier = stakingTiers[tierIndex];
        return (tier.name, tier.minAmount, tier.lockPeriod, tier.rewardRate, tier.active);
    }

    /**
     * @dev Get contract statistics
     * @return totalStakedETH Total ETH staked
     * @return totalRewardsDistributed Total rewards paid out
     * @return contractETHBalance Current contract balance
     * @return isStakingActive Whether staking is enabled
     * @return isEmergencyActive Whether emergency mode is active
     * @return tierCount Number of staking tiers
     */
    function getContractStats() 
        external 
        view 
        returns (
            uint256 totalStakedETH,
            uint256 totalRewardsDistributed,
            uint256 contractETHBalance,
            bool isStakingActive,
            bool isEmergencyActive,
            uint256 tierCount
        ) 
    {
        return (
            totalStakedAmount,
            totalRewardsPaid,
            address(this).balance,
            stakingEnabled && !emergencyMode,
            emergencyMode,
            stakingTiers.length
        );
    }

    /**
     * @dev Get user statistics
     * @param user User address
     * @return userTotalStaked Total amount staked by user
     * @return userTotalRewards Total rewards claimed by user
     * @return activeStakesCount Number of active stakes
     * @return totalPendingRewards Total pending rewards across all stakes
     */
    function getUserStats(address user) 
        external 
        view 
        returns (
            uint256 userTotalStaked,
            uint256 userTotalRewards,
            uint256 activeStakesCount,
            uint256 totalPendingRewards
        ) 
    {
        userTotalStaked = totalStaked[user];
        userTotalRewards = totalRewardsClaimed[user];
        
        for (uint256 i = 0; i < userStakes[user].length; i++) {
            if (userStakes[user][i].active) {
                activeStakesCount++;
                totalPendingRewards += calculatePendingRewards(user, i);
            }
        }
    }

    /**
     * @dev Fallback function to receive ETH
     */
    receive() external payable {
        contractBalance += msg.value;
    }
}
