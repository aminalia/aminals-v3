// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {AminalVRGDA} from "src/AminalVRGDA.sol";
import {toWadUnsafe, wadDiv} from "lib/VRGDAs/lib/solmate/src/utils/SignedWadMath.sol";

contract DebugLoveChange is Script {
    function run() public {
        AminalVRGDA vrgda = new AminalVRGDA(
            int256(0.5 ether), // Base price
            0.5e18,            // 50% decay
            10000e18           // 10000 energy units per "time unit"
        );
        
        console.log("Testing love at different energy levels:");
        
        // Test at various energy levels
        uint256[] memory energyLevels = new uint256[](5);
        energyLevels[0] = 0;
        energyLevels[1] = 10000;  // 1 time unit
        energyLevels[2] = 50000;  // 5 time units
        energyLevels[3] = 100000; // 10 time units
        energyLevels[4] = 200000; // 20 time units
        
        for (uint i = 0; i < energyLevels.length; i++) {
            uint256 energy = energyLevels[i];
            uint256 love = vrgda.getLoveForETH(energy, 1 ether);
            
            // Calculate effective time for debugging
            int256 effectiveTime = wadDiv(toWadUnsafe(energy), 10000e18);
            uint256 price = vrgda.getVRGDAPrice(effectiveTime, energy);
            
            console.log("Energy:", energy);
            console.log("  Effective time (WAD):", uint256(effectiveTime));
            console.log("  VRGDA price:", price);
            console.log("  Love for 1 ETH:", love);
            console.log("");
        }
    }
}