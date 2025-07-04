// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {AminalFactory} from "src/AminalFactory.sol";
import {ITraits} from "src/interfaces/ITraits.sol";

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
        
        // Deploy AminalFactory
        AminalFactory factory = new AminalFactory(
            deployer,  // owner
            "https://api.aminals.com/metadata/"  // baseURI
        );
        
        console.log("AminalFactory deployed to:", address(factory));
        
        // Example: Create an Aminal (anyone can do this now, not just owner)
        ITraits.Traits memory dragonTraits = ITraits.Traits({
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