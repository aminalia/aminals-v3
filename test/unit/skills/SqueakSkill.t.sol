// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SkillTestBase} from "../../base/SkillTestBase.sol";
import {SqueakSkill} from "src/skills/SqueakSkill.sol";
import {Aminal} from "src/Aminal.sol";
import {TestHelpers} from "../../helpers/TestHelpers.sol";

/**
 * @title SqueakSkillTest
 * @notice Tests for the SqueakSkill implementation
 */
contract SqueakSkillTest is SkillTestBase {
    using TestHelpers for *;
    
    SqueakSkill public squeakSkill;
    
    function setUp() public override {
        super.setUp();
        squeakSkill = new SqueakSkill();
    }
    
    function test_BasicSqueak() public {
        // Arrange
        uint256 squeakAmount = 1000;
        (uint256 loveBefore, uint256 energyBefore) = _getLoveAndEnergy(user1, aminal);
        
        // Act
        _expectSkillEvent(user1, address(squeakSkill), squeakAmount, SqueakSkill.squeak.selector);
        _useSkill(
            user1,
            aminal,
            address(squeakSkill),
            abi.encodeWithSelector(SqueakSkill.squeak.selector, squeakAmount)
        );
        
        // Assert
        (uint256 loveAfter, uint256 energyAfter) = _getLoveAndEnergy(user1, aminal);
        _assertSkillCost(energyBefore, energyAfter, loveBefore, loveAfter, squeakAmount);
    }
    
    function test_SqueakWithDifferentAmounts() public {
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 100;    // Small squeak
        amounts[1] = 1000;   // Medium squeak  
        amounts[2] = 5000;   // Large squeak
        
        for (uint i = 0; i < amounts.length; i++) {
            // Get fresh state
            (uint256 loveBefore, uint256 energyBefore) = _getLoveAndEnergy(user1, aminal);
            
            // Squeak
            _useSkill(
                user1,
                aminal,
                address(squeakSkill),
                abi.encodeWithSelector(SqueakSkill.squeak.selector, amounts[i])
            );
            
            // Verify exact cost
            (uint256 loveAfter, uint256 energyAfter) = _getLoveAndEnergy(user1, aminal);
            assertEq(loveBefore - loveAfter, amounts[i], "Love cost mismatch");
            assertEq(energyBefore - energyAfter, amounts[i], "Energy cost mismatch");
        }
    }
    
    function test_MultipleUsersSqueak() public {
        // Feed user3 as well since setUp only feeds user1 and user2
        _feedAminal(user3, aminal, 1 ether);
        
        address[3] memory users = [user1, user2, user3];
        uint256 squeakAmount = 500;
        
        for (uint i = 0; i < users.length; i++) {
            // Each user squeaks
            _useSkill(
                users[i],
                aminal,
                address(squeakSkill),
                abi.encodeWithSelector(SqueakSkill.squeak.selector, squeakAmount)
            );
            
            // Verify their love decreased
            uint256 remainingLove = aminal.loveFromUser(users[i]);
            assertGt(remainingLove, 0, "User should have love remaining");
        }
    }
    
    function test_SqueakExhaustResources() public {
        // Get current resources
        uint256 availableLove = aminal.loveFromUser(user1);
        uint256 availableEnergy = aminal.getEnergy();
        uint256 maxSqueak = availableLove < availableEnergy ? availableLove : availableEnergy;
        
        // Cap at 10000 to match contract behavior
        if (maxSqueak > 10000) {
            maxSqueak = 10000;
        }
        
        // Keep squeaking until resources are exhausted
        while (aminal.loveFromUser(user1) >= maxSqueak && aminal.getEnergy() >= maxSqueak && maxSqueak > 0) {
            _useSkill(
                user1,
                aminal,
                address(squeakSkill),
                abi.encodeWithSelector(SqueakSkill.squeak.selector, maxSqueak)
            );
            
            // Update maxSqueak for next iteration
            availableLove = aminal.loveFromUser(user1);
            availableEnergy = aminal.getEnergy();
            maxSqueak = availableLove < availableEnergy ? availableLove : availableEnergy;
            if (maxSqueak > 10000) maxSqueak = 10000;
        }
        
        // Verify at least one resource is exhausted or below the cap
        assertTrue(
            aminal.loveFromUser(user1) < 10000 || aminal.getEnergy() < 10000,
            "At least one resource should be below the cap"
        );
    }
    
    // ========== Revert Tests ==========
    
    function test_RevertWhen_InsufficientEnergy() public {
        // Arrange - consume energy in chunks due to 10k cap
        uint256 currentEnergy = aminal.getEnergy();
        
        // Consume energy in 10k chunks until we have less than 100 left
        while (currentEnergy >= 10100) {
            _useSkill(
                user1,
                aminal,
                address(squeakSkill),
                abi.encodeWithSelector(SqueakSkill.squeak.selector, 10000)
            );
            currentEnergy = aminal.getEnergy();
        }
        
        // Now consume to leave exactly 100 energy
        if (currentEnergy > 100) {
            _useSkill(
                user1,
                aminal,
                address(squeakSkill),
                abi.encodeWithSelector(SqueakSkill.squeak.selector, currentEnergy - 100)
            );
        }
        
        // Try to squeak 101 with only 100 energy left
        _assertSkillReverts(
            user1,
            aminal,
            address(squeakSkill),
            abi.encodeWithSelector(SqueakSkill.squeak.selector, 101),
            Aminal.InsufficientEnergy.selector
        );
    }
    
    function test_RevertWhen_InsufficientLove() public {
        // Create a fresh Aminal to have better control
        aminal = _createDefaultAminal();
        _initializeAminal(aminal, "love-test.json");
        
        // Feed user1 just a small amount to get some love
        _feedAminal(user1, aminal, 0.01 ether);
        
        // Feed user3 more to ensure we have plenty of energy
        _feedAminal(user3, aminal, 1 ether);
        
        // Get user1's love (should be around 1000)
        uint256 user1Love = aminal.loveFromUser(user1);
        
        // Consume most of user1's love, leaving just 50
        if (user1Love > 50) {
            _useSkill(
                user1,
                aminal,
                address(squeakSkill),
                abi.encodeWithSelector(SqueakSkill.squeak.selector, user1Love - 50)
            );
        }
        
        // Try to squeak 51 with only 50 love left
        _assertSkillReverts(
            user1,
            aminal,
            address(squeakSkill),
            abi.encodeWithSelector(SqueakSkill.squeak.selector, 51),
            Aminal.InsufficientLove.selector
        );
    }
    
    function test_RevertWhen_ZeroEnergy() public {
        // Create fresh Aminal with no energy
        aminal = _createDefaultAminal();
        _initializeAminal(aminal, "zero-energy.json");
        
        // Act & Assert
        _assertSkillReverts(
            user1,
            aminal,
            address(squeakSkill),
            abi.encodeWithSelector(SqueakSkill.squeak.selector, 1),
            Aminal.InsufficientEnergy.selector
        );
    }
    
    // ========== Fuzz Tests ==========
    
    function testFuzz_SqueakVariousAmounts(uint256 feedAmount, uint256 squeakAmount) public {
        // Bound inputs to reasonable ranges
        feedAmount = bound(feedAmount, 0.001 ether, 10 ether);
        
        // Feed fresh Aminal
        aminal = _createDefaultAminal();
        _initializeAminal(aminal, "fuzz.json");
        
        // Ensure user1 has enough ETH for the feed
        vm.deal(user1, feedAmount + 1 ether);
        _feedAminal(user1, aminal, feedAmount);
        
        // Get available resources
        uint256 availableLove = aminal.loveFromUser(user1);
        uint256 availableEnergy = aminal.getEnergy();
        
        // Bound squeak amount to available resources
        squeakAmount = bound(squeakAmount, 1, _min(availableLove, availableEnergy));
        squeakAmount = bound(squeakAmount, 1, 10000); // Safety cap
        
        // Squeak
        vm.prank(user1);
        aminal.useSkill(
            address(squeakSkill),
            abi.encodeWithSelector(SqueakSkill.squeak.selector, squeakAmount)
        );
        
        // Verify costs
        assertEq(aminal.loveFromUser(user1), availableLove - squeakAmount);
        assertEq(aminal.getEnergy(), availableEnergy - squeakAmount);
    }
    
    function _min(uint256 a, uint256 b) private pure returns (uint256) {
        return a < b ? a : b;
    }
}