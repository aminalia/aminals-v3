// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "src/AminalVRGDA.sol";

contract VRGDADebugTest is Test {
    AminalVRGDA vrgda;
    
    function setUp() public {
        vrgda = new AminalVRGDA(
            int256(1 ether),  
            0.05e18,
            100e18,
            10e18        
        );
    }
    
    function test_DebugVRGDACalculations() public view {
        console.log("=== VRGDA Love Multipliers ===");
        console.log("Energy 0 (0 ETH):", vrgda.getLoveMultiplier(0));
        console.log("Energy 5 (0.0005 ETH):", vrgda.getLoveMultiplier(5));
        console.log("Energy 10 (0.001 ETH):", vrgda.getLoveMultiplier(10));
        console.log("Energy 50 (0.005 ETH):", vrgda.getLoveMultiplier(50));
        console.log("Energy 100 (0.01 ETH):", vrgda.getLoveMultiplier(100));
        console.log("Energy 500 (0.05 ETH):", vrgda.getLoveMultiplier(500));
        console.log("Energy 1000 (0.1 ETH):", vrgda.getLoveMultiplier(1000));
        console.log("Energy 5000 (0.5 ETH):", vrgda.getLoveMultiplier(5000));
        console.log("Energy 10000 (1 ETH):", vrgda.getLoveMultiplier(10000));
        console.log("Energy 50000 (5 ETH):", vrgda.getLoveMultiplier(50000));
        console.log("Energy 100000 (10 ETH):", vrgda.getLoveMultiplier(100000));
        console.log("Energy 500000 (50 ETH):", vrgda.getLoveMultiplier(500000));
        console.log("Energy 1000000 (100 ETH):", vrgda.getLoveMultiplier(1000000));
        console.log("Energy 2000000 (200 ETH):", vrgda.getLoveMultiplier(2000000));
    }
}