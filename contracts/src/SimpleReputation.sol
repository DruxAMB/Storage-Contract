// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title SimpleReputation
 * @dev A contract for a basic on-chain reputation system.
 * @notice Users can give a single +1 or -1 rating to any other address.
 */
contract SimpleReputation {

    // Mapping from a user's address to their reputation score
    mapping(address => int256) public reputations;

    // Mapping to track who has rated whom
    // mapping(rater => mapping(rated => bool))
    mapping(address => mapping(address => bool)) public hasRated;

    // Event to log when a user is rated
    event UserRated(address indexed rater, address indexed rated, int256 newReputation);

    /**
     * @notice Rates another user, either positively or negatively.
     * @dev A user cannot rate themselves, and can only rate another user once.
     * @param _user The address of the user to rate.
     * @param _isPositive True for a +1 rating, false for a -1 rating.
     */
    function rateUser(address _user, bool _isPositive) external {
        require(_user != msg.sender, "You cannot rate yourself");
        require(!hasRated[msg.sender][_user], "You have already rated this user");

        if (_isPositive) {
            reputations[_user]++;
        } else {
            reputations[_user]--;
        }

        hasRated[msg.sender][_user] = true;

        emit UserRated(msg.sender, _user, reputations[_user]);
    }

    /**
     * @notice Gets the reputation score for a given user.
     * @param _user The address of the user.
     * @return The user's current reputation score.
     */
    function getReputation(address _user) external view returns (int256) {
        return reputations[_user];
    }
}
