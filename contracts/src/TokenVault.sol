// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title TokenVault
 * @dev A simple ETH vault contract for deposits, withdrawals, and interest tracking on Base
 * @notice Users can deposit ETH, earn simple interest, and withdraw their funds
 */
contract TokenVault {
    // State variables
    mapping(address => uint256) private balances;
    mapping(address => uint256) private depositTimestamps;
    mapping(address => uint256) private totalDeposited;
    
    address public owner;
    uint256 public totalVaultBalance;
    uint256 public totalUsers;
    uint256 public interestRate; // Annual interest rate in basis points (100 = 1%)
    uint256 public minimumDeposit;
    bool public vaultActive;
    
    address[] private depositors;
    
    // Events
    event Deposit(address indexed user, uint256 amount, uint256 timestamp);
    event Withdrawal(address indexed user, uint256 amount, uint256 interest, uint256 timestamp);
    event InterestRateUpdated(uint256 newRate, address updatedBy);
    event VaultStatusChanged(bool active, address changedBy);
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    modifier vaultIsActive() {
        require(vaultActive, "Vault is currently inactive");
        _;
    }
    
    modifier hasBalance() {
        require(balances[msg.sender] > 0, "No balance to withdraw");
        _;
    }
    
    // Constructor
    constructor(uint256 _interestRate, uint256 _minimumDeposit) {
        owner = msg.sender;
        interestRate = _interestRate; // e.g., 500 = 5% annual
        minimumDeposit = _minimumDeposit;
        vaultActive = true;
        totalVaultBalance = 0;
        totalUsers = 0;
    }
    
    /**
     * @dev Deposit ETH into the vault
     */
    function deposit() external payable vaultIsActive {
        require(msg.value >= minimumDeposit, "Deposit amount too small");
        
        // If first deposit, add to depositors array
        if (balances[msg.sender] == 0) {
            depositors.push(msg.sender);
            totalUsers++;
        }
        
        balances[msg.sender] += msg.value;
        totalDeposited[msg.sender] += msg.value;
        depositTimestamps[msg.sender] = block.timestamp;
        totalVaultBalance += msg.value;
        
        emit Deposit(msg.sender, msg.value, block.timestamp);
    }
    
    /**
     * @dev Withdraw ETH from the vault with calculated interest
     * @param _amount Amount to withdraw (0 = withdraw all)
     */
    function withdraw(uint256 _amount) external hasBalance vaultIsActive {
        uint256 userBalance = balances[msg.sender];
        uint256 interest = calculateInterest(msg.sender);
        uint256 totalAvailable = userBalance + interest;
        
        uint256 withdrawAmount = _amount == 0 ? totalAvailable : _amount;
        require(withdrawAmount <= totalAvailable, "Insufficient balance including interest");
        require(address(this).balance >= withdrawAmount, "Vault has insufficient funds");
        
        // Update balances
        if (withdrawAmount >= userBalance) {
            // Withdrawing more than principal, deduct from balance and pay interest
            balances[msg.sender] = 0;
            totalVaultBalance -= userBalance;
        } else {
            // Partial withdrawal from principal only
            balances[msg.sender] -= withdrawAmount;
            totalVaultBalance -= withdrawAmount;
            interest = 0; // No interest on partial withdrawals
        }
        
        // Reset timestamp for remaining balance
        if (balances[msg.sender] > 0) {
            depositTimestamps[msg.sender] = block.timestamp;
        }
        
        // Transfer funds
        payable(msg.sender).transfer(withdrawAmount);
        
        emit Withdrawal(msg.sender, withdrawAmount, interest, block.timestamp);
    }
    
    /**
     * @dev Calculate interest earned by a user
     * @param _user Address to calculate interest for
     * @return Interest amount in wei
     */
    function calculateInterest(address _user) public view returns (uint256) {
        if (balances[_user] == 0 || depositTimestamps[_user] == 0) {
            return 0;
        }
        
        uint256 timeElapsed = block.timestamp - depositTimestamps[_user];
        uint256 principal = balances[_user];
        
        // Simple interest calculation: (Principal * Rate * Time) / (100 * 365 days)
        // Rate is in basis points (100 = 1%)
        uint256 interest = (principal * interestRate * timeElapsed) / (10000 * 365 days);
        
        return interest;
    }
    
    /**
     * @dev Get user's balance and interest
     * @param _user Address to check
     * @return balance Current balance
     * @return interest Earned interest
     * @return totalAvailable Balance + interest
     */
    function getUserInfo(address _user) external view returns (
        uint256 balance,
        uint256 interest,
        uint256 totalAvailable
    ) {
        balance = balances[_user];
        interest = calculateInterest(_user);
        totalAvailable = balance + interest;
    }
    
    /**
     * @dev Get caller's balance and interest
     * @return balance Current balance
     * @return interest Earned interest
     * @return totalAvailable Balance + interest
     */
    function getMyInfo() external view returns (
        uint256 balance,
        uint256 interest,
        uint256 totalAvailable
    ) {
        return this.getUserInfo(msg.sender);
    }
    
    /**
     * @dev Get vault statistics
     * @return totalBalance Total ETH in vault
     * @return userCount Number of users with deposits
     * @return currentRate Current interest rate
     * @return minDeposit Minimum deposit amount
     * @return isActive Whether vault is active
     */
    function getVaultInfo() external view returns (
        uint256 totalBalance,
        uint256 userCount,
        uint256 currentRate,
        uint256 minDeposit,
        bool isActive
    ) {
        return (
            totalVaultBalance,
            totalUsers,
            interestRate,
            minimumDeposit,
            vaultActive
        );
    }
    
    /**
     * @dev Get all depositors
     * @return Array of depositor addresses
     */
    function getDepositors() external view returns (address[] memory) {
        return depositors;
    }
    
    /**
     * @dev Update interest rate (owner only)
     * @param _newRate New interest rate in basis points
     */
    function updateInterestRate(uint256 _newRate) external onlyOwner {
        require(_newRate <= 2000, "Interest rate too high (max 20%)");
        interestRate = _newRate;
        emit InterestRateUpdated(_newRate, msg.sender);
    }
    
    /**
     * @dev Toggle vault active status (owner only)
     */
    function toggleVaultStatus() external onlyOwner {
        vaultActive = !vaultActive;
        emit VaultStatusChanged(vaultActive, msg.sender);
    }
    
    /**
     * @dev Emergency withdrawal for owner (only if vault inactive)
     */
    function emergencyWithdraw() external onlyOwner {
        require(!vaultActive, "Vault must be inactive for emergency withdrawal");
        uint256 contractBalance = address(this).balance;
        require(contractBalance > 0, "No funds to withdraw");
        
        payable(owner).transfer(contractBalance);
    }
    
    /**
     * @dev Get contract balance
     * @return Contract's ETH balance
     */
    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }
    
    // Fallback function to receive ETH
    receive() external payable {
        // Auto-deposit received ETH
        if (msg.value >= minimumDeposit && vaultActive) {
            if (balances[msg.sender] == 0) {
                depositors.push(msg.sender);
                totalUsers++;
            }
            balances[msg.sender] += msg.value;
            totalDeposited[msg.sender] += msg.value;
            depositTimestamps[msg.sender] = block.timestamp;
            totalVaultBalance += msg.value;
            
            emit Deposit(msg.sender, msg.value, block.timestamp);
        }
    }
}
