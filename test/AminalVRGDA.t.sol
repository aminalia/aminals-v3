// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {Aminal} from "src/Aminal.sol";
import {AminalVRGDA} from "src/AminalVRGDA.sol";
import {ITraits} from "src/interfaces/ITraits.sol";

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
        deal(user1, 20 ether);
        deal(user2, 2000 ether);
    }
    
    function test_InitialEnergyIsZero() public view {
        assertEq(aminal.energy(), 0);
    }
    
    function test_FixedEnergyGainPerETH() public {
        uint256 feedAmount = 0.5 ether;
        uint256 expectedEnergy = (feedAmount * vrgda.ENERGY_PER_ETH()) / 1 ether; // Should be 5000
        
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: feedAmount}("");
        assertTrue(success);
        
        assertEq(aminal.energy(), expectedEnergy);
        assertEq(aminal.energy(), 5000); // 0.5 ETH * 10000 = 5000 energy
    }
    
    function test_LoveVariesBasedOnEnergy() public {
        // At 0 energy, should get bonus love (more than ETH sent)
        uint256 feedAmount1 = 0.1 ether;
        uint256 expectedLove1 = aminal.calculateLoveForETH(feedAmount1);
        
        vm.prank(user1);
        (bool success1,) = address(aminal).call{value: feedAmount1}("");
        assertTrue(success1);
        
        // At 0 energy, love should be 10x base units (maximum multiplier)
        uint256 expectedLoveAtZero = (feedAmount1 * vrgda.ENERGY_PER_ETH() * 10) / 1 ether;
        assertEq(aminal.totalLove(), expectedLoveAtZero);
        assertEq(aminal.totalLove(), expectedLove1);
        
        // Feed more to increase energy significantly  
        vm.prank(user1);
        (bool success2,) = address(aminal).call{value: 5 ether}("");
        assertTrue(success2);
        
        uint256 totalLoveBefore = aminal.totalLove();
        uint256 energyBefore = aminal.energy();
        
        // Now with higher energy, love per ETH should be less
        uint256 feedAmount2 = 0.1 ether;
        uint256 expectedLove2 = aminal.calculateLoveForETH(feedAmount2);
        
        vm.prank(user2);
        (bool success3,) = address(aminal).call{value: feedAmount2}("");
        assertTrue(success3);
        
        uint256 loveGained = aminal.totalLove() - totalLoveBefore;
        
        // Love gained should be less than or equal to the first feeding for same ETH amount
        assertLe(loveGained, expectedLove1);
        assertEq(loveGained, expectedLove2);
        assertLe(loveGained, feedAmount2 * 10); // Should be less than or equal to 10x
        
        // But energy gain should be the same
        uint256 energyGained = aminal.energy() - energyBefore;
        assertEq(energyGained, 1000); // 0.1 ETH * 10000 = 1000 energy
    }
    
    function test_LoveMultiplierDecreasesWithEnergy() public {
        // Check initial love multiplier at 0 energy
        uint256 initialMultiplier = aminal.getCurrentLoveMultiplier();
        
        // At 0 energy, love multiplier should be at maximum (100,000 units for 1 ETH)
        assertEq(initialMultiplier, 100000); // 10,000 base * 10x
        
        // Feed small amount first to get just above threshold
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 0.01 ether}("");
        assertTrue(success);
        
        // Love multiplier should decrease from 100x to something lower
        uint256 newMultiplier = aminal.getCurrentLoveMultiplier();
        assertLt(newMultiplier, initialMultiplier);
        assertLt(newMultiplier, 100000); // Less than 10x multiplier
        
        // Feed much more to reach high energy threshold
        vm.prank(user2);
        (bool success2,) = address(aminal).call{value: 1001 ether}("");
        assertTrue(success2);
        
        // At >1M energy, multiplier should be at minimum (1,000 units for 1 ETH)
        uint256 highEnergyMultiplier = aminal.getCurrentLoveMultiplier();
        assertEq(highEnergyMultiplier, 1000); // 10,000 base * 0.1x
    }
    
    function test_SqueakingImprovesLoveMultiplier() public {
        // Feed to gain energy
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 2 ether}("");
        assertTrue(success);
        
        uint256 multiplierWithHighEnergy = aminal.getCurrentLoveMultiplier();
        
        // Squeak to reduce energy (need to use user1 who has love)
        uint256 squeakAmount = aminal.energy() / 2;
        vm.prank(user1);
        aminal.squeak(squeakAmount);
        
        // Love multiplier should improve (increase) when energy is lower
        uint256 multiplierWithLowEnergy = aminal.getCurrentLoveMultiplier();
        assertGe(multiplierWithLowEnergy, multiplierWithHighEnergy);
    }
    
    function testFuzz_FixedEnergyGain(uint96 ethAmount) public {
        vm.assume(ethAmount > 0.00001 ether && ethAmount < 10 ether);
        
        uint256 expectedEnergy = (ethAmount * vrgda.ENERGY_PER_ETH()) / 1 ether;
        
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: ethAmount}("");
        assertTrue(success);
        
        assertEq(aminal.energy(), expectedEnergy);
    }
    
    function testFuzz_LoveDiminishingReturns(uint96 firstAmount, uint96 secondAmount) public {
        vm.assume(firstAmount > 0.01 ether && firstAmount < 10 ether);
        vm.assume(secondAmount > 0.01 ether && secondAmount < 10 ether);
        
        // First feeding at low energy
        vm.prank(user1);
        (bool success1,) = address(aminal).call{value: firstAmount}("");
        assertTrue(success1);
        uint256 lovePerEthFirst = (aminal.totalLove() * 1e18) / firstAmount;
        
        // Second feeding at higher energy
        vm.prank(user2);
        uint256 loveBefore = aminal.totalLove();
        (bool success2,) = address(aminal).call{value: secondAmount}("");
        assertTrue(success2);
        uint256 loveGained = aminal.totalLove() - loveBefore;
        uint256 lovePerEthSecond = (loveGained * 1e18) / secondAmount;
        
        // Love per ETH should decrease with higher energy
        // Allow 1% tolerance for rounding
        uint256 allowedIncrease = lovePerEthFirst / 100;
        assertLe(lovePerEthSecond, lovePerEthFirst + allowedIncrease);
    }
    
    function test_LoveTrackingPerUser() public {
        uint256 feedAmount1 = 0.1 ether;
        uint256 feedAmount2 = 0.2 ether;
        
        // Calculate expected love for each feeding
        uint256 expectedLove1 = aminal.calculateLoveForETH(feedAmount1);
        
        // First user feeds
        vm.prank(user1);
        (bool success1,) = address(aminal).call{value: feedAmount1}("");
        assertTrue(success1);
        
        // Calculate expected love for second feeding (at higher energy)
        uint256 expectedLove2 = aminal.calculateLoveForETH(feedAmount2);
        
        // Second user feeds
        vm.prank(user2);
        (bool success2,) = address(aminal).call{value: feedAmount2}("");
        assertTrue(success2);
        
        // Check individual love tracking
        assertEq(aminal.loveFromUser(user1), expectedLove1);
        assertEq(aminal.loveFromUser(user2), expectedLove2);
        assertEq(aminal.totalLove(), expectedLove1 + expectedLove2);
        
        // Energy should be fixed based on ETH sent
        uint256 expectedTotalEnergy = ((feedAmount1 + feedAmount2) * vrgda.ENERGY_PER_ETH()) / 1 ether;
        assertEq(aminal.energy(), expectedTotalEnergy);
    }
    
    function test_MinimumLoveGain() public {
        // Feed a large amount to get high energy
        vm.prank(user1);
        (bool success1,) = address(aminal).call{value: 9 ether}("");
        assertTrue(success1);
        
        uint256 loveBefore = aminal.totalLove();
        uint256 energyBefore = aminal.energy();
        
        // Even with high energy, sending ETH should give some love
        vm.prank(user2);
        (bool success2,) = address(aminal).call{value: 0.001 ether}("");
        assertTrue(success2);
        
        // Should gain some love
        assertGt(aminal.totalLove(), loveBefore);
        
        // Energy gain should be fixed
        uint256 energyGained = aminal.energy() - energyBefore;
        assertEq(energyGained, 10); // 0.001 ETH * 10000 = 10 energy
    }
    
    function test_ZeroEnergyMaximumLove() public {
        // At 0 energy, love multiplier should be at maximum
        uint256 multiplierAtZero = aminal.getCurrentLoveMultiplier();
        assertEq(multiplierAtZero, 100000); // 10x multiplier
        
        // Feed a larger amount to ensure we have enough love
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 0.1 ether}("");
        assertTrue(success);
        
        // Multiplier should decrease or stay roughly the same
        uint256 multiplierAfterFeeding = aminal.getCurrentLoveMultiplier();
        assertLe(multiplierAfterFeeding, multiplierAtZero);
        
        // Squeak all energy back to 0 (use user1 who has love)
        uint256 currentEnergy = aminal.energy();
        uint256 userLove = aminal.loveFromUser(user1);
        
        // Only squeak what we can afford (min of energy and love)
        uint256 squeakAmount = currentEnergy < userLove ? currentEnergy : userLove;
        
        vm.prank(user1);
        aminal.squeak(squeakAmount);
        assertEq(aminal.energy(), 0);
        
        // Multiplier should be back to maximum
        uint256 multiplierBackAtZero = aminal.getCurrentLoveMultiplier();
        assertEq(multiplierBackAtZero, multiplierAtZero);
    }
}