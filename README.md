# Base Smart Contract Portfolio

A comprehensive collection of smart contracts deployed on Base blockchain, showcasing various DeFi, NFT, and governance functionalities.

## 🚀 Deployed Contracts on Base Mainnet

### 1. **SimpleStorage Contract** 📦
**Address**: `0x88B741DD4C0eF38587D374f7Cc5c485De2200Cf3`  
**[View on Basescan](https://basescan.org/address/0x88B741DD4C0eF38587D374f7Cc5c485De2200Cf3)**

- **Store Value**: Store any uint256 value
- **Retrieve Value**: Get the currently stored value
- **Increment**: Increment the stored value by 1
- **Get Info**: Retrieve both the current value and contract owner
- **Events**: Emits events when values are updated

### 2. **GreetingContract** 👋
**Address**: `0x6705FB53187e3a27862cFED3daE6EC80e506c952`  
**[View on Basescan](https://basescan.org/address/0x6705FB53187e3a27862cFED3daE6EC80e506c952)**

- **Personal Greetings**: Set custom greetings per user
- **Default Greeting**: Fallback greeting for new users
- **Timestamp Tracking**: Records when greetings were set
- **Owner Controls**: Admin can update default greeting
- **Statistics**: Track total number of greeters

### 3. **TokenVault** 🏦
**Address**: `0xe13BD178F1cE140B799a7BcBEF4C62dAA84F8664`  
**[View on Basescan](https://basescan.org/address/0xe13BD178F1cE140B799a7BcBEF4C62dAA84F8664)**

- **ETH Deposits**: Secure ETH storage with interest
- **Interest Calculation**: 5% annual interest (500 basis points)
- **Flexible Withdrawals**: Withdraw deposits + earned interest
- **Minimum Deposit**: 0.0001 ETH for testing
- **User Analytics**: Track individual balances and earnings

### 4. **SimpleNFT** 🎨
**Address**: `0x49297371d51544a71495e0Aacf3c66908F785aEd`  
**[View on Basescan](https://basescan.org/address/0x49297371d51544a71495e0Aacf3c66908F785aEd)**

- **ERC-721 Compliant**: Full NFT standard implementation
- **Built-in Marketplace**: List and buy NFTs directly
- **Custom Metadata**: Support for token URIs and descriptions
- **Owner Controls**: Mint price and supply management
- **Gas Optimized**: Efficient storage and transfer mechanisms

### 5. **DecentralizedVoting** 🗳️
**Address**: `0xD876ff79167604630f4F0e5d2B4E63A091060Cc4`  
**[View on Basescan](https://basescan.org/address/0xD876ff79167604630f4F0e5d2B4E63A091060Cc4)**

- **Proposal Creation**: Submit governance proposals
- **Voter Registration**: Open registration system
- **Time-based Voting**: 7-day voting periods
- **Quorum Requirements**: Minimum 10 votes for validity
- **Transparent Execution**: Automatic proposal execution

## Prerequisites

1. **Install Foundry** (if not already installed):
   ```bash
   curl -L https://foundry.paradigm.xyz | bash
   foundryup
   ```

2. **Get Base Sepolia ETH**: Obtain test ETH from [Base faucets](https://docs.base.org/tools/network-faucets)

## Setup

1. **Clone and setup environment**:
   ```bash
   cp .env.example .env
   ```

2. **Secure your private key**:
   ```bash
   cast wallet import deployer --interactive
   ```
   Enter your private key when prompted and set a password.

## Deployment

### Option 1: Using Foundry (Recommended)
```bash
# Deploy to Base Sepolia
forge create ./src/SimpleStorage.sol:SimpleStorage --rpc-url https://sepolia.base.org --account deployer

# Or using the deployment script
forge script script/Deploy.s.sol --rpc-url https://sepolia.base.org --account deployer --broadcast
```

### Option 2: Manual Deployment
If Foundry isn't available, you can use other tools like Remix IDE or Hardhat.

## 🛠️ Interacting with Your Contracts

### Using Foundry/Cast (Command Line)

**Setup environment variables:**
```bash
# Set contract addresses
export SIMPLE_STORAGE="0x88B741DD4C0eF38587D374f7Cc5c485De2200Cf3"
export GREETING_CONTRACT="0x6705FB53187e3a27862cFED3daE6EC80e506c952"
export TOKEN_VAULT="0xe13BD178F1cE140B799a7BcBEF4C62dAA84F8664"
export SIMPLE_NFT="0x49297371d51544a71495e0Aacf3c66908F785aEd"
export VOTING_CONTRACT="0xD876ff79167604630f4F0e5d2B4E63A091060Cc4"
export BASE_RPC="https://mainnet.base.org"

#### SimpleStorage Contract
```bash
# Read current value
cast call $SIMPLE_STORAGE "retrieve()(uint256)" --rpc-url $BASE_RPC

# Store new value
cast send $SIMPLE_STORAGE "store(uint256)" 42 --rpc-url $BASE_RPC --account deployer

# Increment value
cast send $SIMPLE_STORAGE "increment()" --rpc-url $BASE_RPC --account deployer
```

#### GreetingContract
```bash
# Set personal greeting
cast send $GREETING_CONTRACT "setGreeting(string)" "Hello Base!" --rpc-url $BASE_RPC --account deployer

# Get greeting for address
cast call $GREETING_CONTRACT "getGreeting(address)" YOUR_ADDRESS --rpc-url $BASE_RPC
```

#### TokenVault
```bash
# Deposit ETH (0.001 ETH example)
cast send $TOKEN_VAULT "deposit()" --value 1000000000000000 --rpc-url $BASE_RPC --account deployer

# Check balance
cast call $TOKEN_VAULT "getMyInfo()(uint256,uint256)" --rpc-url $BASE_RPC --from YOUR_ADDRESS

# Withdraw all funds
cast send $TOKEN_VAULT "withdraw(uint256)" AMOUNT --rpc-url $BASE_RPC --account deployer
```

#### SimpleNFT
```bash
# Mint NFT (0.0001 ETH)
cast send $SIMPLE_NFT "mintToSelf(string)" "My Base NFT" --value 100000000000000 --rpc-url $BASE_RPC --account deployer

# Check your NFT balance
cast call $SIMPLE_NFT "balanceOf(address)" YOUR_ADDRESS --rpc-url $BASE_RPC

# List NFT for sale (token 1 for 0.0002 ETH)
cast send $SIMPLE_NFT "listForSale(uint256,uint256)" 1 200000000000000 --rpc-url $BASE_RPC --account deployer
```

#### DecentralizedVoting
```bash
# Register to vote
cast send $VOTING_CONTRACT "registerToVote()" --rpc-url $BASE_RPC --account deployer

# Create proposal
cast send $VOTING_CONTRACT "createProposal(string,string)" "Proposal Title" "Proposal Description" --rpc-url $BASE_RPC --account deployer

# Vote on proposal (true = yes, false = no)
cast send $VOTING_CONTRACT "vote(uint256,bool)" 1 true --rpc-url $BASE_RPC --account deployer
```

### Using Remix IDE (Browser-based)

1. **Open [Remix IDE](https://remix.ethereum.org/)**
2. **Connect MetaMask** to Base mainnet
3. **Go to "Deploy & Run"** tab
4. **Set Environment** to "Injected Provider - MetaMask"
5. **Load contract** using "At Address" with contract addresses above
6. **Interact** with blue (view) and red (transaction) buttons

## 🔍 Contract Verification

All contracts are verified on Basescan:
- [SimpleStorage](https://basescan.org/address/0x88B741DD4C0eF38587D374f7Cc5c485De2200Cf3)
- [GreetingContract](https://basescan.org/address/0x6705FB53187e3a27862cFED3daE6EC80e506c952)
- [TokenVault](https://basescan.org/address/0xe13BD178F1cE140B799a7BcBEF4C62dAA84F8664)
- [SimpleNFT](https://basescan.org/address/0x49297371d51544a71495e0Aacf3c66908F785aEd)
- [DecentralizedVoting](https://basescan.org/address/0xD876ff79167604630f4F0e5d2B4E63A091060Cc4)

## 🚀 Next Steps

- **Build a Frontend**: Use [Onchainkit](https://onchainkit.com) for React integration
- **Add More Features**: Extend contracts with additional functionality
- **Create a DApp**: Combine multiple contracts into a full application
- **Deploy on Other Networks**: Use the same contracts on other EVM chains

## 📊 Portfolio Summary

✅ **5 Production-Ready Contracts Deployed**  
✅ **Full Base Blockchain Integration**  
✅ **DeFi, NFT, and Governance Functionality**  
✅ **Professional Documentation & Testing**  
✅ **Ready for Frontend Integration**
