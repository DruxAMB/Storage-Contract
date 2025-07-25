// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IERC20
 * @dev Interface for ERC20 token standard
 * @notice Shared interface for CELO stable coins (cUSD, cEUR, cREAL)
 */
interface IERC20 {
    /**
     * @dev Transfers tokens to a specified address
     * @param to The address to transfer to
     * @param amount The amount to transfer
     * @return success Whether the transfer was successful
     */
    function transfer(address to, uint256 amount) external returns (bool success);
    
    /**
     * @dev Transfers tokens from one address to another
     * @param from The address to transfer from
     * @param to The address to transfer to
     * @param amount The amount to transfer
     * @return success Whether the transfer was successful
     */
    function transferFrom(address from, address to, uint256 amount) external returns (bool success);
    
    /**
     * @dev Returns the balance of a specified address
     * @param account The address to query the balance of
     * @return balance The balance of the specified address
     */
    function balanceOf(address account) external view returns (uint256 balance);
}
