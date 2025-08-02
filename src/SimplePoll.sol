// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v4.8.0/contracts/access/Ownable.sol";
import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v4.8.0/contracts/security/ReentrancyGuard.sol";

/**
 * @title SimplePoll
 * @dev A basic on-chain voting/polling system.
 * @notice Allows users to create polls, cast votes, and view results.
 */
contract SimplePoll is Ownable, ReentrancyGuard {

    // Struct to hold poll information
    struct Poll {
        string question;
        string[] options;
        mapping(uint256 => uint256) votesPerOption;
        mapping(address => bool) voters;
        uint256 totalVotes;
        uint256 deadline;
        address creator;
        bool exists;
    }

    // State variables
    uint256 public pollCount;
    mapping(uint256 => Poll) public polls;

    // Events
    event PollCreated(
        uint256 indexed pollId,
        address indexed creator,
        string question,
        uint256 deadline
    );

    event Voted(
        uint256 indexed pollId,
        address indexed voter,
        uint256 indexed optionId
    );

    /**
     * @dev Constructor.
     */
    constructor() Ownable() {}

    /**
     * @notice Creates a new poll.
     * @param _question The question for the poll.
     * @param _options The list of options for the poll.
     * @param _durationSeconds The duration of the poll in seconds.
     * @return The ID of the newly created poll.
     */
    function createPoll(
        string memory _question,
        string[] memory _options,
        uint256 _durationSeconds
    ) external returns (uint256) {
        require(bytes(_question).length > 0, "Question cannot be empty");
        require(_options.length >= 2, "Must have at least two options");
        require(_durationSeconds > 0, "Duration must be positive");

        uint256 pollId = pollCount;
        Poll storage newPoll = polls[pollId];

        newPoll.question = _question;
        newPoll.deadline = block.timestamp + _durationSeconds;
        newPoll.creator = msg.sender;
        newPoll.exists = true;

        for (uint i = 0; i < _options.length; i++) {
            newPoll.options.push(_options[i]);
        }

        pollCount++;

        emit PollCreated(pollId, msg.sender, _question, newPoll.deadline);

        return pollId;
    }

    /**
     * @notice Casts a vote on a specific poll.
     * @param _pollId The ID of the poll to vote on.
     * @param _optionId The index of the option to vote for.
     */
    function vote(uint256 _pollId, uint256 _optionId) external nonReentrant {
        require(_pollId < pollCount, "Poll does not exist");
        Poll storage selectedPoll = polls[_pollId];

        require(selectedPoll.exists, "Poll does not exist");
        require(block.timestamp < selectedPoll.deadline, "Poll has ended");
        require(!selectedPoll.voters[msg.sender], "Already voted");
        require(_optionId < selectedPoll.options.length, "Invalid option");

        selectedPoll.voters[msg.sender] = true;
        selectedPoll.votesPerOption[_optionId]++;
        selectedPoll.totalVotes++;

        emit Voted(_pollId, msg.sender, _optionId);
    }

    /**
     * @notice Gets the details of a poll.
     * @param _pollId The ID of the poll.
     * @return question The poll's question.
     * @return options The poll's options.
     * @return deadline The poll's voting deadline.
     * @return creator The address of the poll's creator.
     */
    function getPollDetails(uint256 _pollId) 
        external 
        view 
        returns (
            string memory question,
            string[] memory options,
            uint256 deadline,
            address creator
        )
    {
        require(_pollId < pollCount && polls[_pollId].exists, "Poll does not exist");
        Poll storage selectedPoll = polls[_pollId];
        return (
            selectedPoll.question,
            selectedPoll.options,
            selectedPoll.deadline,
            selectedPoll.creator
        );
    }

    /**
     * @notice Gets the results of a poll.
     * @param _pollId The ID of the poll.
     * @return results An array of vote counts for each option.
     * @return totalVotes_ The total number of votes cast.
     */
    function getPollResults(uint256 _pollId) 
        external 
        view 
        returns (uint256[] memory results, uint256 totalVotes_)
    {
        require(_pollId < pollCount && polls[_pollId].exists, "Poll does not exist");
        Poll storage selectedPoll = polls[_pollId];

        uint256 optionCount = selectedPoll.options.length;
        results = new uint256[](optionCount);

        for (uint i = 0; i < optionCount; i++) {
            results[i] = selectedPoll.votesPerOption[i];
        }

        return (results, selectedPoll.totalVotes);
    }

    /**
     * @notice Checks if an address has voted on a specific poll.
     * @param _pollId The ID of the poll.
     * @param _voter The address to check.
     * @return True if the address has voted, false otherwise.
     */
    function hasVoted(uint256 _pollId, address _voter) external view returns (bool) {
        require(_pollId < pollCount && polls[_pollId].exists, "Poll does not exist");
        return polls[_pollId].voters[_voter];
    }

    /**
     * @notice Checks if a poll is currently active.
     * @param _pollId The ID of the poll.
     * @return True if the poll is active, false otherwise.
     */
    function isPollActive(uint256 _pollId) external view returns (bool) {
        require(_pollId < pollCount && polls[_pollId].exists, "Poll does not exist");
        return block.timestamp < polls[_pollId].deadline;
    }
}
