// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AminalTestBase} from "../../base/AminalTestBase.sol";
import {TestHelpers} from "../../helpers/TestHelpers.sol";

/**
 * @title AminalLoveEnergyTest
 * @notice Tests love and energy mechanics including VRGDA calculations
 */
contract AminalLoveEnergyTest is AminalTestBase {
    using TestHelpers for *;
    
    // Events
    event LoveReceived(address indexed from, uint256 amount, uint256 totalLove);
    event EnergyGained(address indexed from, uint256 amount, uint256 newEnergy);
    
    // Test data structures
    struct Threshold {
        uint256 energy;
        uint256 feedAmount;
        uint256 minMultiplier;
        uint256 maxMultiplier;
    }
    
    function setUp() public override {
        super.setUp();
        _initializeAminal(aminal, "love-energy-test.json");
    }
    
    function test_ReceiveLove() public {
        // Arrange
        uint256 ethAmount = 1 ether;
        uint256 expectedEnergy = TestHelpers.ENERGY_PER_ETH;
        uint256 expectedLove = 100000; // 10,000 base × 10x multiplier at 0 energy
        
        // Assert initial state
        assertEq(aminal.totalLove(), 0);
        assertEq(aminal.loveFromUser(user1), 0);
        assertEq(aminal.energy(), 0);
        assertEq(address(aminal).balance, 0);
        
        // Act
        vm.expectEmit(true, false, false, true);
        emit LoveReceived(user1, expectedLove, expectedLove);
        vm.expectEmit(true, false, false, true);
        emit EnergyGained(user1, expectedEnergy, expectedEnergy);
        
        _feedAminal(user1, aminal, ethAmount);
        
        // Assert
        assertEq(aminal.totalLove(), expectedLove);
        assertEq(aminal.loveFromUser(user1), expectedLove);
        assertEq(aminal.energy(), expectedEnergy);
        assertEq(address(aminal).balance, ethAmount);
    }
    
    function test_LoveDiminishingReturns() public {
        // Feed multiple times to test VRGDA curve
        uint256[] memory feedAmounts = new uint256[](3);
        feedAmounts[0] = TestHelpers.SMALL_FEED;
        feedAmounts[1] = TestHelpers.MEDIUM_FEED;
        feedAmounts[2] = TestHelpers.LARGE_FEED;
        
        uint256 previousLovePerEth = type(uint256).max;
        
        for (uint i = 0; i < feedAmounts.length; i++) {
            uint256 loveBefore = aminal.loveFromUser(user1);
            uint256 energyBefore = aminal.energy();
            
            _feedAminal(user1, aminal, feedAmounts[i]);
            
            uint256 loveGained = aminal.loveFromUser(user1) - loveBefore;
            uint256 lovePerEth = (loveGained * 1 ether) / feedAmounts[i];
            
            // Assert diminishing returns
            assertLt(lovePerEth, previousLovePerEth, "Love per ETH should decrease");
            previousLovePerEth = lovePerEth;
            
            // Energy should always be fixed rate
            uint256 energyGained = aminal.energy() - energyBefore;
            assertEq(energyGained, (feedAmounts[i] * TestHelpers.ENERGY_PER_ETH) / 1 ether);
        }
    }
    
    function test_MultipleUsersFeeding() public {
        // Arrange
        address[3] memory users = [user1, user2, user3];
        uint256[3] memory amounts = [
            TestHelpers.SMALL_FEED,
            TestHelpers.MEDIUM_FEED,
            TestHelpers.LARGE_FEED
        ];
        
        uint256 totalExpectedEnergy = 0;
        uint256 totalLove = 0;
        
        // Act
        for (uint i = 0; i < users.length; i++) {
            uint256 expectedLove = aminal.calculateLoveForETH(amounts[i]);
            _feedAminal(users[i], aminal, amounts[i]);
            
            totalExpectedEnergy += (amounts[i] * TestHelpers.ENERGY_PER_ETH) / 1 ether;
            totalLove += expectedLove;
            
            // Assert individual user love
            assertEq(aminal.loveFromUser(users[i]), expectedLove);
        }
        
        // Assert totals
        assertEq(aminal.energy(), totalExpectedEnergy);
        assertEq(aminal.totalLove(), totalLove);
        assertEq(address(aminal).balance, amounts[0] + amounts[1] + amounts[2]);
    }
    
    function test_ZeroValueFeeding() public {
        // Act
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 0}("");
        
        // Assert
        assertTrue(success);
        assertEq(aminal.totalLove(), 0);
        assertEq(aminal.loveFromUser(user1), 0);
        assertEq(aminal.energy(), 0);
    }
    
    function test_LoveMultiplierRanges() public {
        // Test key energy thresholds
        
        Threshold[4] memory thresholds = [
            // Starving: <0.001 ETH energy, ~10x multiplier
            Threshold(0, TestHelpers.SMALL_FEED, 9 * 1e18, 10 * 1e18),
            // Fed: 0.1-1 ETH energy, ~5.5-7.4x multiplier  
            Threshold(1000, TestHelpers.SMALL_FEED, 5 * 1e18, 10 * 1e18),
            // Well-fed: 1-10 ETH energy, ~3.5-5.5x multiplier
            Threshold(10000, TestHelpers.SMALL_FEED, 3 * 1e18, 9 * 1e18),
            // Overfed: >10 ETH energy, <3.5x multiplier
            Threshold(100000, TestHelpers.SMALL_FEED, 0.1 * 1e18, 8.5 * 1e18)
        ];
        
        for (uint i = 0; i < thresholds.length; i++) {
            // Create new Aminal for each test
            aminal = _createDefaultAminal();
            _initializeAminal(aminal, "threshold-test.json");
            
            // Reset user1's balance for each test
            vm.deal(user1, 20 ether);
            
            // Set up initial energy if needed
            if (thresholds[i].energy > 0) {
                uint256 setupAmount = (thresholds[i].energy * 1 ether) / TestHelpers.ENERGY_PER_ETH;
                // Deal more ETH if needed for setup
                if (setupAmount > 20 ether) {
                    vm.deal(user1, setupAmount + 1 ether);
                }
                _feedAminal(user1, aminal, setupAmount);
            }
            
            // Calculate love for feed amount
            uint256 love = aminal.calculateLoveForETH(thresholds[i].feedAmount);
            uint256 multiplier = (love * 1e18) / ((thresholds[i].feedAmount * TestHelpers.ENERGY_PER_ETH) / 1 ether);
            
            // Assert multiplier is in expected range
            assertGe(multiplier, thresholds[i].minMultiplier, "Multiplier too low");
            assertLe(multiplier, thresholds[i].maxMultiplier, "Multiplier too high");
        }
    }
    
    // ========== Fuzz Tests ==========
    
    function testFuzz_ReceiveLove(uint96 amount) public {
        // Bound to reasonable amounts
        amount = uint96(bound(amount, 0.001 ether, 10 ether));
        
        // Act
        _feedAminal(user1, aminal, amount);
        
        // Assert
        uint256 expectedEnergy = (uint256(amount) * TestHelpers.ENERGY_PER_ETH) / 1 ether;
        assertEq(aminal.energy(), expectedEnergy);
        assertGt(aminal.loveFromUser(user1), 0);
        assertEq(address(aminal).balance, amount);
    }
    
    function testFuzz_LoveAlwaysPositive(uint96 amount, uint96 initialEnergy) public {
        // Bound inputs
        amount = uint96(bound(amount, 0.001 ether, 10 ether)); // Max 10 ETH since that's what users have
        initialEnergy = uint96(bound(initialEnergy, 0, 1000000)); // Up to 100 ETH worth
        
        // Setup initial energy
        if (initialEnergy > 0) {
            uint256 setupAmount = (uint256(initialEnergy) * 1 ether) / TestHelpers.ENERGY_PER_ETH;
            // Skip if setup would require too much ETH
            vm.assume(setupAmount <= 50 ether);
            // Deal more ETH to user2 if needed
            vm.deal(user2, setupAmount + 1 ether);
            _feedAminal(user2, aminal, setupAmount);
        }
        
        // Act
        _feedAminal(user1, aminal, amount);
        
        // Assert love is always positive
        assertGt(aminal.loveFromUser(user1), 0, "Love should always be positive");
    }
}