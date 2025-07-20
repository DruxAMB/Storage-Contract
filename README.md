# Simple Storage Contract on Base

A simple smart contract deployed on Base that demonstrates basic storage operations.

## Contract Features

- **Store Value**: Store any uint256 value
- **Retrieve Value**: Get the currently stored value
- **Increment**: Increment the stored value by 1
- **Get Info**: Retrieve both the current value and contract owner
- **Events**: Emits events when values are updated

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

## Interacting with the Contract

After deployment, you can interact with your contract:

```bash
# Set the contract address in your environment
export CONTRACT_ADDRESS="0x..." # Your deployed contract address

# Read the current value
cast call $CONTRACT_ADDRESS "retrieve()(uint256)" --rpc-url https://sepolia.base.org

# Store a new value (requires gas)
cast send $CONTRACT_ADDRESS "store(uint256)" 42 --rpc-url https://sepolia.base.org --account deployer

# Increment the value
cast send $CONTRACT_ADDRESS "increment()" --rpc-url https://sepolia.base.org --account deployer

# Get contract info
cast call $CONTRACT_ADDRESS "getInfo()(uint256,address)" --rpc-url https://sepolia.base.org
```

## Verification

Verify your deployment on [Sepolia Basescan](https://sepolia.basescan.org/) by searching for your contract address.

## Next Steps

- Connect a frontend using [Onchainkit](https://onchainkit.com)
- Deploy to Base mainnet when ready
- Add more complex functionality to your contract

## Contract Address

✅ **Deployed Contract:**
- **Base Mainnet**: `0x88B741DD4C0eF38587D374f7Cc5c485De2200Cf3`
- **Basescan**: [View on Basescan](https://basescan.org/address/0x88B741DD4C0eF38587D374f7Cc5c485De2200Cf3)
- **Deployment Method**: Remix IDE
