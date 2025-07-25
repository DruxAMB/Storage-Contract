// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/MessageBoard.sol";
import "../src/LotteryContract.sol";
import "../src/StakingContract.sol";
import "../src/MultiSigWallet.sol";
import "../src/SimpleToken.sol";
import "../src/EscrowContract.sol";

/**
 * @title DeployBase
 * @dev Deployment script for Base network contracts
 */
contract DeployBase is Script {
    function run() external {
        // Load private key from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);

        // Deploy MessageBoard
        MessageBoard messageBoard = new MessageBoard("Base Community Board");
        console.log("MessageBoard deployed to:", address(messageBoard));

        // Deploy LotteryContract (5% platform fee)
        LotteryContract lottery = new LotteryContract(500);
        console.log("LotteryContract deployed to:", address(lottery));

        // Deploy StakingContract (10% emergency withdrawal penalty)
        StakingContract staking = new StakingContract(1000);
        console.log("StakingContract deployed to:", address(staking));

        // Deploy MultiSigWallet (3 owners, 2 confirmations required)
        address[] memory owners = new address[](3);
        owners[0] = vm.addr(deployerPrivateKey); // Deployer
        owners[1] = 0x742D35cc6634c0532925a3b8d5c9e3F8d4c4b8D8; // Replace with actual addresses
        owners[2] = 0x742d35cc6634C0532925a3B8D5c9E3f8d4C4b8D9; // Replace with actual addresses
        
        MultiSigWallet multiSig = new MultiSigWallet(owners, 2);
        console.log("MultiSigWallet deployed to:", address(multiSig));

        // Deploy SimpleToken
        SimpleToken token = new SimpleToken(
            "Base Community Token",
            "BCT",
            18,                   // 18 decimals
            1000000 * 10**18,     // 1M initial supply
            2000000 * 10**18      // 2M max supply
        );
        console.log("SimpleToken deployed to:", address(token));

        // Deploy EscrowContract (2.5% platform fee, 1% arbiter fee)
        EscrowContract escrow = new EscrowContract(250, 100);
        console.log("EscrowContract deployed to:", address(escrow));

        vm.stopBroadcast();

        // Log deployment summary
        console.log("\n=== BASE DEPLOYMENT SUMMARY ===");
        console.log("MessageBoard:", address(messageBoard));
        console.log("LotteryContract:", address(lottery));
        console.log("StakingContract:", address(staking));
        console.log("MultiSigWallet:", address(multiSig));
        console.log("SimpleToken:", address(token));
        console.log("EscrowContract:", address(escrow));
    }
}
