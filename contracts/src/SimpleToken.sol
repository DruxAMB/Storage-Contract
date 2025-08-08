// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v4.8.0/contracts/token/ERC20/ERC20.sol";
import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v4.8.0/contracts/access/Ownable.sol";

/**
 * @title SimpleToken
 * @dev A basic ERC20 token with a fixed supply.
 * @notice The total supply is minted to the contract creator upon deployment.
 */
contract SimpleToken is ERC20, Ownable {

    /**
     * @notice Constructor to create the token.
     * @param _name The name of the token.
     * @param _symbol The symbol of the token.
     * @param _initialSupply The total amount of tokens to mint, including decimals.
     */
    constructor(string memory _name, string memory _symbol, uint256 _initialSupply) ERC20(_name, _symbol) Ownable() {
        // The _initialSupply should be provided with decimals in mind.
        // For a token with 18 decimals, to mint 1,000,000 tokens, _initialSupply should be 1000000 * (10**18).
        _mint(msg.sender, _initialSupply);
    }
}
