// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {CeloMessageBoard} from "../src/CeloMessageBoard.sol";
import {CeloLottery} from "../src/CeloLottery.sol";
import {IERC20} from "../src/interfaces/IERC20.sol";

/**
 * @title DeployCelo
 * @dev Deployment script for CELO network contracts
 */
contract DeployCelo is Script {
    // CELO token addresses
    address constant CELO_MAINNET_CUSD = 0x765DE816845861e75A25fCA122bb6898B8B1282a;
    address constant CELO_TESTNET_CUSD = 0x874069Fa1Eb16D44d622F2e0Ca25eeA172369bC1;

    function run() external {
        // Load private key from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // Determine which cUSD address to use based on chain ID
        uint256 chainId = block.chainid;
        address cUSDAddress;
        
        if (chainId == 42220) {
            // CELO Mainnet
            cUSDAddress = CELO_MAINNET_CUSD;
            console.log("Deploying to CELO Mainnet");
        } else if (chainId == 44787) {
            // CELO Alfajores Testnet
            cUSDAddress = CELO_TESTNET_CUSD;
            console.log("Deploying to CELO Alfajores Testnet");
        } else {
            revert("Unsupported network for CELO deployment");
        }

        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);

        // Deploy CeloMessageBoard
        CeloMessageBoard celoMessageBoard = new CeloMessageBoard(
            "CELO Community Board",           // Board name
            cUSDAddress,                      // cUSD token address
            1 * 10**18,                      // 1 cUSD minimum tip
            250                              // 2.5% platform fee
        );
        console.log("CeloMessageBoard deployed to:", address(celoMessageBoard));

        // Deploy CeloLottery
        CeloLottery celoLottery = new CeloLottery(
            cUSDAddress,                     // cUSD token address
            500,                             // 5% platform fee
            1 * 10**18,                     // 1 cUSD minimum ticket price
            100 * 10**18                    // 100 cUSD maximum ticket price
        );
        console.log("CeloLottery deployed to:", address(celoLottery));

        vm.stopBroadcast();

        // Log deployment summary
        console.log("\n=== CELO DEPLOYMENT SUMMARY ===");
        console.log("Network Chain ID:", chainId);
        console.log("cUSD Address:", cUSDAddress);
        console.log("CeloMessageBoard:", address(celoMessageBoard));
        console.log("CeloLottery:", address(celoLottery));
        
        // Log next steps
        console.log("\n=== NEXT STEPS ===");
        console.log("1. Verify contracts on Celoscan");
        console.log("2. Test cUSD functionality");
        console.log("3. Update .env with new addresses");
    }
}
