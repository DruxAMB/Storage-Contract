// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v4.8.0/contracts/token/ERC20/IERC20.sol";
import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v4.8.0/contracts/security/ReentrancyGuard.sol";
import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v4.8.0/contracts/access/Ownable.sol";

/**
 * @title SimpleDAO
 * @dev Basic decentralized autonomous organization with governance features
 * @notice Allows members to create proposals, vote, and manage treasury
 */
contract SimpleDAO is ReentrancyGuard, Ownable {
    // Proposal states
    enum ProposalState { PENDING, ACTIVE, SUCCEEDED, DEFEATED, EXECUTED, CANCELLED }
    
    // Proposal types
    enum ProposalType { GENERAL, TREASURY_TRANSFER, ADD_MEMBER, REMOVE_MEMBER, CHANGE_SETTINGS }
    
    // Membership types
    enum MembershipType { TOKEN_BASED, NFT_BASED, MANUAL }
    
    // Proposal struct
    struct Proposal {
        uint256 id;
        address proposer;
        string title;
        string description;
        ProposalType proposalType;
        address target;           // Target address for treasury transfers
        uint256 amount;          // Amount for treasury transfers
        bytes data;              // Additional data for execution
        uint256 startTime;
        uint256 endTime;
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 votesAbstain;
        bool executed;
        bool cancelled;
        mapping(address => bool) hasVoted;
        mapping(address => uint256) voteChoice; // 0=against, 1=for, 2=abstain
    }
    
    // Member struct
    struct Member {
        bool isActive;
        uint256 joinedAt;
        uint256 votingPower;
        uint256 proposalsCreated;
        uint256 votesParticipated;
    }
    
    // DAO settings
    struct DAOSettings {
        uint256 proposalDuration;      // Duration proposals stay open for voting
        uint256 minVotingPower;        // Minimum voting power to create proposals
        uint256 quorumPercentage;      // Percentage of total voting power needed for quorum
        uint256 majorityPercentage;    // Percentage of votes needed to pass
        bool requireMembershipToVote;  // Whether only members can vote
        MembershipType membershipType; // How membership is determined
    }
    
    // State variables
    uint256 public proposalCount;
    uint256 public memberCount;
    uint256 public totalVotingPower;
    
    // Mappings
    mapping(uint256 => Proposal) public proposals;
    mapping(address => Member) public members;
    mapping(address => bool) public isMember;
    
    // DAO settings
    DAOSettings public daoSettings;
    
    // Governance token (if token-based membership)
    IERC20 public governanceToken;
    
    // Events
    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        string title,
        ProposalType proposalType,
        uint256 startTime,
        uint256 endTime
    );
    
    event VoteCast(
        uint256 indexed proposalId,
        address indexed voter,
        uint256 choice,
        uint256 votingPower
    );
    
    event ProposalExecuted(uint256 indexed proposalId, bool success);
    event ProposalCancelled(uint256 indexed proposalId);
    
    event MemberAdded(address indexed member, uint256 votingPower);
    event MemberRemoved(address indexed member);
    event MemberVotingPowerUpdated(address indexed member, uint256 newVotingPower);
    
    event TreasuryDeposit(address indexed from, uint256 amount);
    event TreasuryWithdrawal(address indexed to, uint256 amount);
    
    event DAOSettingsUpdated();
    
    /**
     * @dev Constructor
     * @param _governanceToken Address of governance token (use address(0) for manual membership)
     * @param _proposalDuration Duration in seconds for proposal voting
     * @param _minVotingPower Minimum voting power required to create proposals
     * @param _quorumPercentage Percentage of total voting power needed for quorum (basis points)
     * @param _majorityPercentage Percentage of votes needed to pass (basis points)
     */
    constructor(
        address _governanceToken,
        uint256 _proposalDuration,
        uint256 _minVotingPower,
        uint256 _quorumPercentage,
        uint256 _majorityPercentage
    ) Ownable() {
        require(_quorumPercentage <= 10000, "Quorum cannot exceed 100%");
        require(_majorityPercentage <= 10000, "Majority cannot exceed 100%");
        require(_proposalDuration > 0, "Proposal duration must be positive");
        
        governanceToken = IERC20(_governanceToken);
        
        daoSettings = DAOSettings({
            proposalDuration: _proposalDuration,
            minVotingPower: _minVotingPower,
            quorumPercentage: _quorumPercentage,
            majorityPercentage: _majorityPercentage,
            requireMembershipToVote: true,
            membershipType: _governanceToken == address(0) ? MembershipType.MANUAL : MembershipType.TOKEN_BASED
        });
        
        // Add deployer as initial member with voting power
        _addMember(msg.sender, 1000);
    }
    
    /**
     * @dev Receive function to accept ETH deposits to treasury
     */
    receive() external payable {
        emit TreasuryDeposit(msg.sender, msg.value);
    }
    
    /**
     * @dev Create a new proposal
     * @param title Title of the proposal
     * @param description Description of the proposal
     * @param proposalType Type of proposal
     * @param target Target address (for treasury transfers)
     * @param amount Amount (for treasury transfers)
     * @param data Additional data for execution
     * @return proposalId ID of the created proposal
     */
    function createProposal(
        string memory title,
        string memory description,
        ProposalType proposalType,
        address target,
        uint256 amount,
        bytes memory data
    ) external returns (uint256 proposalId) {
        require(bytes(title).length > 0, "Title cannot be empty");
        require(bytes(description).length > 0, "Description cannot be empty");
        
        uint256 voterPower = getVotingPower(msg.sender);
        require(voterPower >= daoSettings.minVotingPower, "Insufficient voting power");
        
        // Validate proposal based on type
        if (proposalType == ProposalType.TREASURY_TRANSFER) {
            require(target != address(0), "Target address required");
            require(amount > 0, "Amount must be positive");
            require(amount <= address(this).balance, "Insufficient treasury balance");
        }
        
        proposalId = proposalCount++;
        
        Proposal storage proposal = proposals[proposalId];
        proposal.id = proposalId;
        proposal.proposer = msg.sender;
        proposal.title = title;
        proposal.description = description;
        proposal.proposalType = proposalType;
        proposal.target = target;
        proposal.amount = amount;
        proposal.data = data;
        proposal.startTime = block.timestamp;
        proposal.endTime = block.timestamp + daoSettings.proposalDuration;
        
        // Update member stats
        members[msg.sender].proposalsCreated++;
        
        emit ProposalCreated(
            proposalId,
            msg.sender,
            title,
            proposalType,
            proposal.startTime,
            proposal.endTime
        );
        
        return proposalId;
    }
    
    /**
     * @dev Cast a vote on a proposal
     * @param proposalId ID of the proposal to vote on
     * @param choice Vote choice (0=against, 1=for, 2=abstain)
     */
    function vote(uint256 proposalId, uint256 choice) external nonReentrant {
        require(choice <= 2, "Invalid vote choice");
        require(proposalId < proposalCount, "Proposal does not exist");
        
        Proposal storage proposal = proposals[proposalId];
        require(block.timestamp >= proposal.startTime, "Voting not started");
        require(block.timestamp <= proposal.endTime, "Voting ended");
        require(!proposal.hasVoted[msg.sender], "Already voted");
        require(!proposal.executed, "Proposal already executed");
        require(!proposal.cancelled, "Proposal cancelled");
        
        uint256 voterPower = getVotingPower(msg.sender);
        require(voterPower > 0, "No voting power");
        
        if (daoSettings.requireMembershipToVote) {
            require(isMember[msg.sender], "Must be a member to vote");
        }
        
        proposal.hasVoted[msg.sender] = true;
        proposal.voteChoice[msg.sender] = choice;
        
        if (choice == 0) {
            proposal.votesAgainst += voterPower;
        } else if (choice == 1) {
            proposal.votesFor += voterPower;
        } else {
            proposal.votesAbstain += voterPower;
        }
        
        // Update member stats
        members[msg.sender].votesParticipated++;
        
        emit VoteCast(proposalId, msg.sender, choice, voterPower);
    }
    
    /**
     * @dev Execute a proposal that has passed
     * @param proposalId ID of the proposal to execute
     */
    function executeProposal(uint256 proposalId) external nonReentrant {
        require(proposalId < proposalCount, "Proposal does not exist");
        
        Proposal storage proposal = proposals[proposalId];
        require(block.timestamp > proposal.endTime, "Voting still active");
        require(!proposal.executed, "Already executed");
        require(!proposal.cancelled, "Proposal cancelled");
        require(getProposalState(proposalId) == ProposalState.SUCCEEDED, "Proposal did not pass");
        
        proposal.executed = true;
        
        bool success = true;
        
        // Execute based on proposal type
        if (proposal.proposalType == ProposalType.TREASURY_TRANSFER) {
            success = _executeTreasuryTransfer(proposal.target, proposal.amount);
        } else if (proposal.proposalType == ProposalType.ADD_MEMBER) {
            _addMember(proposal.target, proposal.amount); // amount = voting power
        } else if (proposal.proposalType == ProposalType.REMOVE_MEMBER) {
            _removeMember(proposal.target);
        } else if (proposal.proposalType == ProposalType.CHANGE_SETTINGS) {
            // Custom execution logic would go here
            success = true;
        }
        
        emit ProposalExecuted(proposalId, success);
    }
    
    /**
     * @dev Cancel a proposal (only proposer or owner)
     * @param proposalId ID of the proposal to cancel
     */
    function cancelProposal(uint256 proposalId) external {
        require(proposalId < proposalCount, "Proposal does not exist");
        
        Proposal storage proposal = proposals[proposalId];
        require(
            msg.sender == proposal.proposer || msg.sender == owner(),
            "Only proposer or owner can cancel"
        );
        require(!proposal.executed, "Cannot cancel executed proposal");
        require(!proposal.cancelled, "Already cancelled");
        
        proposal.cancelled = true;
        
        emit ProposalCancelled(proposalId);
    }
    
    /**
     * @dev Add a member manually (owner only, for manual membership type)
     * @param member Address of the new member
     * @param votingPower Voting power to assign
     */
    function addMember(address member, uint256 votingPower) external onlyOwner {
        require(daoSettings.membershipType == MembershipType.MANUAL, "Not manual membership");
        _addMember(member, votingPower);
    }
    
    /**
     * @dev Remove a member manually (owner only, for manual membership type)
     * @param member Address of the member to remove
     */
    function removeMember(address member) external onlyOwner {
        require(daoSettings.membershipType == MembershipType.MANUAL, "Not manual membership");
        _removeMember(member);
    }
    
    /**
     * @dev Update DAO settings (owner only)
     * @param newProposalDuration New proposal duration
     * @param newMinVotingPower New minimum voting power
     * @param newQuorumPercentage New quorum percentage
     * @param newMajorityPercentage New majority percentage
     */
    function updateDAOSettings(
        uint256 newProposalDuration,
        uint256 newMinVotingPower,
        uint256 newQuorumPercentage,
        uint256 newMajorityPercentage
    ) external onlyOwner {
        require(newQuorumPercentage <= 10000, "Quorum cannot exceed 100%");
        require(newMajorityPercentage <= 10000, "Majority cannot exceed 100%");
        require(newProposalDuration > 0, "Proposal duration must be positive");
        
        daoSettings.proposalDuration = newProposalDuration;
        daoSettings.minVotingPower = newMinVotingPower;
        daoSettings.quorumPercentage = newQuorumPercentage;
        daoSettings.majorityPercentage = newMajorityPercentage;
        
        emit DAOSettingsUpdated();
    }
    
    /**
     * @dev Get the current state of a proposal
     * @param proposalId ID of the proposal
     * @return Current state of the proposal
     */
    function getProposalState(uint256 proposalId) public view returns (ProposalState) {
        require(proposalId < proposalCount, "Proposal does not exist");
        
        Proposal storage proposal = proposals[proposalId];
        
        if (proposal.cancelled) {
            return ProposalState.CANCELLED;
        }
        
        if (proposal.executed) {
            return ProposalState.EXECUTED;
        }
        
        if (block.timestamp <= proposal.endTime) {
            return ProposalState.ACTIVE;
        }
        
        // Check if proposal passed
        uint256 totalVotes = proposal.votesFor + proposal.votesAgainst + proposal.votesAbstain;
        uint256 quorumRequired = (totalVotingPower * daoSettings.quorumPercentage) / 10000;
        
        if (totalVotes < quorumRequired) {
            return ProposalState.DEFEATED;
        }
        
        uint256 majorityRequired = (totalVotes * daoSettings.majorityPercentage) / 10000;
        
        if (proposal.votesFor >= majorityRequired) {
            return ProposalState.SUCCEEDED;
        } else {
            return ProposalState.DEFEATED;
        }
    }
    
    /**
     * @dev Get voting power of an address
     * @param account Address to check
     * @return Voting power of the address
     */
    function getVotingPower(address account) public view returns (uint256) {
        if (daoSettings.membershipType == MembershipType.TOKEN_BASED && address(governanceToken) != address(0)) {
            return governanceToken.balanceOf(account);
        } else {
            return members[account].votingPower;
        }
    }
    
    /**
     * @dev Get proposal details
     * @param proposalId ID of the proposal
     * @return Proposal details
     */
    function getProposal(uint256 proposalId) external view returns (
        uint256 id,
        address proposer,
        string memory title,
        string memory description,
        ProposalType proposalType,
        address target,
        uint256 amount,
        uint256 startTime,
        uint256 endTime,
        uint256 votesFor,
        uint256 votesAgainst,
        uint256 votesAbstain,
        bool executed,
        bool cancelled
    ) {
        require(proposalId < proposalCount, "Proposal does not exist");
        
        Proposal storage proposal = proposals[proposalId];
        
        return (
            proposal.id,
            proposal.proposer,
            proposal.title,
            proposal.description,
            proposal.proposalType,
            proposal.target,
            proposal.amount,
            proposal.startTime,
            proposal.endTime,
            proposal.votesFor,
            proposal.votesAgainst,
            proposal.votesAbstain,
            proposal.executed,
            proposal.cancelled
        );
    }
    
    /**
     * @dev Get treasury balance
     * @return Current ETH balance of the treasury
     */
    function getTreasuryBalance() external view returns (uint256) {
        return address(this).balance;
    }
    
    /**
     * @dev Check if an address has voted on a proposal
     * @param proposalId ID of the proposal
     * @param voter Address to check
     * @return Whether the address has voted
     */
    function hasVoted(uint256 proposalId, address voter) external view returns (bool) {
        return proposals[proposalId].hasVoted[voter];
    }
    
    /**
     * @dev Get vote choice of an address for a proposal
     * @param proposalId ID of the proposal
     * @param voter Address to check
     * @return Vote choice (0=against, 1=for, 2=abstain)
     */
    function getVoteChoice(uint256 proposalId, address voter) external view returns (uint256) {
        return proposals[proposalId].voteChoice[voter];
    }
    
    /**
     * @dev Internal function to add a member
     * @param member Address of the new member
     * @param votingPower Voting power to assign
     */
    function _addMember(address member, uint256 votingPower) internal {
        require(member != address(0), "Invalid member address");
        require(!isMember[member], "Already a member");
        
        isMember[member] = true;
        members[member] = Member({
            isActive: true,
            joinedAt: block.timestamp,
            votingPower: votingPower,
            proposalsCreated: 0,
            votesParticipated: 0
        });
        
        memberCount++;
        totalVotingPower += votingPower;
        
        emit MemberAdded(member, votingPower);
    }
    
    /**
     * @dev Internal function to remove a member
     * @param member Address of the member to remove
     */
    function _removeMember(address member) internal {
        require(isMember[member], "Not a member");
        
        uint256 memberVotingPower = members[member].votingPower;
        
        isMember[member] = false;
        members[member].isActive = false;
        members[member].votingPower = 0;
        
        memberCount--;
        totalVotingPower -= memberVotingPower;
        
        emit MemberRemoved(member);
    }
    
    /**
     * @dev Internal function to execute treasury transfer
     * @param to Address to transfer to
     * @param amount Amount to transfer
     * @return Whether the transfer was successful
     */
    function _executeTreasuryTransfer(address to, uint256 amount) internal returns (bool) {
        require(to != address(0), "Invalid recipient");
        require(amount <= address(this).balance, "Insufficient balance");
        
        (bool success, ) = payable(to).call{value: amount}("");
        
        if (success) {
            emit TreasuryWithdrawal(to, amount);
        }
        
        return success;
    }
}
