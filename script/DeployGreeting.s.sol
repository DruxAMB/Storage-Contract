// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/GreetingContract.sol";

contract DeployGreetingScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy with a default greeting
        string memory defaultGreeting = "Hello from Base! Welcome to decentralized greetings!";
        GreetingContract greetingContract = new GreetingContract(defaultGreeting);
        
        console.log("GreetingContract deployed to:", address(greetingContract));
        console.log("Default greeting:", defaultGreeting);
        console.log("Owner:", greetingContract.owner());
        
        vm.stopBroadcast();
    }
}
