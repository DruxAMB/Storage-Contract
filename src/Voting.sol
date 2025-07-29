// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title SimpleVoting
 * @dev A simple voting contract for creating polls and collecting votes
 * @notice Allows users to create polls and vote on them with basic analytics
 */
contract SimpleVoting {
    
    // Structs
    struct Poll {
        uint256 id;
        string question;
        string[] options;
        mapping(uint256 => uint256) votes; // optionIndex => voteCount
        mapping(address => bool) hasVoted;
        address creator;
        uint256 createdAt;
        uint256 totalVotes;
        bool isActive;
    }
    
    // State variables
    mapping(uint256 => Poll) public polls;
    mapping(address => uint256[]) public userPolls;
    uint256 public pollCount;
    
    // Events
    event PollCreated(
        uint256 indexed pollId,
        address indexed creator,
        string question,
        uint256 timestamp
    );
    
    event VoteCast(
        uint256 indexed pollId,
        address indexed voter,
        uint256 optionIndex,
        uint256 timestamp
    );
    
    event PollClosed(
        uint256 indexed pollId,
        address indexed creator,
        uint256 timestamp
    );
    
    /**
     * @dev Create a new poll with multiple options
     * @param question The poll question
     * @param options Array of voting options
     * @return pollId The ID of the created poll
     */
    function createPoll(
        string memory question,
        string[] memory options
    ) external returns (uint256 pollId) {
        require(bytes(question).length > 0, "Question cannot be empty");
        require(options.length >= 2, "Must have at least 2 options");
        require(options.length <= 10, "Maximum 10 options allowed");
        
        pollId = pollCount++;
        Poll storage newPoll = polls[pollId];
        
        newPoll.id = pollId;
        newPoll.question = question;
        newPoll.creator = msg.sender;
        newPoll.createdAt = block.timestamp;
        newPoll.totalVotes = 0;
        newPoll.isActive = true;
        
        // Store options
        for (uint256 i = 0; i < options.length; i++) {
            require(bytes(options[i]).length > 0, "Option cannot be empty");
            newPoll.options.push(options[i]);
        }
        
        userPolls[msg.sender].push(pollId);
        
        emit PollCreated(pollId, msg.sender, question, block.timestamp);
    }
    
    /**
     * @dev Cast a vote on a poll
     * @param pollId The poll ID to vote on
     * @param optionIndex The index of the chosen option
     */
    function vote(uint256 pollId, uint256 optionIndex) external {
        require(pollId < pollCount, "Poll does not exist");
        
        Poll storage poll = polls[pollId];
        require(poll.isActive, "Poll is not active");
        require(!poll.hasVoted[msg.sender], "Already voted on this poll");
        require(optionIndex < poll.options.length, "Invalid option index");
        
        poll.hasVoted[msg.sender] = true;
        poll.votes[optionIndex]++;
        poll.totalVotes++;
        
        emit VoteCast(pollId, msg.sender, optionIndex, block.timestamp);
    }
    
    /**
     * @dev Close a poll (only creator can close)
     * @param pollId The poll ID to close
     */
    function closePoll(uint256 pollId) external {
        require(pollId < pollCount, "Poll does not exist");
        
        Poll storage poll = polls[pollId];
        require(msg.sender == poll.creator, "Only creator can close poll");
        require(poll.isActive, "Poll already closed");
        
        poll.isActive = false;
        
        emit PollClosed(pollId, msg.sender, block.timestamp);
    }
    
    /**
     * @dev Get poll information
     * @param pollId The poll ID
     * @return question Poll question
     * @return options Array of voting options
     * @return creator Poll creator address
     * @return createdAt Creation timestamp
     * @return totalVotes Total number of votes
     * @return isActive Whether poll is active
     */
    function getPoll(uint256 pollId) external view returns (
        string memory question,
        string[] memory options,
        address creator,
        uint256 createdAt,
        uint256 totalVotes,
        bool isActive
    ) {
        require(pollId < pollCount, "Poll does not exist");
        
        Poll storage poll = polls[pollId];
        return (
            poll.question,
            poll.options,
            poll.creator,
            poll.createdAt,
            poll.totalVotes,
            poll.isActive
        );
    }
    
    /**
     * @dev Get vote count for a specific option
     * @param pollId The poll ID
     * @param optionIndex The option index
     * @return voteCount Number of votes for this option
     */
    function getVoteCount(uint256 pollId, uint256 optionIndex) external view returns (uint256 voteCount) {
        require(pollId < pollCount, "Poll does not exist");
        require(optionIndex < polls[pollId].options.length, "Invalid option index");
        
        return polls[pollId].votes[optionIndex];
    }
    
    /**
     * @dev Check if user has voted on a poll
     * @param pollId The poll ID
     * @param user The user address
     * @return hasVoted Whether user has voted
     */
    function hasUserVoted(uint256 pollId, address user) external view returns (bool hasVoted) {
        require(pollId < pollCount, "Poll does not exist");
        return polls[pollId].hasVoted[user];
    }
    
    /**
     * @dev Get polls created by a user
     * @param user The user address
     * @return pollIds Array of poll IDs created by user
     */
    function getUserPolls(address user) external view returns (uint256[] memory pollIds) {
        return userPolls[user];
    }
    
    /**
     * @dev Get total number of polls
     * @return count Total poll count
     */
    function getTotalPolls() external view returns (uint256 count) {
        return pollCount;
    }
}
