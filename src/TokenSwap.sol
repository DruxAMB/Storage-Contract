// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title TokenSwap
 * @dev Simple peer-to-peer token exchange contract
 * @notice Allows users to create and execute token swap offers between any two ERC-20 tokens
 */
contract TokenSwap is ReentrancyGuard, Ownable {
    // Struct to represent a swap offer
    struct SwapOffer {
        address maker;                  // Address that created the swap offer
        address tokenOffered;           // Address of token being offered
        uint256 amountOffered;          // Amount of tokens being offered
        address tokenRequested;         // Address of token requested in exchange
        uint256 amountRequested;        // Amount of tokens requested in exchange
        uint256 expirationTime;         // Timestamp when the offer expires
        bool isActive;                  // Whether the offer is still active
    }
    
    // Mapping from offer ID to SwapOffer
    mapping(uint256 => SwapOffer) public swapOffers;
    
    // Counter for offer IDs
    uint256 public offerCount;
    
    // Platform fee in basis points (e.g., 25 = 0.25%)
    uint256 public platformFee = 25;
    
    // Events
    event OfferCreated(
        uint256 indexed offerId,
        address indexed maker,
        address tokenOffered,
        uint256 amountOffered,
        address tokenRequested,
        uint256 amountRequested,
        uint256 expirationTime
    );
    
    event OfferCancelled(
        uint256 indexed offerId,
        address indexed maker
    );
    
    event SwapExecuted(
        uint256 indexed offerId,
        address indexed maker,
        address indexed taker,
        address tokenOffered,
        uint256 amountOffered,
        address tokenRequested,
        uint256 amountRequested
    );
    
    event PlatformFeeUpdated(
        uint256 oldFee,
        uint256 newFee
    );
    
    /**
     * @dev Constructor
     */
    constructor() Ownable(msg.sender) {}
    
    /**
     * @dev Create a new swap offer
     * @param tokenOffered Address of token being offered
     * @param amountOffered Amount of tokens being offered
     * @param tokenRequested Address of token requested in exchange
     * @param amountRequested Amount of tokens requested in exchange
     * @param expirationTime Timestamp when the offer expires (0 for no expiration)
     * @return offerId ID of the created offer
     */
    function createOffer(
        address tokenOffered,
        uint256 amountOffered,
        address tokenRequested,
        uint256 amountRequested,
        uint256 expirationTime
    ) external returns (uint256 offerId) {
        require(tokenOffered != address(0), "Invalid offered token address");
        require(tokenRequested != address(0), "Invalid requested token address");
        require(tokenOffered != tokenRequested, "Cannot swap same token");
        require(amountOffered > 0, "Offered amount must be greater than 0");
        require(amountRequested > 0, "Requested amount must be greater than 0");
        require(
            expirationTime == 0 || expirationTime > block.timestamp,
            "Expiration time must be in the future"
        );
        
        // Transfer tokens from maker to contract
        IERC20(tokenOffered).transferFrom(msg.sender, address(this), amountOffered);
        
        // Create the offer
        offerId = offerCount++;
        swapOffers[offerId] = SwapOffer({
            maker: msg.sender,
            tokenOffered: tokenOffered,
            amountOffered: amountOffered,
            tokenRequested: tokenRequested,
            amountRequested: amountRequested,
            expirationTime: expirationTime == 0 ? type(uint256).max : expirationTime,
            isActive: true
        });
        
        emit OfferCreated(
            offerId,
            msg.sender,
            tokenOffered,
            amountOffered,
            tokenRequested,
            amountRequested,
            expirationTime
        );
        
        return offerId;
    }
    
    /**
     * @dev Cancel an existing swap offer
     * @param offerId ID of the offer to cancel
     */
    function cancelOffer(uint256 offerId) external {
        SwapOffer storage offer = swapOffers[offerId];
        
        require(offer.isActive, "Offer is not active");
        require(offer.maker == msg.sender, "Only maker can cancel offer");
        
        // Mark offer as inactive
        offer.isActive = false;
        
        // Return tokens to maker
        IERC20(offer.tokenOffered).transfer(offer.maker, offer.amountOffered);
        
        emit OfferCancelled(offerId, msg.sender);
    }
    
    /**
     * @dev Execute a swap offer
     * @param offerId ID of the offer to execute
     */
    function executeSwap(uint256 offerId) external nonReentrant {
        SwapOffer storage offer = swapOffers[offerId];
        
        require(offer.isActive, "Offer is not active");
        require(block.timestamp <= offer.expirationTime, "Offer has expired");
        require(msg.sender != offer.maker, "Cannot execute own offer");
        
        // Mark offer as inactive
        offer.isActive = false;
        
        // Calculate platform fee
        uint256 feeAmount = (offer.amountRequested * platformFee) / 10000;
        uint256 makerAmount = offer.amountRequested - feeAmount;
        
        // Transfer requested tokens from taker to maker (minus fee)
        IERC20(offer.tokenRequested).transferFrom(
            msg.sender,
            offer.maker,
            makerAmount
        );
        
        // Transfer fee to owner if applicable
        if (feeAmount > 0) {
            IERC20(offer.tokenRequested).transferFrom(
                msg.sender,
                owner(),
                feeAmount
            );
        }
        
        // Transfer offered tokens from contract to taker
        IERC20(offer.tokenOffered).transfer(msg.sender, offer.amountOffered);
        
        emit SwapExecuted(
            offerId,
            offer.maker,
            msg.sender,
            offer.tokenOffered,
            offer.amountOffered,
            offer.tokenRequested,
            offer.amountRequested
        );
    }
    
    /**
     * @dev Check if an offer is active and not expired
     * @param offerId ID of the offer to check
     * @return isValid Whether the offer is valid (active and not expired)
     */
    function isOfferValid(uint256 offerId) external view returns (bool isValid) {
        SwapOffer storage offer = swapOffers[offerId];
        return offer.isActive && block.timestamp <= offer.expirationTime;
    }
    
    /**
     * @dev Get active offers from a specific maker
     * @param maker Address of the maker
     * @param startIndex Starting index for pagination
     * @param count Maximum number of offers to return
     * @return offerIds Array of offer IDs
     */
    function getOffersByMaker(
        address maker,
        uint256 startIndex,
        uint256 count
    ) external view returns (uint256[] memory offerIds) {
        // Count active offers from maker
        uint256 activeCount = 0;
        for (uint256 i = 0; i < offerCount; i++) {
            if (swapOffers[i].maker == maker && swapOffers[i].isActive) {
                activeCount++;
            }
        }
        
        // Adjust count if needed
        if (startIndex >= activeCount) {
            return new uint256[](0);
        }
        
        uint256 returnCount = count;
        if (startIndex + returnCount > activeCount) {
            returnCount = activeCount - startIndex;
        }
        
        // Collect offer IDs
        offerIds = new uint256[](returnCount);
        uint256 currentIndex = 0;
        uint256 resultIndex = 0;
        
        for (uint256 i = 0; i < offerCount && resultIndex < returnCount; i++) {
            if (swapOffers[i].maker == maker && swapOffers[i].isActive) {
                if (currentIndex >= startIndex) {
                    offerIds[resultIndex] = i;
                    resultIndex++;
                }
                currentIndex++;
            }
        }
        
        return offerIds;
    }
    
    /**
     * @dev Get offers for a specific token pair
     * @param tokenA First token address
     * @param tokenB Second token address
     * @param startIndex Starting index for pagination
     * @param count Maximum number of offers to return
     * @return offerIds Array of offer IDs
     */
    function getOffersByTokenPair(
        address tokenA,
        address tokenB,
        uint256 startIndex,
        uint256 count
    ) external view returns (uint256[] memory offerIds) {
        // Count active offers for token pair
        uint256 pairCount = 0;
        for (uint256 i = 0; i < offerCount; i++) {
            SwapOffer storage offer = swapOffers[i];
            if (offer.isActive && 
                ((offer.tokenOffered == tokenA && offer.tokenRequested == tokenB) ||
                 (offer.tokenOffered == tokenB && offer.tokenRequested == tokenA))) {
                pairCount++;
            }
        }
        
        // Adjust count if needed
        if (startIndex >= pairCount) {
            return new uint256[](0);
        }
        
        uint256 returnCount = count;
        if (startIndex + returnCount > pairCount) {
            returnCount = pairCount - startIndex;
        }
        
        // Collect offer IDs
        offerIds = new uint256[](returnCount);
        uint256 currentIndex = 0;
        uint256 resultIndex = 0;
        
        for (uint256 i = 0; i < offerCount && resultIndex < returnCount; i++) {
            SwapOffer storage offer = swapOffers[i];
            if (offer.isActive && 
                ((offer.tokenOffered == tokenA && offer.tokenRequested == tokenB) ||
                 (offer.tokenOffered == tokenB && offer.tokenRequested == tokenA))) {
                if (currentIndex >= startIndex) {
                    offerIds[resultIndex] = i;
                    resultIndex++;
                }
                currentIndex++;
            }
        }
        
        return offerIds;
    }
    
    /**
     * @dev Update platform fee (owner only)
     * @param newFee New platform fee in basis points
     */
    function updatePlatformFee(uint256 newFee) external onlyOwner {
        require(newFee <= 500, "Fee too high"); // Max 5%
        
        uint256 oldFee = platformFee;
        platformFee = newFee;
        
        emit PlatformFeeUpdated(oldFee, newFee);
    }
    
    /**
     * @dev Emergency function to recover tokens accidentally sent to contract
     * @param token Token address
     * @param amount Amount to recover
     */
    function recoverTokens(address token, uint256 amount) external onlyOwner {
        IERC20(token).transfer(owner(), amount);
    }
}
