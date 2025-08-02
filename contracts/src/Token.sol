// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title SimpleToken
 * @dev ERC-20 compliant token with mint/burn capabilities and advanced features
 * @notice Custom token for Base ecosystem with transfer restrictions and allowances
 */
contract SimpleToken {
    // Token details
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;
    uint256 public maxSupply;
    
    // Balances and allowances
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    
    // Access control
    address public owner;
    mapping(address => bool) public minters;
    mapping(address => bool) public burners;
    
    // Transfer restrictions
    bool public transfersEnabled;
    mapping(address => bool) public blacklisted;
    mapping(address => bool) public whitelisted;
    bool public whitelistMode;
    
    // Events (ERC-20 standard)
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    
    // Custom events
    event Mint(address indexed to, uint256 value);
    event Burn(address indexed from, uint256 value);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event MinterAdded(address indexed minter);
    event MinterRemoved(address indexed minter);
    event BurnerAdded(address indexed burner);
    event BurnerRemoved(address indexed burner);
    event TransfersEnabled();
    event TransfersDisabled();
    event Blacklisted(address indexed account);
    event Unblacklisted(address indexed account);
    event WhitelistModeEnabled();
    event WhitelistModeDisabled();
    event Whitelisted(address indexed account);
    event UnWhitelisted(address indexed account);

    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }
    
    modifier onlyMinter() {
        require(minters[msg.sender] || msg.sender == owner, "Not authorized to mint");
        _;
    }
    
    modifier onlyBurner() {
        require(burners[msg.sender] || msg.sender == owner, "Not authorized to burn");
        _;
    }
    
    modifier transferAllowed(address from, address to) {
        require(transfersEnabled, "Transfers are disabled");
        require(!blacklisted[from] && !blacklisted[to], "Address is blacklisted");
        
        if (whitelistMode) {
            require(whitelisted[from] && whitelisted[to], "Address not whitelisted");
        }
        _;
    }

    /**
     * @dev Constructor sets token details and initial supply
     * @param _name Token name
     * @param _symbol Token symbol
     * @param _decimals Token decimals
     * @param _initialSupply Initial token supply
     * @param _maxSupply Maximum token supply (0 for unlimited)
     */
    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        uint256 _initialSupply,
        uint256 _maxSupply
    ) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        maxSupply = _maxSupply;
        owner = msg.sender;
        transfersEnabled = true;
        
        if (_initialSupply > 0) {
            require(_maxSupply == 0 || _initialSupply <= _maxSupply, "Initial supply exceeds max supply");
            totalSupply = _initialSupply;
            balanceOf[msg.sender] = _initialSupply;
            emit Transfer(address(0), msg.sender, _initialSupply);
        }
        
        // Owner is automatically a minter and burner
        minters[msg.sender] = true;
        burners[msg.sender] = true;
        
        emit MinterAdded(msg.sender);
        emit BurnerAdded(msg.sender);
    }

    /**
     * @dev Transfer tokens
     * @param to Recipient address
     * @param value Amount to transfer
     * @return success Whether transfer succeeded
     */
    function transfer(address to, uint256 value) 
        public 
        transferAllowed(msg.sender, to) 
        returns (bool success) 
    {
        require(to != address(0), "Transfer to zero address");
        require(balanceOf[msg.sender] >= value, "Insufficient balance");
        
        balanceOf[msg.sender] -= value;
        balanceOf[to] += value;
        
        emit Transfer(msg.sender, to, value);
        return true;
    }

    /**
     * @dev Approve spender to transfer tokens
     * @param spender Spender address
     * @param value Amount to approve
     * @return success Whether approval succeeded
     */
    function approve(address spender, uint256 value) public returns (bool success) {
        require(spender != address(0), "Approve to zero address");
        
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    /**
     * @dev Transfer tokens from one address to another
     * @param from Sender address
     * @param to Recipient address
     * @param value Amount to transfer
     * @return success Whether transfer succeeded
     */
    function transferFrom(address from, address to, uint256 value) 
        public 
        transferAllowed(from, to) 
        returns (bool success) 
    {
        require(to != address(0), "Transfer to zero address");
        require(balanceOf[from] >= value, "Insufficient balance");
        require(allowance[from][msg.sender] >= value, "Insufficient allowance");
        
        balanceOf[from] -= value;
        balanceOf[to] += value;
        allowance[from][msg.sender] -= value;
        
        emit Transfer(from, to, value);
        return true;
    }

    /**
     * @dev Mint new tokens
     * @param to Recipient address
     * @param value Amount to mint
     */
    function mint(address to, uint256 value) public onlyMinter {
        require(to != address(0), "Mint to zero address");
        require(maxSupply == 0 || totalSupply + value <= maxSupply, "Exceeds max supply");
        
        totalSupply += value;
        balanceOf[to] += value;
        
        emit Transfer(address(0), to, value);
        emit Mint(to, value);
    }

    /**
     * @dev Burn tokens from sender
     * @param value Amount to burn
     */
    function burn(uint256 value) public {
        require(balanceOf[msg.sender] >= value, "Insufficient balance to burn");
        
        balanceOf[msg.sender] -= value;
        totalSupply -= value;
        
        emit Transfer(msg.sender, address(0), value);
        emit Burn(msg.sender, value);
    }

    /**
     * @dev Burn tokens from specific address (requires allowance)
     * @param from Address to burn from
     * @param value Amount to burn
     */
    function burnFrom(address from, uint256 value) public onlyBurner {
        require(from != address(0), "Burn from zero address");
        require(balanceOf[from] >= value, "Insufficient balance to burn");
        
        balanceOf[from] -= value;
        totalSupply -= value;
        
        emit Transfer(from, address(0), value);
        emit Burn(from, value);
    }

    /**
     * @dev Transfer ownership
     * @param newOwner New owner address
     */
    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "New owner is zero address");
        
        address previousOwner = owner;
        owner = newOwner;
        
        // Transfer minter and burner roles
        minters[previousOwner] = false;
        burners[previousOwner] = false;
        minters[newOwner] = true;
        burners[newOwner] = true;
        
        emit OwnershipTransferred(previousOwner, newOwner);
        emit MinterRemoved(previousOwner);
        emit BurnerRemoved(previousOwner);
        emit MinterAdded(newOwner);
        emit BurnerAdded(newOwner);
    }

    /**
     * @dev Add minter
     * @param minter Address to add as minter
     */
    function addMinter(address minter) public onlyOwner {
        require(minter != address(0), "Minter is zero address");
        require(!minters[minter], "Already a minter");
        
        minters[minter] = true;
        emit MinterAdded(minter);
    }

    /**
     * @dev Remove minter
     * @param minter Address to remove as minter
     */
    function removeMinter(address minter) public onlyOwner {
        require(minter != owner, "Cannot remove owner as minter");
        require(minters[minter], "Not a minter");
        
        minters[minter] = false;
        emit MinterRemoved(minter);
    }

    /**
     * @dev Add burner
     * @param burner Address to add as burner
     */
    function addBurner(address burner) public onlyOwner {
        require(burner != address(0), "Burner is zero address");
        require(!burners[burner], "Already a burner");
        
        burners[burner] = true;
        emit BurnerAdded(burner);
    }

    /**
     * @dev Remove burner
     * @param burner Address to remove as burner
     */
    function removeBurner(address burner) public onlyOwner {
        require(burner != owner, "Cannot remove owner as burner");
        require(burners[burner], "Not a burner");
        
        burners[burner] = false;
        emit BurnerRemoved(burner);
    }

    /**
     * @dev Enable transfers
     */
    function enableTransfers() public onlyOwner {
        transfersEnabled = true;
        emit TransfersEnabled();
    }

    /**
     * @dev Disable transfers
     */
    function disableTransfers() public onlyOwner {
        transfersEnabled = false;
        emit TransfersDisabled();
    }

    /**
     * @dev Blacklist address
     * @param account Address to blacklist
     */
    function blacklist(address account) public onlyOwner {
        require(account != address(0), "Cannot blacklist zero address");
        require(account != owner, "Cannot blacklist owner");
        require(!blacklisted[account], "Already blacklisted");
        
        blacklisted[account] = true;
        emit Blacklisted(account);
    }

    /**
     * @dev Remove from blacklist
     * @param account Address to unblacklist
     */
    function unblacklist(address account) public onlyOwner {
        require(blacklisted[account], "Not blacklisted");
        
        blacklisted[account] = false;
        emit Unblacklisted(account);
    }

    /**
     * @dev Enable whitelist mode
     */
    function enableWhitelistMode() public onlyOwner {
        whitelistMode = true;
        emit WhitelistModeEnabled();
    }

    /**
     * @dev Disable whitelist mode
     */
    function disableWhitelistMode() public onlyOwner {
        whitelistMode = false;
        emit WhitelistModeDisabled();
    }

    /**
     * @dev Add to whitelist
     * @param account Address to whitelist
     */
    function whitelist(address account) public onlyOwner {
        require(account != address(0), "Cannot whitelist zero address");
        require(!whitelisted[account], "Already whitelisted");
        
        whitelisted[account] = true;
        emit Whitelisted(account);
    }

    /**
     * @dev Remove from whitelist
     * @param account Address to remove from whitelist
     */
    function unWhitelist(address account) public onlyOwner {
        require(account != owner, "Cannot remove owner from whitelist");
        require(whitelisted[account], "Not whitelisted");
        
        whitelisted[account] = false;
        emit UnWhitelisted(account);
    }

    /**
     * @dev Get token information
     * @return tokenName Token name
     * @return tokenSymbol Token symbol
     * @return tokenDecimals Token decimals
     * @return tokenTotalSupply Total supply
     * @return tokenMaxSupply Maximum supply
     * @return tokenOwner Contract owner
     */
    function getTokenInfo() 
        external 
        view 
        returns (
            string memory tokenName,
            string memory tokenSymbol,
            uint8 tokenDecimals,
            uint256 tokenTotalSupply,
            uint256 tokenMaxSupply,
            address tokenOwner
        ) 
    {
        return (name, symbol, decimals, totalSupply, maxSupply, owner);
    }

    /**
     * @dev Get transfer settings
     * @param account Address to check transfer settings for
     * @return enabled Whether transfers are enabled
     * @return whitelistModeActive Whether whitelist mode is active
     * @return isBlacklisted Whether account is blacklisted
     * @return isWhitelisted Whether account is whitelisted
     */
    function getTransferSettings(address account) 
        external 
        view 
        returns (
            bool enabled,
            bool whitelistModeActive,
            bool isBlacklisted,
            bool isWhitelisted
        ) 
    {
        return (
            transfersEnabled,
            whitelistMode,
            blacklisted[account],
            whitelisted[account]
        );
    }
}
