// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {Aminal} from "src/Aminal.sol";
import {IGenes} from "src/interfaces/IGenes.sol";
import {ISkill} from "src/interfaces/ISkill.sol";
import {Skill} from "src/Skill.sol";

// Proper skill implementation
contract ValidSkill is Skill {
    event SkillExecuted(string message);
    
    function action1() external {
        emit SkillExecuted("Action 1 executed");
    }
    
    function action2(uint256 value) external {
        emit SkillExecuted("Action 2 executed");
        // Use value in some way to avoid compiler warning
        value = value;
    }
    
    function skillCost(bytes calldata data) external pure returns (uint256) {
        bytes4 selector = bytes4(data);
        
        if (selector == this.action1.selector) {
            return 50;
        } else if (selector == this.action2.selector) {
            // Dynamic cost based on parameter
            uint256 value = abi.decode(data[4:], (uint256));
            return value * 10;
        }
        
        return 1; // Default cost
    }
}

// Contract without ISkill interface
contract NonSkillContract {
    function someFunction() external pure returns (uint256) {
        return 100;
    }
}

// Skill that reverts on cost query
contract FaultySkill is Skill {
    function doSomething() external pure returns (bool) {
        return true;
    }
    
    function skillCost(bytes calldata) external pure returns (uint256) {
        revert("Cost calculation failed");
    }
}

contract AminalSkillsTest is Test {
    Aminal public aminal;
    ValidSkill public validSkill;
    NonSkillContract public nonSkill;
    FaultySkill public faultySkill;
    
    address public user1 = makeAddr("user1");
    
    event SkillUsed(address indexed user, uint256 energyCost, address indexed target, bytes4 indexed selector);
    
    function setUp() public {
        // Create test traits
        IGenes.Genes memory traits = IGenes.Genes({
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
        aminal = new Aminal("TestAminal", "TAMINAL", "https://test.com/", traits, address(this));
        aminal.initialize("test-uri");
        
        validSkill = new ValidSkill();
        nonSkill = new NonSkillContract();
        faultySkill = new FaultySkill();
        
        // Fund user
        deal(user1, 10 ether);
    }
    
    function test_ValidSkillExecution() public {
        // Feed the Aminal
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 1 ether}("");
        assertTrue(success);
        
        uint256 energyBefore = aminal.energy();
        uint256 loveBefore = aminal.loveFromUser(user1);
        
        // Execute skill action1 (costs 50)
        bytes memory skillData = abi.encodeWithSelector(ValidSkill.action1.selector);
        
        vm.prank(user1);
        vm.expectEmit(true, true, false, true);
        emit SkillUsed(user1, 50, address(validSkill), ValidSkill.action1.selector);
        
        aminal.useSkill(address(validSkill), skillData);
        
        assertEq(aminal.energy(), energyBefore - 50);
        assertEq(aminal.loveFromUser(user1), loveBefore - 50);
    }
    
    function test_DynamicCostCalculation() public {
        // Feed the Aminal
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 1 ether}("");
        assertTrue(success);
        
        uint256 energyBefore = aminal.energy();
        
        // Execute action2 with value 5 (costs 5 * 10 = 50)
        bytes memory skillData = abi.encodeWithSelector(ValidSkill.action2.selector, 5);
        
        vm.prank(user1);
        aminal.useSkill(address(validSkill), skillData);
        
        assertEq(aminal.energy(), energyBefore - 50);
    }
    
    function test_RevertWhen_NonSkillContract() public {
        // Feed the Aminal
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 1 ether}("");
        assertTrue(success);
        
        // Try to use non-skill contract
        bytes memory skillData = abi.encodeWithSelector(NonSkillContract.someFunction.selector);
        
        vm.prank(user1);
        vm.expectRevert(Aminal.SkillNotSupported.selector);
        aminal.useSkill(address(nonSkill), skillData);
    }
    
    function test_FaultyCostQueryDefaultsTo1() public {
        // Feed the Aminal
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 1 ether}("");
        assertTrue(success);
        
        uint256 energyBefore = aminal.energy();
        
        // Use faulty skill (cost query reverts, should default to 1)
        bytes memory skillData = abi.encodeWithSelector(FaultySkill.doSomething.selector);
        
        vm.prank(user1);
        aminal.useSkill(address(faultySkill), skillData);
        
        assertEq(aminal.energy(), energyBefore - 1);
    }
    
    function test_CostCapping() public {
        // Create a skill that returns excessive cost
        ExcessiveCostSkill excessiveSkill = new ExcessiveCostSkill();
        
        // Feed the Aminal
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 0.5 ether}(""); // Only 5000 energy
        assertTrue(success);
        
        uint256 energyBefore = aminal.energy();
        
        // Try to use skill that wants 999999 energy
        bytes memory skillData = abi.encodeWithSelector(ExcessiveCostSkill.expensiveAction.selector);
        
        vm.prank(user1);
        aminal.useSkill(address(excessiveSkill), skillData);
        
        // Should be capped at all available energy (5000)
        assertEq(aminal.energy(), 0);
        assertEq(energyBefore, 5000);
    }
    
    function test_MinimumCostOf1() public {
        // Create a skill that returns 0 cost
        ZeroCostSkill zeroSkill = new ZeroCostSkill();
        
        // Feed the Aminal
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 1 ether}("");
        assertTrue(success);
        
        uint256 energyBefore = aminal.energy();
        
        // Use skill that returns 0 cost
        bytes memory skillData = abi.encodeWithSelector(ZeroCostSkill.freeAction.selector);
        
        vm.prank(user1);
        aminal.useSkill(address(zeroSkill), skillData);
        
        // Should consume minimum of 1
        assertEq(aminal.energy(), energyBefore - 1);
    }
    
    function test_SkillExecutionFailureReverts() public {
        // Create a skill that reverts on execution
        RevertingSkill revertingSkill = new RevertingSkill();
        
        // Feed the Aminal
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 1 ether}("");
        assertTrue(success);
        
        // Try to use reverting skill
        bytes memory skillData = abi.encodeWithSelector(RevertingSkill.failingAction.selector);
        
        vm.prank(user1);
        vm.expectRevert(Aminal.SkillCallFailed.selector);
        aminal.useSkill(address(revertingSkill), skillData);
        
        // Energy should not have been consumed
        assertEq(aminal.energy(), 10000);
    }
}

// Helper contracts
contract ExcessiveCostSkill is Skill {
    function expensiveAction() external pure returns (bool) {
        return true;
    }
    
    function skillCost(bytes calldata) external pure returns (uint256) {
        return 999999;
    }
}

contract ZeroCostSkill is Skill {
    function freeAction() external pure returns (string memory) {
        return "Free!";
    }
    
    function skillCost(bytes calldata) external pure returns (uint256) {
        return 0;
    }
}

contract RevertingSkill is Skill {
    function failingAction() external pure {
        revert("Action failed!");
    }
    
    function skillCost(bytes calldata) external pure returns (uint256) {
        return 10;
    }
}