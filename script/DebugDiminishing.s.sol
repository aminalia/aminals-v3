// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {Aminal} from "src/Aminal.sol";
import {ITraits} from "src/interfaces/ITraits.sol";

contract DebugDiminishing is Script {
    function run() public {
        // Create test traits
        ITraits.Traits memory traits = ITraits.Traits({
            back: "wings",
            arm: "claws", 
            tail: "fluffy",
            ears: "pointy",
            body: "furry",
            face: "cute",
            mouth: "smile",
            misc: "sparkles"
        });
        
        // Deploy Aminal
        Aminal aminal = new Aminal("TestAminal", "TAMINAL", "https://test.com/", traits);
        aminal.initialize("test-uri");
        
        // Test with the failing values
        uint256 firstAmount = 2773365158517656; // ~0.00277 ETH
        uint256 secondAmount = 4558775225738086255; // ~4.56 ETH
        
        // First feeding
        uint256 energy1 = aminal.calculateEnergyForETH(firstAmount);
        console.log("First amount:", firstAmount);
        console.log("Energy from first:", energy1);
        console.log("Energy per ETH first:", (energy1 * 1e18) / firstAmount);
        
        // Simulate first feeding by manually setting energy
        (bool success,) = address(aminal).call{value: firstAmount}("");
        require(success, "First feeding failed");
        
        uint256 currentEnergy = aminal.energy();
        console.log("Current energy after first feed:", currentEnergy);
        
        // Second feeding calculation
        uint256 energy2 = aminal.calculateEnergyForETH(secondAmount) - currentEnergy;
        console.log("\nSecond amount:", secondAmount);
        console.log("Energy from second:", energy2);
        console.log("Energy per ETH second:", (energy2 * 1e18) / secondAmount);
    }
}