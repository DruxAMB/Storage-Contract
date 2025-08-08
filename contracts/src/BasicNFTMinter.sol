// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v4.8.0/contracts/token/ERC721/ERC721.sol";
import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v4.8.0/contracts/access/Ownable.sol";
import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v4.8.0/contracts/utils/Counters.sol";

/**
 * @title BasicNFTMinter
 * @dev A simple contract for minting NFTs for a fee.
 * @notice Users can pay a fee to mint a new, unique NFT.
 */
contract BasicNFTMinter is ERC721, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    uint256 public mintFee = 0.01 ether;

    // Event
    event FeeUpdated(uint256 newFee);

    /**
     * @notice Constructor to create the NFT collection.
     * @param _name The name of the NFT collection.
     * @param _symbol The symbol for the NFT collection.
     */
    constructor(string memory _name, string memory _symbol) ERC721(_name, _symbol) Ownable() {}

    /**
     * @notice Mints a new NFT to the sender's address.
     * @dev Requires the specified minting fee to be paid.
     */
    function mint() external payable {
        require(msg.value == mintFee, "Incorrect mint fee");

        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();
        _safeMint(msg.sender, newItemId);
    }

    /**
     * @notice Allows the owner to withdraw collected fees.
     */
    function withdrawFees() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No fees to withdraw");
        payable(owner()).transfer(balance);
    }

    /**
     * @notice Updates the minting fee (owner only).
     * @param _newFee The new fee in wei.
     */
    function setMintFee(uint256 _newFee) external onlyOwner {
        mintFee = _newFee;
        emit FeeUpdated(_newFee);
    }
}
