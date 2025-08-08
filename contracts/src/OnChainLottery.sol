// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v4.8.0/contracts/access/Ownable.sol";
import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v4.8.0/contracts/security/ReentrancyGuard.sol";

/**
 * @title OnChainLottery
 * @dev A simple on-chain lottery contract.
 * @notice Users can buy tickets to enter. The owner picks a winner who receives the prize pool.
 */
contract OnChainLottery is Ownable, ReentrancyGuard {

    uint256 public ticketPrice = 0.01 ether;
    address[] public players;
    address public lastWinner;

    // Events
    event TicketPurchased(address indexed player);
    event WinnerPicked(address indexed winner, uint256 prizeAmount);
    event PriceUpdated(uint256 newPrice);

    /**
     * @dev Constructor.
     */
    constructor() Ownable() {}

    /**
     * @notice Buys a ticket to enter the lottery.
     */
    function enter() external payable {
        require(msg.value == ticketPrice, "Incorrect ticket price");
        players.push(msg.sender);
        emit TicketPurchased(msg.sender);
    }

    /**
     * @notice Picks a random winner from the list of players.
     * @dev This is a pseudo-random number generation method and is not secure for high-value lotteries.
     *      For production use, a Chainlink VRF should be used.
     *      Only the owner can call this function.
     */
    function pickWinner() external onlyOwner nonReentrant {
        require(players.length > 0, "No players in the lottery");

        uint256 randomIndex = uint256(keccak256(abi.encodePacked(
            block.timestamp,
            block.prevrandao, // Note: prevrandao is the new name for block.difficulty
            players
        ))) % players.length;

        address winner = players[randomIndex];
        lastWinner = winner;

        uint256 prizeAmount = address(this).balance;

        // Reset for the next lottery round before transferring funds
        players = new address[](0);

        payable(winner).transfer(prizeAmount);

        emit WinnerPicked(winner, prizeAmount);
    }

    /**
     * @notice Gets the list of all players currently in the lottery.
     * @return An array of player addresses.
     */
    function getPlayers() external view returns (address[] memory) {
        return players;
    }

    /**
     * @notice Updates the ticket price (owner only).
     * @param _newPrice The new price in wei.
     */
    function setTicketPrice(uint256 _newPrice) external onlyOwner {
        ticketPrice = _newPrice;
        emit PriceUpdated(_newPrice);
    }
}
