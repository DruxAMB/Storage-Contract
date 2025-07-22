// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title SimpleNFT
 * @dev A simple NFT collection contract for Base with minting, metadata, and basic marketplace features
 * @notice Create and manage your own NFT collection on Base
 */
contract SimpleNFT {
    // Token storage
    mapping(uint256 => address) private _owners;
    mapping(address => uint256) private _balances;
    mapping(uint256 => address) private _tokenApprovals;
    mapping(address => mapping(address => bool)) private _operatorApprovals;
    mapping(uint256 => string) private _tokenURIs;
    
    // Collection info
    string public name;
    string public symbol;
    string public baseURI;
    address public owner;
    uint256 public totalSupply;
    uint256 public maxSupply;
    uint256 public mintPrice;
    bool public mintingActive;
    
    // Marketplace features
    mapping(uint256 => uint256) public tokenPrices;
    mapping(uint256 => bool) public tokensForSale;
    
    uint256 private _currentTokenId;
    
    // Events (ERC-721 standard + custom)
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);
    event TokenMinted(address indexed to, uint256 indexed tokenId, string tokenURI);
    event TokenListedForSale(uint256 indexed tokenId, uint256 price);
    event TokenSold(uint256 indexed tokenId, address indexed from, address indexed to, uint256 price);
    event MintingStatusChanged(bool active);
    event BaseURIUpdated(string newBaseURI);
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    modifier tokenExists(uint256 tokenId) {
        require(_owners[tokenId] != address(0), "Token does not exist");
        _;
    }
    
    modifier onlyTokenOwner(uint256 tokenId) {
        require(ownerOf(tokenId) == msg.sender, "Not the token owner");
        _;
    }
    
    // Constructor
    constructor(
        string memory _name,
        string memory _symbol,
        string memory _baseURI,
        uint256 _maxSupply,
        uint256 _mintPrice
    ) {
        name = _name;
        symbol = _symbol;
        baseURI = _baseURI;
        owner = msg.sender;
        maxSupply = _maxSupply;
        mintPrice = _mintPrice;
        mintingActive = true;
        totalSupply = 0;
        _currentTokenId = 1;
    }
    
    /**
     * @dev Mint a new NFT
     * @param to Address to mint the NFT to
     * @param tokenURI Metadata URI for the token
     */
    function mint(address to, string memory tokenURI) public payable {
        require(mintingActive, "Minting is not active");
        require(totalSupply < maxSupply, "Max supply reached");
        require(msg.value >= mintPrice, "Insufficient payment");
        require(to != address(0), "Cannot mint to zero address");
        
        uint256 tokenId = _currentTokenId;
        _currentTokenId++;
        
        _owners[tokenId] = to;
        _balances[to]++;
        totalSupply++;
        
        if (bytes(tokenURI).length > 0) {
            _tokenURIs[tokenId] = tokenURI;
        }
        
        emit Transfer(address(0), to, tokenId);
        emit TokenMinted(to, tokenId, tokenURI);
    }
    
    /**
     * @dev Mint NFT to yourself
     * @param tokenURI Metadata URI for the token
     */
    function mintToSelf(string memory tokenURI) external payable {
        mint(msg.sender, tokenURI);
    }
    
    /**
     * @dev Owner mint (free minting for contract owner)
     * @param to Address to mint to
     * @param tokenURI Metadata URI for the token
     */
    function ownerMint(address to, string memory tokenURI) external onlyOwner {
        require(totalSupply < maxSupply, "Max supply reached");
        require(to != address(0), "Cannot mint to zero address");
        
        uint256 tokenId = _currentTokenId;
        _currentTokenId++;
        
        _owners[tokenId] = to;
        _balances[to]++;
        totalSupply++;
        
        if (bytes(tokenURI).length > 0) {
            _tokenURIs[tokenId] = tokenURI;
        }
        
        emit Transfer(address(0), to, tokenId);
        emit TokenMinted(to, tokenId, tokenURI);
    }
    
    /**
     * @dev Get owner of a token
     * @param tokenId Token ID to check
     * @return Owner address
     */
    function ownerOf(uint256 tokenId) public view tokenExists(tokenId) returns (address) {
        return _owners[tokenId];
    }
    
    /**
     * @dev Get balance of an address
     * @param owner Address to check
     * @return Number of tokens owned
     */
    function balanceOf(address owner) public view returns (uint256) {
        require(owner != address(0), "Balance query for zero address");
        return _balances[owner];
    }
    
    /**
     * @dev Get token URI
     * @param tokenId Token ID to get URI for
     * @return Token URI string
     */
    function tokenURI(uint256 tokenId) public view tokenExists(tokenId) returns (string memory) {
        string memory _tokenURI = _tokenURIs[tokenId];
        
        // If token has specific URI, return it
        if (bytes(_tokenURI).length > 0) {
            return _tokenURI;
        }
        
        // Otherwise, return baseURI + tokenId
        return bytes(baseURI).length > 0 
            ? string(abi.encodePacked(baseURI, _toString(tokenId)))
            : "";
    }
    
    /**
     * @dev Transfer token from one address to another
     * @param from Current owner
     * @param to New owner
     * @param tokenId Token to transfer
     */
    function transferFrom(address from, address to, uint256 tokenId) external {
        require(_isApprovedOrOwner(msg.sender, tokenId), "Not approved or owner");
        require(from == ownerOf(tokenId), "From address is not owner");
        require(to != address(0), "Cannot transfer to zero address");
        
        // Clear approvals
        _approve(address(0), tokenId);
        
        // Remove from sale if listed
        if (tokensForSale[tokenId]) {
            tokensForSale[tokenId] = false;
            tokenPrices[tokenId] = 0;
        }
        
        // Update balances
        _balances[from]--;
        _balances[to]++;
        _owners[tokenId] = to;
        
        emit Transfer(from, to, tokenId);
    }
    
    /**
     * @dev Safe transfer (same as transferFrom for simplicity)
     */
    function safeTransferFrom(address from, address to, uint256 tokenId) external {
        transferFrom(from, to, tokenId);
    }
    
    /**
     * @dev Approve another address to transfer a specific token
     * @param to Address to approve
     * @param tokenId Token to approve
     */
    function approve(address to, uint256 tokenId) external {
        address owner = ownerOf(tokenId);
        require(to != owner, "Approval to current owner");
        require(msg.sender == owner || isApprovedForAll(owner, msg.sender), "Not approved or owner");
        
        _approve(to, tokenId);
    }
    
    /**
     * @dev Get approved address for a token
     * @param tokenId Token to check
     * @return Approved address
     */
    function getApproved(uint256 tokenId) public view tokenExists(tokenId) returns (address) {
        return _tokenApprovals[tokenId];
    }
    
    /**
     * @dev Set approval for all tokens
     * @param operator Address to set approval for
     * @param approved Whether to approve or revoke
     */
    function setApprovalForAll(address operator, bool approved) external {
        require(operator != msg.sender, "Approve to caller");
        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }
    
    /**
     * @dev Check if operator is approved for all tokens of owner
     * @param owner Token owner
     * @param operator Operator to check
     * @return Whether operator is approved
     */
    function isApprovedForAll(address owner, address operator) public view returns (bool) {
        return _operatorApprovals[owner][operator];
    }
    
    /**
     * @dev List token for sale
     * @param tokenId Token to list
     * @param price Price in wei
     */
    function listForSale(uint256 tokenId, uint256 price) external onlyTokenOwner(tokenId) {
        require(price > 0, "Price must be greater than 0");
        
        tokensForSale[tokenId] = true;
        tokenPrices[tokenId] = price;
        
        emit TokenListedForSale(tokenId, price);
    }
    
    /**
     * @dev Remove token from sale
     * @param tokenId Token to remove from sale
     */
    function removeFromSale(uint256 tokenId) external onlyTokenOwner(tokenId) {
        tokensForSale[tokenId] = false;
        tokenPrices[tokenId] = 0;
    }
    
    /**
     * @dev Buy a token that's for sale
     * @param tokenId Token to buy
     */
    function buyToken(uint256 tokenId) external payable tokenExists(tokenId) {
        require(tokensForSale[tokenId], "Token not for sale");
        require(msg.value >= tokenPrices[tokenId], "Insufficient payment");
        
        address seller = ownerOf(tokenId);
        require(seller != msg.sender, "Cannot buy your own token");
        
        uint256 price = tokenPrices[tokenId];
        
        // Remove from sale
        tokensForSale[tokenId] = false;
        tokenPrices[tokenId] = 0;
        
        // Transfer token
        _approve(address(0), tokenId);
        _balances[seller]--;
        _balances[msg.sender]++;
        _owners[tokenId] = msg.sender;
        
        // Transfer payment
        payable(seller).transfer(price);
        
        // Refund excess payment
        if (msg.value > price) {
            payable(msg.sender).transfer(msg.value - price);
        }
        
        emit Transfer(seller, msg.sender, tokenId);
        emit TokenSold(tokenId, seller, msg.sender, price);
    }
    
    /**
     * @dev Get tokens owned by an address
     * @param owner Address to check
     * @return Array of token IDs
     */
    function tokensOfOwner(address owner) external view returns (uint256[] memory) {
        uint256 tokenCount = balanceOf(owner);
        uint256[] memory tokenIds = new uint256[](tokenCount);
        uint256 index = 0;
        
        for (uint256 i = 1; i < _currentTokenId && index < tokenCount; i++) {
            if (_owners[i] == owner) {
                tokenIds[index] = i;
                index++;
            }
        }
        
        return tokenIds;
    }
    
    /**
     * @dev Get all tokens for sale
     * @return tokenIds Array of token IDs for sale
     * @return prices Array of corresponding prices
     */
    function getTokensForSale() external view returns (uint256[] memory tokenIds, uint256[] memory prices) {
        uint256 count = 0;
        
        // Count tokens for sale
        for (uint256 i = 1; i < _currentTokenId; i++) {
            if (tokensForSale[i]) {
                count++;
            }
        }
        
        tokenIds = new uint256[](count);
        prices = new uint256[](count);
        uint256 index = 0;
        
        // Fill arrays
        for (uint256 i = 1; i < _currentTokenId && index < count; i++) {
            if (tokensForSale[i]) {
                tokenIds[index] = i;
                prices[index] = tokenPrices[i];
                index++;
            }
        }
    }
    
    /**
     * @dev Update base URI (owner only)
     * @param newBaseURI New base URI
     */
    function setBaseURI(string memory newBaseURI) external onlyOwner {
        baseURI = newBaseURI;
        emit BaseURIUpdated(newBaseURI);
    }
    
    /**
     * @dev Toggle minting status (owner only)
     */
    function toggleMinting() external onlyOwner {
        mintingActive = !mintingActive;
        emit MintingStatusChanged(mintingActive);
    }
    
    /**
     * @dev Update mint price (owner only)
     * @param newPrice New mint price in wei
     */
    function setMintPrice(uint256 newPrice) external onlyOwner {
        mintPrice = newPrice;
    }
    
    /**
     * @dev Withdraw contract balance (owner only)
     */
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");
        payable(owner).transfer(balance);
    }
    
    /**
     * @dev Get collection info
     * @return Collection statistics
     */
    function getCollectionInfo() external view returns (
        uint256 currentSupply,
        uint256 maxTokens,
        uint256 price,
        bool active,
        address contractOwner
    ) {
        return (totalSupply, maxSupply, mintPrice, mintingActive, owner);
    }
    
    // Internal functions
    function _approve(address to, uint256 tokenId) internal {
        _tokenApprovals[tokenId] = to;
        emit Approval(ownerOf(tokenId), to, tokenId);
    }
    
    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view returns (bool) {
        require(_owners[tokenId] != address(0), "Token does not exist");
        address owner = ownerOf(tokenId);
        return (spender == owner || getApproved(tokenId) == spender || isApprovedForAll(owner, spender));
    }
    
    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
    
    // ERC-165 support
    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == 0x01ffc9a7 || // ERC-165
               interfaceId == 0x80ac58cd || // ERC-721
               interfaceId == 0x5b5e139f;   // ERC-721 Metadata
    }
}
