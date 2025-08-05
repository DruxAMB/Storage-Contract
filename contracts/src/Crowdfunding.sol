// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v4.8.0/contracts/security/ReentrancyGuard.sol";

/**
 * @title Crowdfunding
 * @dev A contract for creating and managing crowdfunding campaigns.
 * @notice Users can create campaigns, contribute funds, and claim or refund based on the outcome.
 */
contract Crowdfunding is ReentrancyGuard {

    // Enum for campaign status
    enum Status { FUNDING, SUCCEEDED, FAILED }

    // Struct for a campaign
    struct Campaign {
        address payable owner;
        string description;
        uint256 goalAmount;
        uint256 deadline;
        uint256 raisedAmount;
        Status status;
        mapping(address => uint256) contributions;
        bool exists;
    }

    // State variables
    uint256 public campaignCount;
    mapping(uint256 => Campaign) public campaigns;

    // Events
    event CampaignCreated(uint256 indexed campaignId, address indexed owner, uint256 goal, uint256 deadline);
    event Contribution(uint256 indexed campaignId, address indexed contributor, uint256 amount);
    event FundsClaimed(uint256 indexed campaignId, address indexed owner, uint256 amount);
    event Refunded(uint256 indexed campaignId, address indexed contributor, uint256 amount);

    /**
     * @notice Creates a new crowdfunding campaign.
     * @param _description A description of the campaign.
     * @param _goalAmount The funding goal in wei.
     * @param _durationSeconds The duration of the campaign.
     * @return The ID of the new campaign.
     */
    function createCampaign(string memory _description, uint256 _goalAmount, uint256 _durationSeconds) external returns (uint256) {
        require(_goalAmount > 0, "Goal must be positive");
        require(_durationSeconds > 0, "Duration must be positive");

        uint256 campaignId = campaignCount;
        campaigns[campaignId] = Campaign({
            owner: payable(msg.sender),
            description: _description,
            goalAmount: _goalAmount,
            deadline: block.timestamp + _durationSeconds,
            raisedAmount: 0,
            status: Status.FUNDING,
            exists: true
        });

        campaignCount++;
        emit CampaignCreated(campaignId, msg.sender, _goalAmount, campaigns[campaignId].deadline);
        return campaignId;
    }

    /**
     * @notice Contributes funds to a campaign.
     * @param _campaignId The ID of the campaign.
     */
    function contribute(uint256 _campaignId) external payable {
        require(_campaignId < campaignCount && campaigns[_campaignId].exists, "Campaign not found");
        Campaign storage c = campaigns[_campaignId];

        require(c.status == Status.FUNDING, "Campaign is not active");
        require(block.timestamp < c.deadline, "Campaign has ended");
        require(msg.value > 0, "Contribution must be positive");

        c.contributions[msg.sender] += msg.value;
        c.raisedAmount += msg.value;

        emit Contribution(_campaignId, msg.sender, msg.value);
    }

    /**
     * @notice Checks the status of a campaign and updates it if the deadline has passed.
     * @param _campaignId The ID of the campaign.
     */
    function checkStatus(uint256 _campaignId) public {
        require(_campaignId < campaignCount && campaigns[_campaignId].exists, "Campaign not found");
        Campaign storage c = campaigns[_campaignId];

        if (c.status == Status.FUNDING && block.timestamp >= c.deadline) {
            if (c.raisedAmount >= c.goalAmount) {
                c.status = Status.SUCCEEDED;
            } else {
                c.status = Status.FAILED;
            }
        }
    }

    /**
     * @notice Allows the campaign owner to claim the funds if the goal was met.
     * @param _campaignId The ID of the campaign.
     */
    function claimFunds(uint256 _campaignId) external nonReentrant {
        require(_campaignId < campaignCount && campaigns[_campaignId].exists, "Campaign not found");
        Campaign storage c = campaigns[_campaignId];

        require(msg.sender == c.owner, "Not the owner");
        checkStatus(_campaignId);
        require(c.status == Status.SUCCEEDED, "Campaign did not succeed");

        uint256 amount = c.raisedAmount;
        c.raisedAmount = 0; // Prevent re-entrancy

        c.owner.transfer(amount);
        emit FundsClaimed(_campaignId, c.owner, amount);
    }

    /**
     * @notice Allows contributors to get a refund if the campaign failed.
     * @param _campaignId The ID of the campaign.
     */
    function getRefund(uint256 _campaignId) external nonReentrant {
        require(_campaignId < campaignCount && campaigns[_campaignId].exists, "Campaign not found");
        Campaign storage c = campaigns[_campaignId];

        checkStatus(_campaignId);
        require(c.status == Status.FAILED, "Campaign did not fail");

        uint256 contribution = c.contributions[msg.sender];
        require(contribution > 0, "No contribution to refund");

        c.contributions[msg.sender] = 0; // Prevent re-entrancy

        payable(msg.sender).transfer(contribution);
        emit Refunded(_campaignId, msg.sender, contribution);
    }
}
