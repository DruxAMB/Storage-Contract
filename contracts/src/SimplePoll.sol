// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title SimplePoll
 * @dev A contract for creating and participating in simple on-chain polls.
 * @notice Users can create polls, vote on options, and view results.
 */
contract SimplePoll {

    // Struct for a poll
    struct Poll {
        string question;
        string[] options;
        uint256 deadline;
        mapping(uint256 => uint256) voteCounts;
        mapping(address => bool) hasVoted;
        bool exists;
    }

    // State variables
    uint256 public pollCount;
    mapping(uint256 => Poll) public polls;

    // Events
    event PollCreated(uint256 indexed pollId, string question, uint256 deadline);
    event Voted(uint256 indexed pollId, address indexed voter, uint256 optionIndex);

    /**
     * @notice Creates a new poll.
     * @param _question The question for the poll.
     * @param _options An array of options for the poll.
     * @param _durationSeconds The duration for which the poll will be open for voting.
     * @return The ID of the newly created poll.
     */
    function createPoll(string memory _question, string[] memory _options, uint256 _durationSeconds) external returns (uint256) {
        require(bytes(_question).length > 0, "Question cannot be empty");
        require(_options.length >= 2, "Must have at least two options");
        require(_durationSeconds > 0, "Duration must be positive");

        uint256 pollId = pollCount;
        Poll storage newPoll = polls[pollId];
        newPoll.question = _question;
        newPoll.options = _options;
        newPoll.deadline = block.timestamp + _durationSeconds;
        newPoll.exists = true;

        pollCount++;
        emit PollCreated(pollId, _question, newPoll.deadline);
        return pollId;
    }

    /**
     * @notice Casts a vote in a poll.
     * @param _pollId The ID of the poll.
     * @param _optionIndex The index of the chosen option.
     */
    function vote(uint256 _pollId, uint256 _optionIndex) external {
        require(_pollId < pollCount && polls[_pollId].exists, "Poll not found");
        Poll storage p = polls[_pollId];

        require(block.timestamp < p.deadline, "Voting has ended");
        require(!p.hasVoted[msg.sender], "Already voted");
        require(_optionIndex < p.options.length, "Invalid option");

        p.hasVoted[msg.sender] = true;
        p.voteCounts[_optionIndex]++;

        emit Voted(_pollId, msg.sender, _optionIndex);
    }

    /**
     * @notice Gets the details of a poll, including the current vote counts.
     * @param _pollId The ID of the poll.
     * @return The question, options, deadline, and vote counts for the poll.
     */
    function getPoll(uint256 _pollId) 
        external 
        view 
        returns (
            string memory question,
            string[] memory options,
            uint256 deadline,
            uint256[] memory voteCounts
        )
    {
        require(_pollId < pollCount && polls[_pollId].exists, "Poll not found");
        Poll storage p = polls[_pollId];

        options = p.options;
        voteCounts = new uint256[](options.length);
        for (uint i = 0; i < options.length; i++) {
            voteCounts[i] = p.voteCounts[i];
        }

        return (p.question, options, p.deadline, voteCounts);
    }
}
