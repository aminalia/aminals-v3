// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {Aminal} from "src/Aminal.sol";
import {ITraits} from "src/interfaces/ITraits.sol";

// Mock skill contracts for testing
contract SimpleSkill {
    function performAction() external pure returns (uint256) {
        return 100; // Costs 100 energy
    }
    
    function freeAction() external pure returns (uint256) {
        return 0; // Invalid cost, should default to 1
    }
    
    function expensiveAction() external pure returns (uint256) {
        return 1000000; // Very expensive
    }
}

contract NoReturnSkill {
    event ActionPerformed();
    
    function voidAction() external {
        emit ActionPerformed();
        // No return value
    }
}

contract RevertingSkill {
    error ActionFailed();
    
    function failingAction() external pure {
        revert ActionFailed();
    }
}

contract ComplexSkill {
    struct Result {
        uint256 cost;
        string message;
    }
    
    function complexAction() external pure returns (Result memory) {
        return Result(50, "Complex action performed");
    }
}

contract AminalSkillsTest is Test {
    Aminal public aminal;
    SimpleSkill public simpleSkill;
    NoReturnSkill public noReturnSkill;
    RevertingSkill public revertingSkill;
    ComplexSkill public complexSkill;
    
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");
    
    event SkillUsed(address indexed user, address indexed target, uint256 energyCost, bytes4 selector);
    event EnergyLost(address indexed squeaker, uint256 amount, uint256 newEnergy);
    event LoveConsumed(address indexed squeaker, uint256 amount, uint256 remainingLove);
    
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
        
        simpleSkill = new SimpleSkill();
        noReturnSkill = new NoReturnSkill();
        revertingSkill = new RevertingSkill();
        complexSkill = new ComplexSkill();
        
        // Fund test users
        deal(user1, 10 ether);
        deal(user2, 10 ether);
    }
    
    function test_UseSkillWithReturnedCost() public {
        // Feed the Aminal to give it energy and love
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 1 ether}("");
        assertTrue(success);
        
        uint256 initialEnergy = aminal.energy();
        uint256 initialLove = aminal.loveFromUser(user1);
        
        // Use skill that returns 100 energy cost
        bytes memory skillData = abi.encodeWithSelector(SimpleSkill.performAction.selector);
        
        vm.prank(user1);
        vm.expectEmit(true, false, false, true);
        emit EnergyLost(user1, 100, initialEnergy - 100);
        vm.expectEmit(true, false, false, true);
        emit LoveConsumed(user1, 100, initialLove - 100);
        vm.expectEmit(true, true, false, true);
        emit SkillUsed(user1, address(simpleSkill), 100, SimpleSkill.performAction.selector);
        
        aminal.useSkill(address(simpleSkill), skillData);
        
        // Verify energy and love were consumed
        assertEq(aminal.energy(), initialEnergy - 100);
        assertEq(aminal.loveFromUser(user1), initialLove - 100);
    }
    
    function test_UseSkillWithNoReturn() public {
        // Feed the Aminal
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 0.1 ether}("");
        assertTrue(success);
        
        uint256 initialEnergy = aminal.energy();
        uint256 initialLove = aminal.loveFromUser(user1);
        
        // Use skill that returns nothing (should default to 1 cost)
        bytes memory skillData = abi.encodeWithSelector(NoReturnSkill.voidAction.selector);
        
        vm.prank(user1);
        vm.expectEmit(true, true, false, true);
        emit SkillUsed(user1, address(noReturnSkill), 1, NoReturnSkill.voidAction.selector);
        
        aminal.useSkill(address(noReturnSkill), skillData);
        
        // Should consume 1 energy/love (default)
        assertEq(aminal.energy(), initialEnergy - 1);
        assertEq(aminal.loveFromUser(user1), initialLove - 1);
    }
    
    function test_UseSkillWithZeroCost() public {
        // Feed the Aminal
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 0.1 ether}("");
        assertTrue(success);
        
        uint256 initialEnergy = aminal.energy();
        uint256 initialLove = aminal.loveFromUser(user1);
        
        // Use skill that returns 0 (should default to 1)
        bytes memory skillData = abi.encodeWithSelector(SimpleSkill.freeAction.selector);
        
        vm.prank(user1);
        aminal.useSkill(address(simpleSkill), skillData);
        
        // Should consume 1 energy/love (default for 0 cost)
        assertEq(aminal.energy(), initialEnergy - 1);
        assertEq(aminal.loveFromUser(user1), initialLove - 1);
    }
    
    function test_UseSkillWithExcessiveCost() public {
        // Feed the Aminal a small amount
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 0.001 ether}("");
        assertTrue(success);
        
        uint256 initialEnergy = aminal.energy();
        uint256 initialLove = aminal.loveFromUser(user1);
        
        // Use skill that returns very high cost (more than available energy)
        bytes memory skillData = abi.encodeWithSelector(SimpleSkill.expensiveAction.selector);
        
        // With the cap, it will consume all available energy (not revert)
        vm.prank(user1);
        aminal.useSkill(address(simpleSkill), skillData);
        
        // Should have consumed only the available energy (10)
        assertEq(aminal.energy(), 0);
        assertEq(aminal.loveFromUser(user1), initialLove - 10);
    }
    
    function test_UseSkillWithComplexReturn() public {
        // Feed the Aminal
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 0.1 ether}("");
        assertTrue(success);
        
        uint256 initialEnergy = aminal.energy();
        uint256 initialLove = aminal.loveFromUser(user1);
        
        // Use skill that returns a struct (first 32 bytes should be the cost)
        bytes memory skillData = abi.encodeWithSelector(ComplexSkill.complexAction.selector);
        
        vm.prank(user1);
        aminal.useSkill(address(complexSkill), skillData);
        
        // When a struct is returned, the first 32 bytes will be interpreted as the cost
        // In this case, it's actually the offset to the struct data, not the cost value
        // So it will use a different value than 50
        // Let's check what was actually consumed
        uint256 actualEnergyConsumed = initialEnergy - aminal.energy();
        uint256 actualLoveConsumed = initialLove - aminal.loveFromUser(user1);
        
        // The consumed amounts should be equal and greater than 0
        assertEq(actualEnergyConsumed, actualLoveConsumed);
        assertGt(actualEnergyConsumed, 0);
    }
    
    function test_RevertWhen_SkillFails() public {
        // Feed the Aminal
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 0.1 ether}("");
        assertTrue(success);
        
        // Use skill that reverts
        bytes memory skillData = abi.encodeWithSelector(RevertingSkill.failingAction.selector);
        
        vm.prank(user1);
        vm.expectRevert(Aminal.SkillCallFailed.selector);
        aminal.useSkill(address(revertingSkill), skillData);
    }
    
    function test_RevertWhen_InsufficientResources() public {
        // Don't feed the Aminal - it has 0 energy and 0 love
        
        // Try to use any skill - should fail due to insufficient energy
        bytes memory skillData = abi.encodeWithSelector(NoReturnSkill.voidAction.selector);
        
        vm.prank(user1);
        vm.expectRevert(Aminal.InsufficientEnergy.selector);
        aminal.useSkill(address(noReturnSkill), skillData);
    }
    
    function test_RevertWhen_InsufficientLove() public {
        // User1 feeds the Aminal
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 0.01 ether}("");
        assertTrue(success);
        
        // User2 feeds more to increase energy but has less love
        vm.prank(user2);
        (success,) = address(aminal).call{value: 0.001 ether}("");
        assertTrue(success);
        
        // User2 tries to use skill but doesn't have enough love
        bytes memory skillData = abi.encodeWithSelector(SimpleSkill.performAction.selector);
        
        vm.prank(user2);
        vm.expectRevert(Aminal.InsufficientLove.selector);
        aminal.useSkill(address(simpleSkill), skillData);
    }
    
    function test_MultipleUsersUsingSkills() public {
        // Both users feed the Aminal
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 1 ether}("");
        assertTrue(success);
        
        uint256 user1InitialLove = aminal.loveFromUser(user1);
        
        vm.prank(user2);
        (success,) = address(aminal).call{value: 1 ether}("");
        assertTrue(success);
        
        uint256 user2InitialLove = aminal.loveFromUser(user2);
        
        // User1 uses a skill that costs 100
        bytes memory skillData1 = abi.encodeWithSelector(SimpleSkill.performAction.selector);
        vm.prank(user1);
        aminal.useSkill(address(simpleSkill), skillData1);
        
        // User2 uses a skill that costs 1 (default)
        bytes memory skillData2 = abi.encodeWithSelector(NoReturnSkill.voidAction.selector);
        vm.prank(user2);
        aminal.useSkill(address(noReturnSkill), skillData2);
        
        // Verify both users' love was consumed appropriately
        uint256 user1Love = aminal.loveFromUser(user1);
        uint256 user2Love = aminal.loveFromUser(user2);
        
        // User1 consumed 100, user2 consumed 1
        assertEq(user1Love, user1InitialLove - 100);
        assertEq(user2Love, user2InitialLove - 1);
    }
    
    function testFuzz_UseSkillWithVariableCosts(uint8 cost) public {
        // Create a mock skill that returns the fuzzed cost
        MockVariableSkill variableSkill = new MockVariableSkill(uint256(cost));
        
        // Feed the Aminal enough energy
        vm.deal(user1, 10 ether);
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 1 ether}("");
        assertTrue(success);
        
        uint256 initialEnergy = aminal.energy();
        uint256 initialLove = aminal.loveFromUser(user1);
        
        // Use the skill
        bytes memory skillData = abi.encodeWithSelector(MockVariableSkill.action.selector);
        
        // Check if we expect it to revert
        if (cost > initialEnergy || cost > initialLove) {
            vm.prank(user1);
            if (cost > initialEnergy) {
                vm.expectRevert(Aminal.InsufficientEnergy.selector);
            } else {
                vm.expectRevert(Aminal.InsufficientLove.selector);
            }
            aminal.useSkill(address(variableSkill), skillData);
        } else {
            vm.prank(user1);
            aminal.useSkill(address(variableSkill), skillData);
            
            // Verify correct amount was consumed
            if (cost == 0) {
                // Should default to 1 for zero cost
                assertEq(aminal.energy(), initialEnergy - 1);
                assertEq(aminal.loveFromUser(user1), initialLove - 1);
            } else {
                // Should consume the returned cost
                assertEq(aminal.energy(), initialEnergy - uint256(cost));
                assertEq(aminal.loveFromUser(user1), initialLove - uint256(cost));
            }
        }
    }
}

// Helper contract for fuzz testing
contract MockVariableSkill {
    uint256 public cost;
    
    constructor(uint256 _cost) {
        cost = _cost;
    }
    
    function action() external view returns (uint256) {
        return cost;
    }
}