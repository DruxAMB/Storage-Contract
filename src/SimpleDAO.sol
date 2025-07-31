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
    enum ProposalType { GENERAL, TREASURY_TRANSFER, ADD_MEMBER, REMOVE_MEMBER }
    
    // Proposal struct (simplified to avoid stack issues)
    struct Proposal {
        address proposer;
        string title;
        string description;
        ProposalType proposalType;
        address target;
        uint256 amount;
        uint256 startTime;
        uint256 endTime;
        uint256 votesFor;
        uint256 votesAgainst;
        bool executed;
        bool cancelled;
        mapping(address => bool) hasVoted;
    }
    
    // Member struct
    struct Member {
        bool isActive;
        uint256 votingPower;
        uint256 joinedAt;
    }
    
    // State variables
    uint256 public proposalCount;
    uint256 public memberCount;
    uint256 public totalVotingPower;
    
    // Settings
    uint256 public proposalDuration = 7 days;
    uint256 public minVotingPower = 1;
    uint256 public quorumPercentage = 2500; // 25%
    uint256 public majorityPercentage = 5000; // 50%
    
    // Mappings
    mapping(uint256 => Proposal) public proposals;
    mapping(address => Member) public members;
    mapping(address => bool) public isMember;
    
    // Governance token (optional)
    IERC20 public governanceToken;
    bool public isTokenBased;
    
    // Events
    event ProposalCreated(uint256 indexed proposalId, address indexed proposer, string title);
    event VoteCast(uint256 indexed proposalId, address indexed voter, bool support, uint256 votingPower);
    event ProposalExecuted(uint256 indexed proposalId, bool success);
    event MemberAdded(address indexed member, uint256 votingPower);
    event MemberRemoved(address indexed member);
    event TreasuryDeposit(address indexed from, uint256 amount);
    
    /**
     * @dev Constructor
     * @param _governanceToken Address of governance token (use address(0) for manual membership)
     */
    constructor(address _governanceToken) Ownable() {
        if (_governanceToken != address(0)) {
            governanceToken = IERC20(_governanceToken);
            isTokenBased = true;
        }
        
        // Add deployer as initial member
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
     * @return proposalId ID of the created proposal
     */
    function createProposal(
        string memory title,
        string memory description,
        ProposalType proposalType,
        address target,
        uint256 amount
    ) external returns (uint256 proposalId) {
        require(bytes(title).length > 0, "Title cannot be empty");
        require(getVotingPower(msg.sender) >= minVotingPower, "Insufficient voting power");
        
        if (proposalType == ProposalType.TREASURY_TRANSFER) {
            require(target != address(0), "Target address required");
            require(amount > 0, "Amount must be positive");
            require(amount <= address(this).balance, "Insufficient treasury balance");
        }
        
        proposalId = proposalCount++;
        
        Proposal storage proposal = proposals[proposalId];
        proposal.proposer = msg.sender;
        proposal.title = title;
        proposal.description = description;
        proposal.proposalType = proposalType;
        proposal.target = target;
        proposal.amount = amount;
        proposal.startTime = block.timestamp;
        proposal.endTime = block.timestamp + proposalDuration;
        
        emit ProposalCreated(proposalId, msg.sender, title);
        
        return proposalId;
    }
    
    /**
     * @dev Cast a vote on a proposal
     * @param proposalId ID of the proposal to vote on
     * @param support Whether to vote in favor (true) or against (false)
     */
    function vote(uint256 proposalId, bool support) external nonReentrant {
        require(proposalId < proposalCount, "Proposal does not exist");
        
        Proposal storage proposal = proposals[proposalId];
        require(block.timestamp >= proposal.startTime, "Voting not started");
        require(block.timestamp <= proposal.endTime, "Voting ended");
        require(!proposal.hasVoted[msg.sender], "Already voted");
        require(!proposal.executed, "Proposal already executed");
        require(!proposal.cancelled, "Proposal cancelled");
        
        uint256 voterPower = getVotingPower(msg.sender);
        require(voterPower > 0, "No voting power");
        
        proposal.hasVoted[msg.sender] = true;
        
        if (support) {
            proposal.votesFor += voterPower;
        } else {
            proposal.votesAgainst += voterPower;
        }
        
        emit VoteCast(proposalId, msg.sender, support, voterPower);
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
        
        if (proposal.proposalType == ProposalType.TREASURY_TRANSFER) {
            success = _executeTreasuryTransfer(proposal.target, proposal.amount);
        } else if (proposal.proposalType == ProposalType.ADD_MEMBER) {
            _addMember(proposal.target, proposal.amount);
        } else if (proposal.proposalType == ProposalType.REMOVE_MEMBER) {
            _removeMember(proposal.target);
        }
        
        emit ProposalExecuted(proposalId, success);
    }
    
    /**
     * @dev Get the current state of a proposal
     * @param proposalId ID of the proposal
     * @return Current state of the proposal
     */
    function getProposalState(uint256 proposalId) public view returns (ProposalState) {
        require(proposalId < proposalCount, "Proposal does not exist");
        
        Proposal storage proposal = proposals[proposalId];
        
        if (proposal.cancelled) return ProposalState.CANCELLED;
        if (proposal.executed) return ProposalState.EXECUTED;
        if (block.timestamp <= proposal.endTime) return ProposalState.ACTIVE;
        
        uint256 totalVotes = proposal.votesFor + proposal.votesAgainst;
        uint256 quorumRequired = (totalVotingPower * quorumPercentage) / 10000;
        
        if (totalVotes < quorumRequired) return ProposalState.DEFEATED;
        
        uint256 majorityRequired = (totalVotes * majorityPercentage) / 10000;
        
        return proposal.votesFor >= majorityRequired ? ProposalState.SUCCEEDED : ProposalState.DEFEATED;
    }
    
    /**
     * @dev Get voting power of an address
     * @param account Address to check
     * @return Voting power of the address
     */
    function getVotingPower(address account) public view returns (uint256) {
        if (isTokenBased && address(governanceToken) != address(0)) {
            return governanceToken.balanceOf(account);
        }
        return members[account].votingPower;
    }
    
    /**
     * @dev Add a member manually (owner only, for manual membership type)
     * @param member Address of the new member
     * @param votingPower Voting power to assign
     */
    function addMember(address member, uint256 votingPower) external onlyOwner {
        require(!isTokenBased, "Not manual membership");
        _addMember(member, votingPower);
    }
    
    /**
     * @dev Remove a member manually (owner only, for manual membership type)
     * @param member Address of the member to remove
     */
    function removeMember(address member) external onlyOwner {
        require(!isTokenBased, "Not manual membership");
        _removeMember(member);
    }
    
    /**
     * @dev Update DAO settings (owner only)
     * @param newProposalDuration New proposal duration
     * @param newMinVotingPower New minimum voting power
     * @param newQuorumPercentage New quorum percentage
     * @param newMajorityPercentage New majority percentage
     */
    function updateSettings(
        uint256 newProposalDuration,
        uint256 newMinVotingPower,
        uint256 newQuorumPercentage,
        uint256 newMajorityPercentage
    ) external onlyOwner {
        require(newQuorumPercentage <= 10000, "Quorum cannot exceed 100%");
        require(newMajorityPercentage <= 10000, "Majority cannot exceed 100%");
        
        proposalDuration = newProposalDuration;
        minVotingPower = newMinVotingPower;
        quorumPercentage = newQuorumPercentage;
        majorityPercentage = newMajorityPercentage;
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
     * @dev Get basic proposal info
     * @param proposalId ID of the proposal
     * @return proposer Address of proposer
     * @return title Proposal title
     * @return proposalType Type of proposal
     * @return target Target address
     * @return amount Amount for transfers
     */
    function getProposalInfo(uint256 proposalId) external view returns (
        address proposer,
        string memory title,
        ProposalType proposalType,
        address target,
        uint256 amount
    ) {
        require(proposalId < proposalCount, "Proposal does not exist");
        Proposal storage proposal = proposals[proposalId];
        return (proposal.proposer, proposal.title, proposal.proposalType, proposal.target, proposal.amount);
    }
    
    /**
     * @dev Get proposal voting info
     * @param proposalId ID of the proposal
     * @return startTime Voting start time
     * @return endTime Voting end time
     * @return votesFor Votes in favor
     * @return votesAgainst Votes against
     * @return executed Whether executed
     */
    function getProposalVotes(uint256 proposalId) external view returns (
        uint256 startTime,
        uint256 endTime,
        uint256 votesFor,
        uint256 votesAgainst,
        bool executed
    ) {
        require(proposalId < proposalCount, "Proposal does not exist");
        Proposal storage proposal = proposals[proposalId];
        return (proposal.startTime, proposal.endTime, proposal.votesFor, proposal.votesAgainst, proposal.executed);
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
            votingPower: votingPower,
            joinedAt: block.timestamp
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
        return success;
    }
}
