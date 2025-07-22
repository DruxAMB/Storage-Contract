// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title DecentralizedVoting
 * @dev A transparent voting system for proposals with time-based logic and governance features
 * @notice Create proposals, vote on them, and execute results in a decentralized manner
 */
contract DecentralizedVoting {
    // Structs
    struct Proposal {
        uint256 id;
        string title;
        string description;
        address proposer;
        uint256 yesVotes;
        uint256 noVotes;
        uint256 startTime;
        uint256 endTime;
        bool executed;
        bool passed;
        mapping(address => bool) hasVoted;
        mapping(address => bool) voteChoice; // true = yes, false = no
    }
    
    // State variables
    mapping(uint256 => Proposal) public proposals;
    mapping(address => bool) public isEligibleVoter;
    mapping(address => uint256) public voterRegistrationTime;
    
    address public admin;
    uint256 public proposalCount;
    uint256 public votingDuration; // in seconds
    uint256 public minimumQuorum; // minimum votes needed
    uint256 public totalEligibleVoters;
    bool public registrationOpen;
    
    address[] public eligibleVoters;
    uint256[] public activeProposals;
    
    // Events
    event ProposalCreated(
        uint256 indexed proposalId,
        string title,
        address indexed proposer,
        uint256 startTime,
        uint256 endTime
    );
    event VoteCast(
        uint256 indexed proposalId,
        address indexed voter,
        bool choice,
        uint256 timestamp
    );
    event ProposalExecuted(
        uint256 indexed proposalId,
        bool passed,
        uint256 yesVotes,
        uint256 noVotes
    );
    event VoterRegistered(address indexed voter, uint256 timestamp);
    event VoterRemoved(address indexed voter, uint256 timestamp);
    event VotingParametersUpdated(uint256 duration, uint256 quorum);
    
    // Modifiers
    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can call this function");
        _;
    }
    
    modifier onlyEligibleVoter() {
        require(isEligibleVoter[msg.sender], "Not an eligible voter");
        _;
    }
    
    modifier proposalExists(uint256 proposalId) {
        require(proposalId > 0 && proposalId <= proposalCount, "Proposal does not exist");
        _;
    }
    
    modifier votingActive(uint256 proposalId) {
        require(block.timestamp >= proposals[proposalId].startTime, "Voting not started");
        require(block.timestamp <= proposals[proposalId].endTime, "Voting period ended");
        require(!proposals[proposalId].executed, "Proposal already executed");
        _;
    }
    
    modifier votingEnded(uint256 proposalId) {
        require(block.timestamp > proposals[proposalId].endTime, "Voting still active");
        _;
    }
    
    // Constructor
    constructor(uint256 _votingDuration, uint256 _minimumQuorum) {
        admin = msg.sender;
        votingDuration = _votingDuration; // e.g., 7 days = 604800 seconds
        minimumQuorum = _minimumQuorum; // e.g., 10 minimum votes
        registrationOpen = true;
        proposalCount = 0;
        totalEligibleVoters = 0;
        
        // Admin is automatically eligible voter
        isEligibleVoter[admin] = true;
        voterRegistrationTime[admin] = block.timestamp;
        eligibleVoters.push(admin);
        totalEligibleVoters = 1;
    }
    
    /**
     * @dev Register as an eligible voter
     */
    function registerToVote() external {
        require(registrationOpen, "Voter registration is closed");
        require(!isEligibleVoter[msg.sender], "Already registered as voter");
        
        isEligibleVoter[msg.sender] = true;
        voterRegistrationTime[msg.sender] = block.timestamp;
        eligibleVoters.push(msg.sender);
        totalEligibleVoters++;
        
        emit VoterRegistered(msg.sender, block.timestamp);
    }
    
    /**
     * @dev Create a new proposal
     * @param title Proposal title
     * @param description Detailed description
     */
    function createProposal(
        string memory title,
        string memory description
    ) external onlyEligibleVoter returns (uint256) {
        require(bytes(title).length > 0, "Title cannot be empty");
        require(bytes(description).length > 0, "Description cannot be empty");
        
        proposalCount++;
        uint256 proposalId = proposalCount;
        
        Proposal storage newProposal = proposals[proposalId];
        newProposal.id = proposalId;
        newProposal.title = title;
        newProposal.description = description;
        newProposal.proposer = msg.sender;
        newProposal.startTime = block.timestamp;
        newProposal.endTime = block.timestamp + votingDuration;
        newProposal.executed = false;
        newProposal.passed = false;
        newProposal.yesVotes = 0;
        newProposal.noVotes = 0;
        
        activeProposals.push(proposalId);
        
        emit ProposalCreated(
            proposalId,
            title,
            msg.sender,
            newProposal.startTime,
            newProposal.endTime
        );
        
        return proposalId;
    }
    
    /**
     * @dev Vote on a proposal
     * @param proposalId ID of the proposal
     * @param choice true for yes, false for no
     */
    function vote(uint256 proposalId, bool choice) 
        external 
        onlyEligibleVoter 
        proposalExists(proposalId) 
        votingActive(proposalId) 
    {
        Proposal storage proposal = proposals[proposalId];
        require(!proposal.hasVoted[msg.sender], "Already voted on this proposal");
        
        proposal.hasVoted[msg.sender] = true;
        proposal.voteChoice[msg.sender] = choice;
        
        if (choice) {
            proposal.yesVotes++;
        } else {
            proposal.noVotes++;
        }
        
        emit VoteCast(proposalId, msg.sender, choice, block.timestamp);
    }
    
    /**
     * @dev Execute a proposal after voting period ends
     * @param proposalId ID of the proposal to execute
     */
    function executeProposal(uint256 proposalId) 
        external 
        proposalExists(proposalId) 
        votingEnded(proposalId) 
    {
        Proposal storage proposal = proposals[proposalId];
        require(!proposal.executed, "Proposal already executed");
        
        uint256 totalVotes = proposal.yesVotes + proposal.noVotes;
        require(totalVotes >= minimumQuorum, "Minimum quorum not reached");
        
        proposal.executed = true;
        proposal.passed = proposal.yesVotes > proposal.noVotes;
        
        // Remove from active proposals
        _removeFromActiveProposals(proposalId);
        
        emit ProposalExecuted(
            proposalId,
            proposal.passed,
            proposal.yesVotes,
            proposal.noVotes
        );
    }
    
    /**
     * @dev Get proposal details
     * @param proposalId ID of the proposal
     * @return Proposal information
     */
    function getProposal(uint256 proposalId) 
        external 
        view 
        proposalExists(proposalId) 
        returns (
            uint256 id,
            string memory title,
            string memory description,
            address proposer,
            uint256 yesVotes,
            uint256 noVotes,
            uint256 startTime,
            uint256 endTime,
            bool executed,
            bool passed
        ) 
    {
        Proposal storage proposal = proposals[proposalId];
        return (
            proposal.id,
            proposal.title,
            proposal.description,
            proposal.proposer,
            proposal.yesVotes,
            proposal.noVotes,
            proposal.startTime,
            proposal.endTime,
            proposal.executed,
            proposal.passed
        );
    }
    
    /**
     * @dev Check if an address has voted on a proposal
     * @param proposalId ID of the proposal
     * @param voter Address to check
     * @return hasVoted Whether the address has voted
     * @return choice Their vote choice (if voted)
     */
    function getVoteStatus(uint256 proposalId, address voter) 
        external 
        view 
        proposalExists(proposalId) 
        returns (bool hasVoted, bool choice) 
    {
        Proposal storage proposal = proposals[proposalId];
        hasVoted = proposal.hasVoted[voter];
        choice = proposal.voteChoice[voter];
    }
    
    /**
     * @dev Get voting results for a proposal
     * @param proposalId ID of the proposal
     * @return yesVotes Number of yes votes
     * @return noVotes Number of no votes
     * @return totalVotes Total votes cast
     * @return quorumReached Whether minimum quorum was reached
     */
    function getVotingResults(uint256 proposalId) 
        external 
        view 
        proposalExists(proposalId) 
        returns (
            uint256 yesVotes,
            uint256 noVotes,
            uint256 totalVotes,
            bool quorumReached
        ) 
    {
        Proposal storage proposal = proposals[proposalId];
        yesVotes = proposal.yesVotes;
        noVotes = proposal.noVotes;
        totalVotes = yesVotes + noVotes;
        quorumReached = totalVotes >= minimumQuorum;
    }
    
    /**
     * @dev Get all active proposals
     * @return Array of active proposal IDs
     */
    function getActiveProposals() external view returns (uint256[] memory) {
        return activeProposals;
    }
    
    /**
     * @dev Get all eligible voters
     * @return Array of eligible voter addresses
     */
    function getEligibleVoters() external view returns (address[] memory) {
        return eligibleVoters;
    }
    
    /**
     * @dev Get voting system statistics
     * @return totalProposals Total number of proposals created
     * @return activeCount Number of active proposals
     * @return voterCount Total eligible voters
     * @return currentQuorum Current minimum quorum requirement
     * @return duration Voting duration in seconds
     */
    function getVotingStats() external view returns (
        uint256 totalProposals,
        uint256 activeCount,
        uint256 voterCount,
        uint256 currentQuorum,
        uint256 duration
    ) {
        return (
            proposalCount,
            activeProposals.length,
            totalEligibleVoters,
            minimumQuorum,
            votingDuration
        );
    }
    
    /**
     * @dev Check if a proposal is currently active for voting
     * @param proposalId ID of the proposal
     * @return Whether the proposal is active
     */
    function isProposalActive(uint256 proposalId) 
        external 
        view 
        proposalExists(proposalId) 
        returns (bool) 
    {
        Proposal storage proposal = proposals[proposalId];
        return (
            block.timestamp >= proposal.startTime &&
            block.timestamp <= proposal.endTime &&
            !proposal.executed
        );
    }
    
    /**
     * @dev Update voting parameters (admin only)
     * @param newDuration New voting duration in seconds
     * @param newQuorum New minimum quorum
     */
    function updateVotingParameters(uint256 newDuration, uint256 newQuorum) 
        external 
        onlyAdmin 
    {
        require(newDuration > 0, "Duration must be greater than 0");
        require(newQuorum > 0, "Quorum must be greater than 0");
        
        votingDuration = newDuration;
        minimumQuorum = newQuorum;
        
        emit VotingParametersUpdated(newDuration, newQuorum);
    }
    
    /**
     * @dev Toggle voter registration (admin only)
     */
    function toggleRegistration() external onlyAdmin {
        registrationOpen = !registrationOpen;
    }
    
    /**
     * @dev Remove a voter (admin only)
     * @param voter Address to remove
     */
    function removeVoter(address voter) external onlyAdmin {
        require(isEligibleVoter[voter], "Address is not a voter");
        require(voter != admin, "Cannot remove admin");
        
        isEligibleVoter[voter] = false;
        totalEligibleVoters--;
        
        // Remove from eligibleVoters array
        for (uint256 i = 0; i < eligibleVoters.length; i++) {
            if (eligibleVoters[i] == voter) {
                eligibleVoters[i] = eligibleVoters[eligibleVoters.length - 1];
                eligibleVoters.pop();
                break;
            }
        }
        
        emit VoterRemoved(voter, block.timestamp);
    }
    
    /**
     * @dev Get proposals by status
     * @param executed Whether to get executed or non-executed proposals
     * @return Array of proposal IDs
     */
    function getProposalsByStatus(bool executed) external view returns (uint256[] memory) {
        uint256 count = 0;
        
        // Count matching proposals
        for (uint256 i = 1; i <= proposalCount; i++) {
            if (proposals[i].executed == executed) {
                count++;
            }
        }
        
        // Fill array
        uint256[] memory result = new uint256[](count);
        uint256 index = 0;
        
        for (uint256 i = 1; i <= proposalCount && index < count; i++) {
            if (proposals[i].executed == executed) {
                result[index] = i;
                index++;
            }
        }
        
        return result;
    }
    
    // Internal functions
    function _removeFromActiveProposals(uint256 proposalId) internal {
        for (uint256 i = 0; i < activeProposals.length; i++) {
            if (activeProposals[i] == proposalId) {
                activeProposals[i] = activeProposals[activeProposals.length - 1];
                activeProposals.pop();
                break;
            }
        }
    }
}
