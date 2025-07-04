// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {AminalVRGDA} from "../src/AminalVRGDA.sol";

contract VRGDACurveDataScript is Script {
    function run() public {
        // Deploy VRGDA with current parameters
        AminalVRGDA vrgda = new AminalVRGDA(
            int256(1 ether),  // Target price
            0.05e18,          // 5% decay
            100e18,           // Asymptote
            10e18             // Time scale
        );
        
        // Create CSV header (overwrite existing file)
        vm.writeFile("script/vrgda_curve_data.csv", "eth_amount,energy,love_multiplier,love_per_eth\n");
        
        // Test points from 0.0001 ETH to 200 ETH
        uint256[] memory ethAmounts = new uint256[](50);
        
        // Logarithmic scale for better coverage
        ethAmounts[0] = 0.0001 ether;
        ethAmounts[1] = 0.0002 ether;
        ethAmounts[2] = 0.0005 ether;
        ethAmounts[3] = 0.001 ether;  // Lower threshold
        ethAmounts[4] = 0.002 ether;
        ethAmounts[5] = 0.005 ether;
        ethAmounts[6] = 0.01 ether;
        ethAmounts[7] = 0.02 ether;
        ethAmounts[8] = 0.05 ether;
        ethAmounts[9] = 0.1 ether;
        ethAmounts[10] = 0.2 ether;
        ethAmounts[11] = 0.5 ether;
        ethAmounts[12] = 1 ether;
        ethAmounts[13] = 2 ether;
        ethAmounts[14] = 5 ether;
        ethAmounts[15] = 10 ether;
        ethAmounts[16] = 20 ether;
        ethAmounts[17] = 50 ether;
        ethAmounts[18] = 100 ether;  // Upper threshold
        ethAmounts[19] = 150 ether;
        ethAmounts[20] = 200 ether;
        
        // Add more granular points around thresholds
        ethAmounts[21] = 0.0008 ether;
        ethAmounts[22] = 0.0009 ether;
        ethAmounts[23] = 0.0011 ether;
        ethAmounts[24] = 0.0012 ether;
        ethAmounts[25] = 80 ether;
        ethAmounts[26] = 90 ether;
        ethAmounts[27] = 95 ether;
        ethAmounts[28] = 99 ether;
        ethAmounts[29] = 101 ether;
        ethAmounts[30] = 105 ether;
        ethAmounts[31] = 110 ether;
        ethAmounts[32] = 120 ether;
        
        // Fill remaining with intermediate values
        ethAmounts[33] = 0.003 ether;
        ethAmounts[34] = 0.004 ether;
        ethAmounts[35] = 0.006 ether;
        ethAmounts[36] = 0.007 ether;
        ethAmounts[37] = 0.008 ether;
        ethAmounts[38] = 0.009 ether;
        ethAmounts[39] = 0.03 ether;
        ethAmounts[40] = 0.04 ether;
        ethAmounts[41] = 0.06 ether;
        ethAmounts[42] = 0.07 ether;
        ethAmounts[43] = 0.08 ether;
        ethAmounts[44] = 0.09 ether;
        ethAmounts[45] = 0.3 ether;
        ethAmounts[46] = 0.4 ether;
        ethAmounts[47] = 0.6 ether;
        ethAmounts[48] = 0.7 ether;
        ethAmounts[49] = 0.8 ether;
        
        // Sort array (bubble sort for simplicity)
        for (uint i = 0; i < ethAmounts.length - 1; i++) {
            for (uint j = 0; j < ethAmounts.length - i - 1; j++) {
                if (ethAmounts[j] > ethAmounts[j + 1]) {
                    uint256 temp = ethAmounts[j];
                    ethAmounts[j] = ethAmounts[j + 1];
                    ethAmounts[j + 1] = temp;
                }
            }
        }
        
        // Calculate and output data
        for (uint i = 0; i < ethAmounts.length; i++) {
            uint256 ethAmount = ethAmounts[i];
            uint256 energy = (ethAmount * vrgda.ENERGY_PER_ETH()) / 1 ether;
            
            // Get love multiplier - handle the threshold at 1M energy
            uint256 loveMultiplier;
            if (energy >= 1000000) {
                loveMultiplier = 0.1 ether; // Above threshold, fixed at 0.1x
            } else {
                loveMultiplier = vrgda.getLoveMultiplier(energy);
            }
            
            uint256 lovePerEth = (loveMultiplier * 1 ether) / 1 ether;
            
            // Format: eth_amount, energy, love_multiplier, love_per_eth
            string memory line = string(abi.encodePacked(
                formatEther(ethAmount), ",",
                vm.toString(energy), ",",
                formatEther(loveMultiplier), ",",
                formatEther(lovePerEth)
            ));
            
            vm.writeLine("script/vrgda_curve_data.csv", line);
            
            // Also log to console for visibility
            console.log(string(abi.encodePacked("ETH: ", formatEther(ethAmount), " Energy: ", vm.toString(energy), " Multiplier: ", formatEther(loveMultiplier))));
        }
        
        console.log("");
        console.log("Data written to script/vrgda_curve_data.csv");
        console.log("Columns: eth_amount, energy, love_multiplier, love_per_eth");
    }
    
    // Helper function to format wei to ether string
    function formatEther(uint256 weiAmount) internal pure returns (string memory) {
        uint256 whole = weiAmount / 1 ether;
        uint256 decimal = (weiAmount % 1 ether) / 1e14; // 4 decimal places
        
        if (decimal == 0) {
            return vm.toString(whole);
        }
        
        // Format decimal part with leading zeros if needed
        string memory decimalStr = vm.toString(decimal);
        while (bytes(decimalStr).length < 4) {
            decimalStr = string(abi.encodePacked("0", decimalStr));
        }
        
        // Remove trailing zeros
        bytes memory decBytes = bytes(decimalStr);
        uint256 end = decBytes.length;
        while (end > 0 && decBytes[end - 1] == '0') {
            end--;
        }
        
        if (end == 0) {
            return vm.toString(whole);
        }
        
        bytes memory trimmed = new bytes(end);
        for (uint i = 0; i < end; i++) {
            trimmed[i] = decBytes[i];
        }
        
        return string(abi.encodePacked(vm.toString(whole), ".", trimmed));
    }
}