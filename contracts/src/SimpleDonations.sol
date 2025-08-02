// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title SimpleDonations
 * @dev A simple donation/crowdfunding platform for transparent fundraising
 * @notice Allows users to create campaigns, donate ETH, and track funding goals
 */
contract SimpleDonations {
    
    // Structs
    struct Campaign {
        uint256 id;
        string title;
        string description;
        address payable creator;
        uint256 goalAmount;
        uint256 raisedAmount;
        uint256 createdAt;
        uint256 deadline;
        bool isActive;
        bool goalReached;
        bool fundsWithdrawn;
    }
    
    struct Donation {
        uint256 id;
        uint256 campaignId;
        address donor;
        uint256 amount;
        uint256 timestamp;
        string message;
    }
    
    // State variables
    mapping(uint256 => Campaign) public campaigns;
    mapping(uint256 => Donation) public donations;
    mapping(uint256 => uint256[]) public campaignDonations;
    mapping(address => uint256[]) public userCampaigns;
    mapping(address => uint256[]) public userDonations;
    
    uint256 public campaignCount;
    uint256 public donationCount;
    uint256 public totalRaised;
    
    // Platform fee (in basis points, 250 = 2.5%)
    uint256 public platformFee = 250;
    address payable public owner;
    
    // Events
    event CampaignCreated(
        uint256 indexed campaignId,
        address indexed creator,
        string title,
        uint256 goalAmount,
        uint256 deadline
    );
    
    event DonationMade(
        uint256 indexed donationId,
        uint256 indexed campaignId,
        address indexed donor,
        uint256 amount,
        string message
    );
    
    event GoalReached(
        uint256 indexed campaignId,
        uint256 totalRaised,
        uint256 timestamp
    );
    
    event FundsWithdrawn(
        uint256 indexed campaignId,
        address indexed creator,
        uint256 amount,
        uint256 platformFee
    );
    
    event CampaignClosed(
        uint256 indexed campaignId,
        address indexed creator,
        uint256 timestamp
    );
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }
    
    modifier validCampaign(uint256 campaignId) {
        require(campaignId < campaignCount, "Campaign does not exist");
        _;
    }
    
    modifier activeCampaign(uint256 campaignId) {
        require(campaigns[campaignId].isActive, "Campaign is not active");
        require(block.timestamp <= campaigns[campaignId].deadline, "Campaign has ended");
        _;
    }
    
    constructor() {
        owner = payable(msg.sender);
    }
    
    /**
     * @dev Create a new fundraising campaign
     * @param title Campaign title
     * @param description Campaign description
     * @param goalAmount Target amount to raise (in wei)
     * @param durationDays Campaign duration in days
     * @return campaignId The ID of the created campaign
     */
    function createCampaign(
        string memory title,
        string memory description,
        uint256 goalAmount,
        uint256 durationDays
    ) external returns (uint256 campaignId) {
        require(bytes(title).length > 0, "Title cannot be empty");
        require(bytes(description).length > 0, "Description cannot be empty");
        require(goalAmount > 0, "Goal amount must be greater than 0");
        require(durationDays > 0 && durationDays <= 365, "Invalid duration");
        
        campaignId = campaignCount++;
        uint256 deadline = block.timestamp + (durationDays * 1 days);
        
        campaigns[campaignId] = Campaign({
            id: campaignId,
            title: title,
            description: description,
            creator: payable(msg.sender),
            goalAmount: goalAmount,
            raisedAmount: 0,
            createdAt: block.timestamp,
            deadline: deadline,
            isActive: true,
            goalReached: false,
            fundsWithdrawn: false
        });
        
        userCampaigns[msg.sender].push(campaignId);
        
        emit CampaignCreated(campaignId, msg.sender, title, goalAmount, deadline);
    }
    
    /**
     * @dev Donate ETH to a campaign
     * @param campaignId The campaign ID to donate to
     * @param message Optional message from donor
     */
    function donate(uint256 campaignId, string memory message) 
        external 
        payable 
        validCampaign(campaignId) 
        activeCampaign(campaignId) 
    {
        require(msg.value > 0, "Donation amount must be greater than 0");
        
        Campaign storage campaign = campaigns[campaignId];
        
        // Create donation record
        uint256 donationId = donationCount++;
        donations[donationId] = Donation({
            id: donationId,
            campaignId: campaignId,
            donor: msg.sender,
            amount: msg.value,
            timestamp: block.timestamp,
            message: message
        });
        
        // Update campaign
        campaign.raisedAmount += msg.value;
        totalRaised += msg.value;
        
        // Track donations
        campaignDonations[campaignId].push(donationId);
        userDonations[msg.sender].push(donationId);
        
        // Check if goal is reached
        if (!campaign.goalReached && campaign.raisedAmount >= campaign.goalAmount) {
            campaign.goalReached = true;
            emit GoalReached(campaignId, campaign.raisedAmount, block.timestamp);
        }
        
        emit DonationMade(donationId, campaignId, msg.sender, msg.value, message);
    }
    
    /**
     * @dev Withdraw funds from a campaign (creator only)
     * @param campaignId The campaign ID to withdraw from
     */
    function withdrawFunds(uint256 campaignId) 
        external 
        validCampaign(campaignId) 
    {
        Campaign storage campaign = campaigns[campaignId];
        require(msg.sender == campaign.creator, "Only creator can withdraw");
        require(!campaign.fundsWithdrawn, "Funds already withdrawn");
        require(campaign.raisedAmount > 0, "No funds to withdraw");
        
        // Can withdraw if goal reached OR campaign ended
        require(
            campaign.goalReached || block.timestamp > campaign.deadline,
            "Cannot withdraw yet"
        );
        
        uint256 totalAmount = campaign.raisedAmount;
        uint256 feeAmount = (totalAmount * platformFee) / 10000;
        uint256 creatorAmount = totalAmount - feeAmount;
        
        campaign.fundsWithdrawn = true;
        campaign.isActive = false;
        
        // Transfer funds
        if (feeAmount > 0) {
            owner.transfer(feeAmount);
        }
        campaign.creator.transfer(creatorAmount);
        
        emit FundsWithdrawn(campaignId, campaign.creator, creatorAmount, feeAmount);
    }
    
    /**
     * @dev Close a campaign early (creator only)
     * @param campaignId The campaign ID to close
     */
    function closeCampaign(uint256 campaignId) 
        external 
        validCampaign(campaignId) 
    {
        Campaign storage campaign = campaigns[campaignId];
        require(msg.sender == campaign.creator, "Only creator can close campaign");
        require(campaign.isActive, "Campaign already closed");
        
        campaign.isActive = false;
        
        emit CampaignClosed(campaignId, campaign.creator, block.timestamp);
    }
    
    /**
     * @dev Get campaign information
     * @param campaignId Campaign ID
     * @return title Campaign title
     * @return description Campaign description
     * @return creator Campaign creator address
     * @return goalAmount Target amount
     * @return raisedAmount Amount raised so far
     * @return deadline Campaign deadline
     * @return isActive Whether campaign is active
     * @return goalReached Whether goal was reached
     */
    function getCampaign(uint256 campaignId) 
        external 
        view 
        validCampaign(campaignId) 
        returns (
            string memory title,
            string memory description,
            address creator,
            uint256 goalAmount,
            uint256 raisedAmount,
            uint256 deadline,
            bool isActive,
            bool goalReached
        ) 
    {
        Campaign storage campaign = campaigns[campaignId];
        return (
            campaign.title,
            campaign.description,
            campaign.creator,
            campaign.goalAmount,
            campaign.raisedAmount,
            campaign.deadline,
            campaign.isActive,
            campaign.goalReached
        );
    }
    
    /**
     * @dev Get donation information
     * @param donationId Donation ID
     * @return campaignId Campaign that received donation
     * @return donor Donor address
     * @return amount Donation amount
     * @return timestamp Donation timestamp
     * @return message Donor message
     */
    function getDonation(uint256 donationId) 
        external 
        view 
        returns (
            uint256 campaignId,
            address donor,
            uint256 amount,
            uint256 timestamp,
            string memory message
        ) 
    {
        require(donationId < donationCount, "Donation does not exist");
        
        Donation storage donation = donations[donationId];
        return (
            donation.campaignId,
            donation.donor,
            donation.amount,
            donation.timestamp,
            donation.message
        );
    }
    
    /**
     * @dev Get all donations for a campaign
     * @param campaignId Campaign ID
     * @return donationIds Array of donation IDs
     */
    function getCampaignDonations(uint256 campaignId) 
        external 
        view 
        validCampaign(campaignId) 
        returns (uint256[] memory donationIds) 
    {
        return campaignDonations[campaignId];
    }
    
    /**
     * @dev Get campaigns created by a user
     * @param user User address
     * @return campaignIds Array of campaign IDs
     */
    function getUserCampaigns(address user) 
        external 
        view 
        returns (uint256[] memory campaignIds) 
    {
        return userCampaigns[user];
    }
    
    /**
     * @dev Get donations made by a user
     * @param user User address
     * @return donationIds Array of donation IDs
     */
    function getUserDonations(address user) 
        external 
        view 
        returns (uint256[] memory donationIds) 
    {
        return userDonations[user];
    }
    
    /**
     * @dev Get active campaigns (paginated)
     * @param offset Starting index
     * @param limit Maximum number of campaigns to return
     * @return campaignIds Array of active campaign IDs
     */
    function getActiveCampaigns(uint256 offset, uint256 limit) 
        external 
        view 
        returns (uint256[] memory campaignIds) 
    {
        uint256 activeCount = 0;
        
        // Count active campaigns
        for (uint256 i = 0; i < campaignCount; i++) {
            if (campaigns[i].isActive && block.timestamp <= campaigns[i].deadline) {
                activeCount++;
            }
        }
        
        if (offset >= activeCount) {
            return new uint256[](0);
        }
        
        uint256 end = offset + limit;
        if (end > activeCount) {
            end = activeCount;
        }
        
        campaignIds = new uint256[](end - offset);
        uint256 currentIndex = 0;
        uint256 resultIndex = 0;
        
        for (uint256 i = 0; i < campaignCount && resultIndex < (end - offset); i++) {
            if (campaigns[i].isActive && block.timestamp <= campaigns[i].deadline) {
                if (currentIndex >= offset) {
                    campaignIds[resultIndex] = i;
                    resultIndex++;
                }
                currentIndex++;
            }
        }
    }
    
    /**
     * @dev Get campaign progress percentage
     * @param campaignId Campaign ID
     * @return percentage Progress as percentage (0-100)
     */
    function getCampaignProgress(uint256 campaignId) 
        external 
        view 
        validCampaign(campaignId) 
        returns (uint256 percentage) 
    {
        Campaign storage campaign = campaigns[campaignId];
        if (campaign.goalAmount == 0) {
            return 0;
        }
        
        percentage = (campaign.raisedAmount * 100) / campaign.goalAmount;
        if (percentage > 100) {
            percentage = 100;
        }
    }
    
    /**
     * @dev Get total number of campaigns
     * @return count Total campaign count
     */
    function getTotalCampaigns() external view returns (uint256 count) {
        return campaignCount;
    }
    
    /**
     * @dev Get total number of donations
     * @return count Total donation count
     */
    function getTotalDonations() external view returns (uint256 count) {
        return donationCount;
    }
    
    /**
     * @dev Get platform statistics
     * @return totalCampaigns Total campaigns created
     * @return totalDonationsCount Total donations made
     * @return totalRaisedAmount Total ETH raised
     * @return activeCampaignsCount Number of active campaigns
     */
    function getPlatformStats() 
        external 
        view 
        returns (
            uint256 totalCampaigns,
            uint256 totalDonationsCount,
            uint256 totalRaisedAmount,
            uint256 activeCampaignsCount
        ) 
    {
        uint256 activeCount = 0;
        for (uint256 i = 0; i < campaignCount; i++) {
            if (campaigns[i].isActive && block.timestamp <= campaigns[i].deadline) {
                activeCount++;
            }
        }
        
        return (campaignCount, donationCount, totalRaised, activeCount);
    }
    
    /**
     * @dev Update platform fee (owner only)
     * @param newFee New platform fee in basis points
     */
    function updatePlatformFee(uint256 newFee) external onlyOwner {
        require(newFee <= 1000, "Platform fee too high"); // Max 10%
        platformFee = newFee;
    }
    
    /**
     * @dev Emergency withdraw (owner only) - for stuck funds
     */
    function emergencyWithdraw() external onlyOwner {
        owner.transfer(address(this).balance);
    }
}
