// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {AminalFactory} from "src/AminalFactory.sol";
import {IGenes} from "src/interfaces/IGenes.sol";

/**
 * @title DeployAminalFactory
 * @notice Deployment script for AminalFactory
 * @dev Run with: forge script script/DeployAminalFactory.s.sol --broadcast --verify
 */
contract DeployAminalFactory is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deploying AminalFactory with deployer:", deployer);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Create parent data for Adam and Eve
        AminalFactory.ParentData memory firstParentData = AminalFactory.ParentData({
            name: "Adam",
            symbol: "ADAM",
            description: "The first Aminal",
            tokenURI: "ipfs://adam",
            genes: IGenes.Genes({
                back: "Original Wings",
                arm: "First Arms",
                tail: "Genesis Tail",
                ears: "Prime Ears",
                body: "Alpha Body",
                face: "Beginning Face",
                mouth: "Initial Mouth",
                misc: "Creation Spark"
            })
        });
        
        AminalFactory.ParentData memory secondParentData = AminalFactory.ParentData({
            name: "Eve",
            symbol: "EVE",
            description: "The second Aminal",
            tokenURI: "ipfs://eve",
            genes: IGenes.Genes({
                back: "Life Wings",
                arm: "Gentle Arms",
                tail: "Harmony Tail",
                ears: "Listening Ears",
                body: "Nurturing Body",
                face: "Wisdom Face",
                mouth: "Speaking Mouth",
                misc: "Life Force"
            })
        });
        
        // Deploy AminalFactory
        AminalFactory factory = new AminalFactory(
            deployer,  // owner
            "https://api.aminals.com/metadata/",  // baseURI
            firstParentData,
            secondParentData
        );
        
        console.log("AminalFactory deployed to:", address(factory));
        
        // Example: Create an Aminal (anyone can do this now, not just owner)
        IGenes.Genes memory dragonTraits = IGenes.Genes({
            back: "Dragon Wings",
            arm: "Clawed Arms",
            tail: "Fire Tail",
            ears: "Horned",
            body: "Scaled",
            face: "Fierce",
            mouth: "Fire Breathing",
            misc: "Glowing Eyes"
        });
        
        address aminalContract = factory.createAminal(
            "Fire Dragon",
            "FDRAGON",
            "A fierce fire-breathing dragon",
            "fire-dragon.json",
            dragonTraits
        );
        
        console.log("Example Aminal created at:", aminalContract);
        console.log("Total Aminals:", factory.totalAminals());
        
        vm.stopBroadcast();
    }
}