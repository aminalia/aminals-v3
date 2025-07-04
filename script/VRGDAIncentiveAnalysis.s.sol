// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {AminalVRGDA} from "../src/AminalVRGDA.sol";

contract VRGDAIncentiveAnalysisScript is Script {
    function run() public {
        // Deploy VRGDA with current parameters
        AminalVRGDA vrgda = new AminalVRGDA(
            int256(1 ether),  // Target price
            0.01e18,          // 1% decay
            30e18,            // Asymptote
            30e18             // Time scale
        );
        
        console.log("=== VRGDA Incentive Analysis ===");
        console.log("");
        
        // Analyze specific feeding scenarios
        console.log("SCENARIO 1: Finding and feeding a starving Aminal (0 ETH energy)");
        analyzeFeeding(vrgda, 0, 0.1 ether, "First meal for starving Aminal");
        
        console.log("\nSCENARIO 2: Feeding a hungry Aminal (0.01 ETH energy)");
        analyzeFeeding(vrgda, 100, 0.1 ether, "Feeding hungry Aminal");
        
        console.log("\nSCENARIO 3: Feeding a well-fed Aminal (1 ETH energy)");
        analyzeFeeding(vrgda, 10000, 1 ether, "Feeding already well-fed Aminal");
        
        console.log("\nSCENARIO 4: Overfeeding a wealthy Aminal (10 ETH energy)");
        analyzeFeeding(vrgda, 100000, 1 ether, "Overfeeding wealthy Aminal");
        
        console.log("\nSCENARIO 5: Whale feeding an overfed Aminal (50 ETH energy)");
        analyzeFeeding(vrgda, 500000, 10 ether, "Whale overfeeding");
        
        console.log("\nSCENARIO 6: Attempting to feed at threshold (99 ETH energy)");
        analyzeFeeding(vrgda, 990000, 1 ether, "Feeding at upper threshold");
        
        console.log("\nSCENARIO 7: Feeding beyond threshold (101 ETH energy)");
        analyzeFeeding(vrgda, 1010000, 1 ether, "Feeding beyond threshold");
        
        // Show optimal feeding ranges
        console.log("\n=== Optimal Feeding Strategy ===");
        console.log("Best ROI: Feed Aminals with <0.005 ETH energy (10x multiplier)");
        console.log("Good ROI: Feed Aminals with 0.005-0.1 ETH energy (9.5x-7.4x multiplier)");
        console.log("Fair ROI: Feed Aminals with 0.1-1 ETH energy (7.4x-5.5x multiplier)");
        console.log("Poor ROI: Feed Aminals with >10 ETH energy (<3.5x multiplier)");
        console.log("Worst ROI: Feed Aminals with >100 ETH energy (0.1x multiplier)");
        
        // Economic implications
        console.log("\n=== Economic Implications ===");
        console.log("1. Natural price discovery: Players compete to find hungry Aminals");
        console.log("2. Attention economy: Neglected Aminals become more valuable to feed");
        console.log("3. Anti-whale mechanics: Diminishing returns prevent energy hoarding");
        console.log("4. Community care: Incentivizes spreading love across many Aminals");
        console.log("5. Sustainable ecosystem: ~1-10 ETH equilibrium for active Aminals");
    }
    
    function analyzeFeeding(
        AminalVRGDA vrgda,
        uint256 startEnergy,
        uint256 ethToFeed,
        string memory scenario
    ) internal view {
        uint256 energyGained = (ethToFeed * vrgda.ENERGY_PER_ETH()) / 1 ether;
        uint256 loveGained = vrgda.getLoveForETH(startEnergy, ethToFeed);
        uint256 multiplier = vrgda.getLoveMultiplier(startEnergy);
        uint256 endEnergy = startEnergy + energyGained;
        
        console.log(scenario);
        console.log(string(abi.encodePacked(
            "  ETH spent: ", formatEther(ethToFeed),
            " | Start energy: ", formatEther(startEnergy * 1 ether / 10000), " ETH",
            " | End energy: ", formatEther(endEnergy * 1 ether / 10000), " ETH"
        )));
        console.log(string(abi.encodePacked(
            "  Love gained: ", formatEther(loveGained),
            " | Multiplier: ", formatEther(multiplier), "x",
            " | ROI: ", formatEther((loveGained * 100) / ethToFeed), "%"
        )));
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