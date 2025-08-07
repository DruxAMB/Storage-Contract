// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v4.8.0/contracts/access/Ownable.sol";

/**
 * @title CommitRevealVoting
 * @dev A contract for a commit-reveal voting scheme.
 * @notice Prevents front-running by separating voting into a commit and a reveal phase.
 */
contract CommitRevealVoting is Ownable {

    // Enum for poll status
    enum Status { CREATED, COMMIT, REVEAL, ENDED }

    // Struct for a poll
    struct Poll {
        string description;
        uint256 commitDeadline;
        uint256 revealDeadline;
        mapping(uint256 => uint256) voteCounts; // option index => count
        mapping(address => bytes32) commitments;
        mapping(address => bool) hasRevealed;
        uint256 optionCount;
        Status status;
    }

    // State variables
    uint256 public pollCount;
    mapping(uint256 => Poll) public polls;

    // Events
    event PollCreated(uint256 indexed pollId, string description, uint256 commitDeadline, uint256 revealDeadline);
    event Committed(uint256 indexed pollId, address indexed voter, bytes32 commitment);
    event Revealed(uint256 indexed pollId, address indexed voter, uint256 choice);

    /**
     * @notice Creates a new poll.
     * @param _description The description of the poll.
     * @param _optionCount The number of choices available.
     * @param _commitDuration The duration of the commit phase in seconds.
     * @param _revealDuration The duration of the reveal phase in seconds.
     */
    function createPoll(string memory _description, uint256 _optionCount, uint256 _commitDuration, uint256 _revealDuration) external onlyOwner {
        require(_optionCount > 1, "Must have at least two options");
        uint256 pollId = pollCount;
        Poll storage p = polls[pollId];
        p.description = _description;
        p.commitDeadline = block.timestamp + _commitDuration;
        p.revealDeadline = p.commitDeadline + _revealDuration;
        p.optionCount = _optionCount;
        p.status = Status.COMMIT;

        pollCount++;
        emit PollCreated(pollId, _description, p.commitDeadline, p.revealDeadline);
    }

    /**
     * @notice Commits a vote by submitting a hash of the choice and a secret salt.
     * @param _pollId The ID of the poll.
     * @param _commitment The keccak256 hash of abi.encodePacked(choice, salt).
     */
    function commit(uint256 _pollId, bytes32 _commitment) external {
        Poll storage p = polls[_pollId];
        require(p.status == Status.COMMIT, "Commit phase is not active");
        require(block.timestamp < p.commitDeadline, "Commit phase has ended");
        require(p.commitments[msg.sender] == bytes32(0), "Already committed");

        p.commitments[msg.sender] = _commitment;
        emit Committed(_pollId, msg.sender, _commitment);
    }

    /**
     * @notice Reveals the vote after the commit phase has ended.
     * @param _pollId The ID of the poll.
     * @param _choice The option index the user voted for.
     * @param _salt A secret, random value to prevent hash collisions.
     */
    function reveal(uint256 _pollId, uint256 _choice, bytes32 _salt) external {
        Poll storage p = polls[_pollId];
        if (p.status == Status.COMMIT && block.timestamp >= p.commitDeadline) {
            p.status = Status.REVEAL;
        }
        require(p.status == Status.REVEAL, "Reveal phase is not active");
        require(block.timestamp < p.revealDeadline, "Reveal phase has ended");
        require(p.commitments[msg.sender] != bytes32(0), "Did not commit");
        require(!p.hasRevealed[msg.sender], "Already revealed");
        require(_choice < p.optionCount, "Invalid choice");

        bytes32 commitment = keccak256(abi.encodePacked(_choice, _salt));
        require(commitment == p.commitments[msg.sender], "Revealed vote does not match commitment");

        p.hasRevealed[msg.sender] = true;
        p.voteCounts[_choice]++;
        emit Revealed(_pollId, msg.sender, _choice);
    }

    /**
     * @notice Ends the poll after the reveal deadline.
     * @param _pollId The ID of the poll.
     */
    function endPoll(uint256 _pollId) external {
        Poll storage p = polls[_pollId];
        require(p.status == Status.REVEAL, "Poll not in reveal phase");
        require(block.timestamp >= p.revealDeadline, "Reveal phase has not ended");
        p.status = Status.ENDED;
    }

    /**
     * @notice Gets the results for a specific option in a poll.
     * @param _pollId The ID of the poll.
     * @param _option The option index.
     * @return The number of votes for that option.
     */
    function getResult(uint256 _pollId, uint256 _option) external view returns (uint256) {
        require(_option < polls[_pollId].optionCount, "Invalid option");
        return polls[_pollId].voteCounts[_option];
    }
}
