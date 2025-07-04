// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Aminal} from "src/Aminal.sol";
import {SqueakSkill} from "src/skills/SqueakSkill.sol";
import {ITraits} from "src/interfaces/ITraits.sol";
import {ISkill} from "src/interfaces/ISkill.sol";

contract SqueakSkillTest is Test {
    Aminal public aminal;
    SqueakSkill public squeakSkill;
    
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");
    
    event Squeaked(address indexed aminal, uint256 amount);
    event EnergyLost(address indexed squeaker, uint256 amount, uint256 newEnergy);
    event LoveConsumed(address indexed squeaker, uint256 amount, uint256 remainingLove);
    event SkillUsed(address indexed user, uint256 energyCost, address indexed target, bytes4 indexed selector);
    
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
        
        // Deploy contracts
        aminal = new Aminal("TestAminal", "TAMINAL", "https://test.com/", traits);
        aminal.initialize("test-uri");
        
        squeakSkill = new SqueakSkill();
        
        // Fund users
        deal(user1, 10 ether);
        deal(user2, 10 ether);
    }
    
    function test_SqueakSkillSupportsInterface() public view {
        assertTrue(squeakSkill.supportsInterface(type(ISkill).interfaceId));
    }
    
    function test_BasicSqueak() public {
        // Feed the Aminal
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 1 ether}("");
        assertTrue(success);
        
        uint256 initialEnergy = aminal.energy();
        uint256 initialLove = aminal.loveFromUser(user1);
        uint256 squeakAmount = 100;
        
        // Prepare squeak call
        bytes memory squeakData = abi.encodeWithSelector(SqueakSkill.squeak.selector, squeakAmount);
        
        // Expect events
        vm.expectEmit(true, false, false, true);
        emit Squeaked(address(aminal), squeakAmount);
        
        vm.expectEmit(true, false, false, true);
        emit EnergyLost(user1, squeakAmount, initialEnergy - squeakAmount);
        
        vm.expectEmit(true, false, false, true);
        emit LoveConsumed(user1, squeakAmount, initialLove - squeakAmount);
        
        vm.expectEmit(true, true, true, true);
        emit SkillUsed(user1, squeakAmount, address(squeakSkill), SqueakSkill.squeak.selector);
        
        // Execute squeak
        vm.prank(user1);
        aminal.useSkill(address(squeakSkill), squeakData);
        
        // Verify state changes
        assertEq(aminal.energy(), initialEnergy - squeakAmount);
        assertEq(aminal.loveFromUser(user1), initialLove - squeakAmount);
    }
    
    function test_SqueakWithDifferentAmounts() public {
        // Feed the Aminal
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 1 ether}("");
        assertTrue(success);
        
        uint256[] memory amounts = new uint256[](5);
        amounts[0] = 1;
        amounts[1] = 10;
        amounts[2] = 100;
        amounts[3] = 500;
        amounts[4] = 1000;
        
        for (uint i = 0; i < amounts.length; i++) {
            uint256 energyBefore = aminal.energy();
            uint256 loveBefore = aminal.loveFromUser(user1);
            
            bytes memory squeakData = abi.encodeWithSelector(SqueakSkill.squeak.selector, amounts[i]);
            
            vm.prank(user1);
            aminal.useSkill(address(squeakSkill), squeakData);
            
            assertEq(aminal.energy(), energyBefore - amounts[i]);
            assertEq(aminal.loveFromUser(user1), loveBefore - amounts[i]);
        }
    }
    
    function test_SqueakInsufficientEnergy() public {
        // Feed the Aminal
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 0.1 ether}("");
        assertTrue(success);
        
        uint256 energy = aminal.energy();
        uint256 squeakAmount = energy + 1; // Try to squeak more than available
        
        bytes memory squeakData = abi.encodeWithSelector(SqueakSkill.squeak.selector, squeakAmount);
        
        vm.prank(user1);
        vm.expectRevert(Aminal.InsufficientEnergy.selector);
        aminal.useSkill(address(squeakSkill), squeakData);
    }
    
    function test_SqueakInsufficientLove() public {
        // User1 feeds the Aminal with small amount
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 0.01 ether}("");
        assertTrue(success);
        
        // User2 feeds the Aminal to add energy
        vm.prank(user2);
        (bool success2,) = address(aminal).call{value: 0.1 ether}("");
        assertTrue(success2);
        
        // User1 tries to squeak more than their love but less than the cap
        uint256 user1Love = aminal.loveFromUser(user1);
        uint256 squeakAmount = user1Love + 1;
        
        // Ensure the amount is less than or equal to 10000 cap
        assertTrue(squeakAmount <= 10000, "Squeak amount should be less than or equal to cap");
        
        bytes memory squeakData = abi.encodeWithSelector(SqueakSkill.squeak.selector, squeakAmount);
        
        vm.prank(user1);
        vm.expectRevert(Aminal.InsufficientLove.selector);
        aminal.useSkill(address(squeakSkill), squeakData);
    }
    
    function test_MultipleUsersSqueak() public {
        // Both users feed the Aminal
        vm.prank(user1);
        (bool success1,) = address(aminal).call{value: 1 ether}("");
        assertTrue(success1);
        
        vm.prank(user2);
        (bool success2,) = address(aminal).call{value: 1 ether}("");
        assertTrue(success2);
        
        uint256 squeakAmount = 500;
        bytes memory squeakData = abi.encodeWithSelector(SqueakSkill.squeak.selector, squeakAmount);
        
        // User1 squeaks
        uint256 energyBefore = aminal.energy();
        uint256 user1LoveBefore = aminal.loveFromUser(user1);
        uint256 user2LoveBefore = aminal.loveFromUser(user2);
        
        vm.prank(user1);
        aminal.useSkill(address(squeakSkill), squeakData);
        
        assertEq(aminal.energy(), energyBefore - squeakAmount);
        assertEq(aminal.loveFromUser(user1), user1LoveBefore - squeakAmount);
        assertEq(aminal.loveFromUser(user2), user2LoveBefore); // User2's love unchanged
        
        // User2 squeaks
        energyBefore = aminal.energy();
        user2LoveBefore = aminal.loveFromUser(user2);
        
        vm.prank(user2);
        aminal.useSkill(address(squeakSkill), squeakData);
        
        assertEq(aminal.energy(), energyBefore - squeakAmount);
        assertEq(aminal.loveFromUser(user2), user2LoveBefore - squeakAmount);
    }
    
    function test_SkillCostCalculation() public view {
        // Test various amounts
        uint256[] memory amounts = new uint256[](4);
        amounts[0] = 1;
        amounts[1] = 100;
        amounts[2] = 1000;
        amounts[3] = 10000;
        
        for (uint i = 0; i < amounts.length; i++) {
            bytes memory squeakData = abi.encodeWithSelector(SqueakSkill.squeak.selector, amounts[i]);
            uint256 cost = squeakSkill.skillCost(squeakData);
            assertEq(cost, amounts[i]);
        }
    }
    
    function test_SkillCostWithInvalidSelector() public view {
        // Test with an invalid function selector
        bytes memory invalidData = abi.encodeWithSelector(bytes4(keccak256("invalidFunction()")));
        uint256 cost = squeakSkill.skillCost(invalidData);
        assertEq(cost, 1); // Should return default cost
    }
    
    function test_SqueakZeroAmount() public {
        // Feed the Aminal
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 1 ether}("");
        assertTrue(success);
        
        // Try to squeak with 0 amount
        bytes memory squeakData = abi.encodeWithSelector(SqueakSkill.squeak.selector, 0);
        
        // Even though squeak amount is 0, useSkill enforces minimum cost of 1
        uint256 energyBefore = aminal.energy();
        uint256 loveBefore = aminal.loveFromUser(user1);
        
        vm.prank(user1);
        aminal.useSkill(address(squeakSkill), squeakData);
        
        // Should consume 1 unit (minimum cost)
        assertEq(aminal.energy(), energyBefore - 1);
        assertEq(aminal.loveFromUser(user1), loveBefore - 1);
    }
    
    function testFuzz_SqueakVariousAmounts(uint256 feedAmount, uint256 squeakAmount) public {
        // Bound inputs
        feedAmount = bound(feedAmount, 0.001 ether, 10 ether);
        squeakAmount = bound(squeakAmount, 1, 10000);
        
        // Feed the Aminal
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: feedAmount}("");
        assertTrue(success);
        
        uint256 energy = aminal.energy();
        uint256 love = aminal.loveFromUser(user1);
        
        // Only squeak if we have enough resources
        vm.assume(squeakAmount <= energy);
        vm.assume(squeakAmount <= love);
        
        bytes memory squeakData = abi.encodeWithSelector(SqueakSkill.squeak.selector, squeakAmount);
        
        vm.prank(user1);
        aminal.useSkill(address(squeakSkill), squeakData);
        
        assertEq(aminal.energy(), energy - squeakAmount);
        assertEq(aminal.loveFromUser(user1), love - squeakAmount);
    }
    
    function test_SqueakExhaustAllResources() public {
        // Feed the Aminal
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 1 ether}("");
        assertTrue(success);
        
        // Get the minimum of energy and love
        uint256 energy = aminal.energy();
        uint256 love = aminal.loveFromUser(user1);
        uint256 maxSqueak = energy < love ? energy : love;
        
        bytes memory squeakData = abi.encodeWithSelector(SqueakSkill.squeak.selector, maxSqueak);
        
        // Squeak the maximum amount
        vm.prank(user1);
        aminal.useSkill(address(squeakSkill), squeakData);
        
        // Verify we've exhausted at least one resource
        assertTrue(aminal.energy() == 0 || aminal.loveFromUser(user1) == 0);
        
        // Try to squeak again - should fail
        bytes memory squeakOneData = abi.encodeWithSelector(SqueakSkill.squeak.selector, 1);
        vm.prank(user1);
        vm.expectRevert();
        aminal.useSkill(address(squeakSkill), squeakOneData);
    }
}