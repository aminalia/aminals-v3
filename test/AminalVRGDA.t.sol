// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {Aminal} from "src/Aminal.sol";
import {AminalVRGDA} from "src/AminalVRGDA.sol";
import {ITraits} from "src/interfaces/ITraits.sol";
import {toWadUnsafe} from "lib/VRGDAs/lib/solmate/src/utils/SignedWadMath.sol";

contract AminalVRGDATest is Test {
    Aminal public aminal;
    AminalVRGDA public vrgda;
    
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");
    
    function setUp() public {
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
        aminal = new Aminal("TestAminal", "TAMINAL", "https://test.com/", traits);
        
        // Initialize the Aminal
        aminal.initialize("test-uri");
        
        // Get the VRGDA instance
        vrgda = aminal.vrgda();
        
        // Fund test users
        deal(user1, 10 ether);
        deal(user2, 10 ether);
    }
    
    function test_InitialEnergyIsZero() public {
        assertEq(aminal.energy(), 0);
        assertEq(aminal.feedingStartTime(), 0);
    }
    
    function test_FirstFeedingGivesFullEnergy() public {
        uint256 feedAmount = 0.01 ether;
        
        // Calculate expected energy before feeding
        uint256 expectedEnergy = aminal.calculateEnergyForETH(feedAmount);
        
        // First feeding should give approximately 100 energy for 0.01 ETH
        // (0.01 ETH / 0.0001 ETH per unit = 100 units)
        assertApproxEqAbs(expectedEnergy, 100, 1); // Energy is not scaled by 1e18
        
        // Feed the Aminal
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: feedAmount}("");
        assertTrue(success);
        
        // Check energy gained
        assertEq(aminal.energy(), expectedEnergy);
        assertGt(aminal.feedingStartTime(), 0);
    }
    
    function test_DiminishingReturnsOnSubsequentFeeding() public {
        // First feeding
        vm.startPrank(user1);
        uint256 firstFeedAmount = 0.1 ether;
        (bool success1,) = address(aminal).call{value: firstFeedAmount}("");
        assertTrue(success1);
        uint256 energyAfterFirst = aminal.energy();
        
        // Second feeding with same amount should give less energy
        uint256 secondFeedAmount = 0.1 ether;
        (bool success2,) = address(aminal).call{value: secondFeedAmount}("");
        assertTrue(success2);
        uint256 energyGainedSecond = aminal.energy() - energyAfterFirst;
        
        // Third feeding should give even less
        uint256 thirdFeedAmount = 0.1 ether;
        uint256 energyBeforeThird = aminal.energy();
        (bool success3,) = address(aminal).call{value: thirdFeedAmount}("");
        assertTrue(success3);
        uint256 energyGainedThird = aminal.energy() - energyBeforeThird;
        
        vm.stopPrank();
        
        // Each subsequent feeding should give less energy
        assertGt(energyAfterFirst, energyGainedSecond);
        assertGt(energyGainedSecond, energyGainedThird);
        
        console.log("First feeding energy:", energyAfterFirst);
        console.log("Second feeding energy gained:", energyGainedSecond);
        console.log("Third feeding energy gained:", energyGainedThird);
    }
    
    function test_EnergyConversionRateIncreases() public {
        // Check initial conversion rate
        uint256 initialRate = aminal.getCurrentEnergyConversionRate();
        assertEq(initialRate, 0.0001 ether);
        
        // Feed the Aminal
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 1 ether}("");
        assertTrue(success);
        
        // Conversion rate should increase (more ETH needed per energy)
        uint256 newRate = aminal.getCurrentEnergyConversionRate();
        assertGt(newRate, initialRate);
    }
    
    function test_TimeDecayReducesPrice() public {
        // Initial feeding
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 0.1 ether}("");
        assertTrue(success);
        
        uint256 rateAfterFeeding = aminal.getCurrentEnergyConversionRate();
        
        // Advance time by 1 day
        vm.warp(block.timestamp + 1 days);
        
        // Rate should decrease due to time decay (behind schedule)
        uint256 rateAfterDelay = aminal.getCurrentEnergyConversionRate();
        assertLt(rateAfterDelay, rateAfterFeeding);
    }
    
    function test_SqueakingAffectsConversionRate() public {
        // Feed to gain energy
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 0.5 ether}("");
        assertTrue(success);
        
        uint256 energyBefore = aminal.energy();
        uint256 rateBefore = aminal.getCurrentEnergyConversionRate();
        
        // Squeak to lose energy
        uint256 squeakAmount = energyBefore / 2;
        aminal.squeak(squeakAmount);
        
        // Energy should decrease and conversion rate should decrease too
        // (because VRGDA now uses current energy level)
        assertEq(aminal.energy(), energyBefore - squeakAmount);
        assertLt(aminal.getCurrentEnergyConversionRate(), rateBefore);
    }
    
    function testFuzz_EnergyCalculation(uint96 ethAmount) public {
        vm.assume(ethAmount > 0.00001 ether && ethAmount < 10 ether); // User only has 10 ETH
        
        // Calculate expected energy
        uint256 expectedEnergy = aminal.calculateEnergyForETH(ethAmount);
        
        // Feed the Aminal
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: ethAmount}("");
        assertTrue(success);
        
        // Actual energy should match expected
        assertEq(aminal.energy(), expectedEnergy);
    }
    
    function testFuzz_DiminishingReturns(uint96 firstAmount, uint96 secondAmount) public {
        vm.assume(firstAmount > 0.01 ether && firstAmount < 5 ether);
        vm.assume(secondAmount > 0.01 ether && secondAmount < 5 ether);
        
        // First feeding
        vm.prank(user1);
        (bool success1,) = address(aminal).call{value: firstAmount}("");
        assertTrue(success1);
        uint256 energyPerEthFirst = (aminal.energy() * 1e18) / firstAmount;
        
        // Second feeding
        vm.prank(user2);
        uint256 energyBefore = aminal.energy();
        (bool success2,) = address(aminal).call{value: secondAmount}("");
        assertTrue(success2);
        uint256 energyGained = aminal.energy() - energyBefore;
        uint256 energyPerEthSecond = (energyGained * 1e18) / secondAmount;
        
        // Energy per ETH should decrease, allowing for small rounding errors
        // We allow up to 0.1% increase due to integer division rounding
        uint256 allowedIncrease = energyPerEthFirst / 1000; // 0.1%
        assertLe(energyPerEthSecond, energyPerEthFirst + allowedIncrease);
    }
    
    function test_LoveTrackingWithVRGDA() public {
        uint256 feedAmount1 = 0.1 ether;
        uint256 feedAmount2 = 0.2 ether;
        
        // First user feeds
        vm.prank(user1);
        (bool success1,) = address(aminal).call{value: feedAmount1}("");
        assertTrue(success1);
        
        // Second user feeds
        vm.prank(user2);
        (bool success2,) = address(aminal).call{value: feedAmount2}("");
        assertTrue(success2);
        
        // Love tracking should still work normally (tracks ETH sent, not energy gained)
        assertEq(aminal.totalLove(), feedAmount1 + feedAmount2);
        assertEq(aminal.loveFromUser(user1), feedAmount1);
        assertEq(aminal.loveFromUser(user2), feedAmount2);
    }
    
    function test_MinimumEnergyGain() public {
        // Feed a large amount to drive up the price
        vm.prank(user1);
        (bool success1,) = address(aminal).call{value: 5 ether}("");
        assertTrue(success1);
        
        uint256 energyBefore = aminal.energy();
        
        // Even with high energy, sending ETH should give at least 1 energy
        vm.prank(user2);
        (bool success2,) = address(aminal).call{value: 1 wei}("");
        assertTrue(success2);
        
        // Should gain at least 1 energy unit
        assertGe(aminal.energy() - energyBefore, 1);
    }
}