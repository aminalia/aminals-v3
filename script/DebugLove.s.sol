// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {AminalVRGDA} from "src/AminalVRGDA.sol";

contract DebugLove is Script {
    function run() public {
        AminalVRGDA vrgda = new AminalVRGDA(
            1e18,     // 1:1 love to ETH ratio at target
            0.5e18,   // 50% decay
            100000e18 // Target energy level
        );
        
        console.log("Target price:", uint256(vrgda.targetPrice()));
        
        // Test at 0 energy
        uint256 love0 = vrgda.getLoveForETH(0, 1 ether);
        console.log("Love at 0 energy for 1 ETH:", love0);
        
        // Test at 50k energy
        uint256 love50k = vrgda.getLoveForETH(50000, 1 ether);
        console.log("Love at 50k energy for 1 ETH:", love50k);
        
        // Test at 100k energy (target)
        uint256 love100k = vrgda.getLoveForETH(100000, 1 ether);
        console.log("Love at 100k energy for 1 ETH:", love100k);
        
        // Check VRGDA price directly
        uint256 price0 = vrgda.getVRGDAPrice(0, 0);
        console.log("VRGDA price at 0,0:", price0);
    }
}