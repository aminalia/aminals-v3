// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "src/AminalVRGDA.sol";

contract VRGDADebugTest is Test {
    AminalVRGDA vrgda;
    
    function setUp() public {
        vrgda = new AminalVRGDA(
            int256(1 ether),  
            0.01e18,
            10000e18,
            2000e18        
        );
    }
    
    function test_DebugVRGDACalculations() public view {
        console.log("Energy 0:", vrgda.getLoveMultiplier(0));
        console.log("Energy 10:", vrgda.getLoveMultiplier(10));
        console.log("Energy 100:", vrgda.getLoveMultiplier(100));
        console.log("Energy 1000:", vrgda.getLoveMultiplier(1000));
        console.log("Energy 10000:", vrgda.getLoveMultiplier(10000));
        console.log("Energy 100000:", vrgda.getLoveMultiplier(100000));
        console.log("Energy 1000000:", vrgda.getLoveMultiplier(1000000));
        console.log("Energy 10000000:", vrgda.getLoveMultiplier(10000000));
        console.log("Energy 100000000:", vrgda.getLoveMultiplier(100000000));
    }
}