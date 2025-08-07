// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v4.8.0/contracts/access/Ownable.sol";

/**
 * @title AddressAllowlist
 * @dev A simple, ownable contract to manage an address allowlist.
 * @notice The owner can add or remove addresses. Other contracts can query this list.
 */
contract AddressAllowlist is Ownable {

    // Mapping from an address to its allowlist status
    mapping(address => bool) public isAllowlisted;

    // Events
    event AddressAdded(address indexed user);
    event AddressRemoved(address indexed user);

    /**
     * @dev Constructor.
     */
    constructor() Ownable() {}

    /**
     * @notice Adds a single address to the allowlist.
     * @param _user The address to add.
     */
    function add(address _user) external onlyOwner {
        require(_user != address(0), "Cannot add zero address");
        require(!isAllowlisted[_user], "User already on allowlist");
        isAllowlisted[_user] = true;
        emit AddressAdded(_user);
    }

    /**
     * @notice Removes a single address from the allowlist.
     * @param _user The address to remove.
     */
    function remove(address _user) external onlyOwner {
        require(isAllowlisted[_user], "User not on allowlist");
        isAllowlisted[_user] = false;
        emit AddressRemoved(_user);
    }

    /**
     * @notice Adds multiple addresses to the allowlist in a batch.
     * @param _users The array of addresses to add.
     */
    function addBatch(address[] memory _users) external onlyOwner {
        for (uint i = 0; i < _users.length; i++) {
            address _user = _users[i];
            if (_user != address(0) && !isAllowlisted[_user]) {
                isAllowlisted[_user] = true;
                emit AddressAdded(_user);
            }
        }
    }

    /**
     * @notice Removes multiple addresses from the allowlist in a batch.
     * @param _users The array of addresses to remove.
     */
    function removeBatch(address[] memory _users) external onlyOwner {
        for (uint i = 0; i < _users.length; i++) {
            address _user = _users[i];
            if (isAllowlisted[_user]) {
                isAllowlisted[_user] = false;
                emit AddressRemoved(_user);
            }
        }
    }
}
