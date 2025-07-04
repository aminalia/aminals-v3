// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "src/AminalVRGDA.sol";

contract VRGDACurveTest is Test {
    AminalVRGDA vrgda;
    
    function setUp() public {
        vrgda = new AminalVRGDA(
            int256(1 ether),  
            0.05e18,
            100e18,
            10e18        
        );
    }
    
    function test_VRGDACurveModerateMultipliers() public view {
        console.log("=== VRGDA Love Multipliers (Moderate Range) ===");
        
        // Below threshold - should be 10x
        uint256 mult0 = vrgda.getLoveMultiplier(0);
        console.log("Energy 0 (0 ETH):", mult0);
        assertEq(mult0, 10 ether, "Should be 10x at 0 energy");
        
        uint256 mult5 = vrgda.getLoveMultiplier(5);
        console.log("Energy 5 (0.0005 ETH):", mult5);
        assertEq(mult5, 10 ether, "Should be 10x at 5 energy");
        
        // At threshold - should be close to 10x
        uint256 mult10 = vrgda.getLoveMultiplier(10);
        console.log("Energy 10 (0.001 ETH):", mult10);
        assertApproxEqAbs(mult10, 10 ether, 0.01 ether, "Should be ~10x at threshold");
        
        // In VRGDA range - should decrease smoothly
        uint256 mult1k = vrgda.getLoveMultiplier(1000);
        console.log("Energy 1000 (0.1 ETH):", mult1k);
        assertLt(mult1k, 10 ether, "Should be less than 10x");
        assertGt(mult1k, 0.1 ether, "Should be more than 0.1x");
        
        uint256 mult10k = vrgda.getLoveMultiplier(10000);
        console.log("Energy 10000 (1 ETH):", mult10k);
        assertLt(mult10k, mult1k, "Should decrease as energy increases");
        
        uint256 mult100k = vrgda.getLoveMultiplier(100000);
        console.log("Energy 100000 (10 ETH):", mult100k);
        assertLt(mult100k, mult10k, "Should continue decreasing");
        
        uint256 mult500k = vrgda.getLoveMultiplier(500000);
        console.log("Energy 500000 (50 ETH):", mult500k);
        assertLt(mult500k, mult100k, "Should approach minimum");
        
        // At upper threshold - should be 0.1x
        uint256 mult1M = vrgda.getLoveMultiplier(1000000);
        console.log("Energy 1000000 (100 ETH):", mult1M);
        assertEq(mult1M, 0.1 ether, "Should be 0.1x at upper threshold");
        
        // Above threshold - should be 0.1x
        uint256 mult2M = vrgda.getLoveMultiplier(2000000);
        console.log("Energy 2000000 (200 ETH):", mult2M);
        assertEq(mult2M, 0.1 ether, "Should be 0.1x above threshold");
    }
}