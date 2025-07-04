// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {AminalVRGDA} from "../src/AminalVRGDA.sol";
import {toWadUnsafe} from "lib/VRGDAs/lib/solmate/src/utils/SignedWadMath.sol";

contract VRGDADebugPriceScript is Script {
    function run() public {
        // Deploy VRGDA with current parameters
        AminalVRGDA vrgda = new AminalVRGDA(
            int256(1 ether),  // Target price
            0.05e18,          // 5% decay
            100e18,           // Asymptote
            10e18             // Time scale
        );
        
        console.log("=== VRGDA Price Debug ===");
        console.log("Target Price: 1 ETH");
        console.log("");
        
        // Test key energy levels
        uint256[] memory energyLevels = new uint256[](10);
        energyLevels[0] = 10;       // 0.001 ETH
        energyLevels[1] = 100;      // 0.01 ETH
        energyLevels[2] = 1000;     // 0.1 ETH
        energyLevels[3] = 10000;    // 1 ETH
        energyLevels[4] = 50000;    // 5 ETH
        energyLevels[5] = 100000;   // 10 ETH
        energyLevels[6] = 200000;   // 20 ETH
        energyLevels[7] = 500000;   // 50 ETH
        energyLevels[8] = 900000;   // 90 ETH
        energyLevels[9] = 990000;   // 99 ETH
        
        for (uint i = 0; i < energyLevels.length; i++) {
            uint256 energy = energyLevels[i];
            uint256 scaledEnergy = energy / 10000; // Scale as in AminalVRGDA
            
            // Get VRGDA price
            uint256 vrgdaPrice = vrgda.getVRGDAPrice(toWadUnsafe(scaledEnergy), scaledEnergy);
            
            // Calculate price ratio
            uint256 priceRatio = (vrgdaPrice * 100) / 1 ether; // Percentage of target
            
            console.log(
                string(abi.encodePacked(
                    "Energy: ", vm.toString(energy),
                    " (", formatEther(energy * 1 ether / 10000), " ETH)",
                    " => VRGDA Price: ", formatEther(vrgdaPrice),
                    " ETH (", vm.toString(priceRatio), "% of target)"
                ))
            );
        }
    }
    
    function formatEther(uint256 weiAmount) internal pure returns (string memory) {
        uint256 whole = weiAmount / 1 ether;
        uint256 decimal = (weiAmount % 1 ether) / 1e14; // 4 decimal places
        
        if (decimal == 0) {
            return vm.toString(whole);
        }
        
        string memory decimalStr = vm.toString(decimal);
        while (bytes(decimalStr).length < 4) {
            decimalStr = string(abi.encodePacked("0", decimalStr));
        }
        
        return string(abi.encodePacked(vm.toString(whole), ".", decimalStr));
    }
}