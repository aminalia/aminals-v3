// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {AminalFactory} from "src/AminalFactory.sol";
import {IGenes} from "src/interfaces/IGenes.sol";

/**
 * @title DeployBreedingOnlyFactory
 * @notice Deployment script for the breeding-only AminalFactory with initial parents
 * @dev Run with: forge script script/DeployBreedingOnlyFactory.s.sol --broadcast --verify
 */
contract DeployBreedingOnlyFactory is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deploying AminalFactory with initial parents with deployer:", deployer);
        
        // Define traits for the first parent (Adam)
        IGenes.Genes memory adamTraits = IGenes.Genes({
            back: "Primordial Wings",
            arm: "Strong Arms",
            tail: "Lion Tail",
            ears: "Alert Ears",
            body: "Muscular Body",
            face: "Wise Face",
            mouth: "Confident Smile",
            misc: "Divine Aura"
        });
        
        // Define traits for the second parent (Eve)
        IGenes.Genes memory eveTraits = IGenes.Genes({
            back: "Ethereal Wings",
            arm: "Graceful Arms",
            tail: "Phoenix Tail",
            ears: "Delicate Ears", 
            body: "Elegant Body",
            face: "Beautiful Face",
            mouth: "Warm Smile",
            misc: "Radiant Glow"
        });
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Create parent data structs
        AminalFactory.ParentData memory adamData = AminalFactory.ParentData({
            name: "Adam",
            symbol: "ADAM",
            description: "The first Aminal - the origin of all",
            tokenURI: "adam.json",
            genes: adamTraits
        });
        
        AminalFactory.ParentData memory eveData = AminalFactory.ParentData({
            name: "Eve",
            symbol: "EVE",
            description: "The second Aminal - the mother of all",
            tokenURI: "eve.json",
            genes: eveTraits
        });
        
        // Deploy AminalFactory with the two initial parents
        AminalFactory factory = new AminalFactory(
            deployer,  // owner
            adamData,
            eveData
        );
        
        console.log("AminalFactory deployed to:", address(factory));
        console.log("First parent (Adam) created at:", factory.firstParent());
        console.log("Second parent (Eve) created at:", factory.secondParent());
        console.log("Total Aminals:", factory.totalAminals());
        
        // Demonstrate that direct creation is not allowed
        console.log("\nAttempting direct creation (should fail)...");
        try factory.createAminal("Test", "TST", "Test", "test.json", adamTraits) {
            console.log("ERROR: Direct creation succeeded when it should have failed!");
        } catch {
            console.log("SUCCESS: Direct creation properly blocked");
        }
        
        vm.stopBroadcast();
        
        console.log("\nDeployment complete!");
        console.log("Only breeding can create new Aminals from this point forward.");
    }
}