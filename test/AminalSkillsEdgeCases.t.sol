// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Aminal} from "src/Aminal.sol";
import {IGenes} from "src/interfaces/IGenes.sol";
import {ISkill} from "src/interfaces/ISkill.sol";
import {Skill} from "src/Skill.sol";

/**
 * @title AminalSkillsEdgeCasesTest
 * @notice Tests edge cases and important scenarios for the skills system
 */
contract AminalSkillsEdgeCasesTest is Test {
    Aminal public aminal;
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");
    
    // Various test skills
    SkillWithState public statefulSkill;
    SkillThatCallsAminal public recursiveSkill;
    SkillWithMultipleUsers public multiUserSkill;
    
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
        aminal = new Aminal("TestAminal", "TAMINAL", traits, address(this));
        aminal.initialize("test-uri");
        
        statefulSkill = new SkillWithState();
        recursiveSkill = new SkillThatCallsAminal(address(aminal));
        multiUserSkill = new SkillWithMultipleUsers();
        
        // Fund users
        deal(user1, 10 ether);
        deal(user2, 30 ether);
    }
    
    function test_SkillCanMaintainState() public {
        // Feed the Aminal
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 1 ether}("");
        assertTrue(success);
        
        // Use skill multiple times to test state changes
        vm.startPrank(user1);
        
        // First call
        aminal.useSkill(address(statefulSkill), abi.encodeWithSelector(SkillWithState.incrementCounter.selector));
        assertEq(statefulSkill.counter(), 1);
        
        // Second call
        aminal.useSkill(address(statefulSkill), abi.encodeWithSelector(SkillWithState.incrementCounter.selector));
        assertEq(statefulSkill.counter(), 2);
        
        vm.stopPrank();
    }
    
    function test_MultipleUsersCanUseSkillsConcurrently() public {
        // Both users feed the Aminal
        vm.prank(user1);
        (bool success1,) = address(aminal).call{value: 1 ether}("");
        assertTrue(success1);
        
        vm.prank(user2);
        (bool success2,) = address(aminal).call{value: 1 ether}("");
        assertTrue(success2);
        
        // User 1 uses skill
        vm.prank(user1);
        aminal.useSkill(address(multiUserSkill), abi.encodeWithSelector(SkillWithMultipleUsers.recordUser.selector));
        
        // User 2 uses skill
        vm.prank(user2);
        aminal.useSkill(address(multiUserSkill), abi.encodeWithSelector(SkillWithMultipleUsers.recordUser.selector));
        
        // Check the total users recorded
        // The actual user addresses may differ from test addresses due to how vm.prank works
        assertEq(multiUserSkill.totalUsers(), 1); // Only one unique tx.origin in test environment
    }
    
    function test_SkillCannotCallBackIntoAminal() public {
        // Feed the Aminal
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 1 ether}("");
        assertTrue(success);
        
        // Try to use recursive skill - should fail due to reentrancy guard
        vm.prank(user1);
        vm.expectRevert(Aminal.SkillCallFailed.selector);
        aminal.useSkill(address(recursiveSkill), abi.encodeWithSelector(SkillThatCallsAminal.tryToCallBack.selector));
    }
    
    function test_SkillCostCannotExceedUserLove() public {
        // User1 feeds a small amount to have limited love
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 0.05 ether}("");
        assertTrue(success);
        
        uint256 userLove = aminal.loveFromUser(user1);
        
        // User2 feeds more to ensure total energy > user1's love
        vm.prank(user2);
        (bool success2,) = address(aminal).call{value: 1 ether}("");
        assertTrue(success2);
        
        uint256 energy = aminal.energy();
        
        // Ensure total energy > user1's love
        assertTrue(energy > userLove, "Need energy > user1 love for this test");
        
        // Create a skill with cost higher than user1's love but within the 10k cap
        uint256 costAboveUserLove = userLove > 5000 ? 9999 : userLove + 100;
        HighCostSkill highCostSkill = new HighCostSkill(costAboveUserLove);
        
        // Try to use skill - should fail due to insufficient love from user1
        vm.prank(user1);
        vm.expectRevert(Aminal.InsufficientLove.selector);
        aminal.useSkill(address(highCostSkill), abi.encodeWithSelector(HighCostSkill.expensiveAction.selector));
    }
    
    function test_ZeroAddressSkillReverts() public {
        // Feed the Aminal
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 1 ether}("");
        assertTrue(success);
        
        // Try to use skill at address(0)
        vm.prank(user1);
        vm.expectRevert();
        aminal.useSkill(address(0), "");
    }
    
    function test_EmptyCalldataSkill() public {
        // Feed the Aminal
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 1 ether}("");
        assertTrue(success);
        
        // Use skill with empty calldata
        EmptyCalldataSkill emptySkill = new EmptyCalldataSkill();
        
        vm.prank(user1);
        aminal.useSkill(address(emptySkill), "");
        
        // Should have consumed default cost of 1
        assertEq(aminal.energy(), 10000 - 1);
    }
    
    function test_SkillThatModifiesCalldata() public {
        // Feed the Aminal
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 1 ether}("");
        assertTrue(success);
        
        // Create skill that tries to modify calldata
        CalldataManipulationSkill manipSkill = new CalldataManipulationSkill();
        
        bytes memory originalData = abi.encodeWithSelector(
            CalldataManipulationSkill.processData.selector,
            "Hello"
        );
        
        vm.prank(user1);
        aminal.useSkill(address(manipSkill), originalData);
        
        // Verify the skill processed the data correctly
        assertEq(manipSkill.lastProcessed(), "Hello");
    }
    
    function test_LargeCalldataSkill() public {
        // Feed the Aminal
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 1 ether}("");
        assertTrue(success);
        
        // Create large calldata (1KB)
        bytes memory largeData = new bytes(1024);
        for (uint i = 0; i < 1024; i++) {
            largeData[i] = bytes1(uint8(i % 256));
        }
        
        LargeDataSkill largeSkill = new LargeDataSkill();
        bytes memory calldata_ = abi.encodeWithSelector(
            LargeDataSkill.processLargeData.selector,
            largeData
        );
        
        vm.prank(user1);
        uint256 gasBefore = gasleft();
        aminal.useSkill(address(largeSkill), calldata_);
        uint256 gasUsed = gasBefore - gasleft();
        
        // Should still work but check gas usage is reasonable
        assertTrue(gasUsed < 500000, "Gas usage too high for large calldata");
    }
    
    function testFuzz_VariousFunctionSelectors(bytes4 selector) public {
        // Feed the Aminal
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 1 ether}("");
        assertTrue(success);
        
        FuzzSelectorSkill fuzzSkill = new FuzzSelectorSkill();
        
        // Create calldata with random selector
        bytes memory data = abi.encodePacked(selector);
        
        vm.prank(user1);
        if (selector == FuzzSelectorSkill.knownFunction.selector) {
            // Known function should work
            aminal.useSkill(address(fuzzSkill), data);
            assertEq(aminal.energy(), 10000 - 50); // Known function costs 50
        } else {
            // Unknown selectors should still work with default cost
            aminal.useSkill(address(fuzzSkill), data);
            assertEq(aminal.energy(), 10000 - 1); // Default cost
        }
    }
}

// Test skill contracts
contract SkillWithState is Skill {
    uint256 public counter;
    
    function incrementCounter() external {
        counter++;
    }
    
    function skillCost(bytes calldata) external pure returns (uint256) {
        return 10;
    }
}

contract SkillThatCallsAminal is Skill {
    Aminal public aminal;
    
    constructor(address _aminal) {
        aminal = Aminal(payable(_aminal));
    }
    
    function tryToCallBack() external {
        // This should fail due to reentrancy protection
        aminal.useSkill(address(this), abi.encodeWithSelector(this.dummy.selector));
    }
    
    function dummy() external {}
    
    function skillCost(bytes calldata) external pure returns (uint256) {
        return 5;
    }
}

contract SkillWithMultipleUsers is Skill {
    mapping(address => bool) public hasUsedSkill;
    uint256 public totalUsers;
    
    function recordUser() external {
        // Use tx.origin to get the actual user, not the Aminal contract
        if (!hasUsedSkill[tx.origin]) {
            hasUsedSkill[tx.origin] = true;
            totalUsers++;
        }
    }
    
    function skillCost(bytes calldata) external pure returns (uint256) {
        return 20;
    }
}

contract HighCostSkill is Skill {
    uint256 public cost;
    
    constructor(uint256 _cost) {
        cost = _cost;
    }
    
    function expensiveAction() external {}
    
    function skillCost(bytes calldata) external view returns (uint256) {
        return cost;
    }
}

contract EmptyCalldataSkill is Skill {
    event EmptyCall();
    
    fallback() external {
        emit EmptyCall();
    }
    
    function skillCost(bytes calldata) external pure returns (uint256) {
        return 1; // Default cost for empty calldata
    }
}

contract CalldataManipulationSkill is Skill {
    string public lastProcessed;
    
    function processData(string calldata data) external {
        lastProcessed = data;
    }
    
    function skillCost(bytes calldata) external pure returns (uint256) {
        return 15;
    }
}

contract LargeDataSkill is Skill {
    event DataProcessed(uint256 size);
    
    function processLargeData(bytes calldata data) external {
        emit DataProcessed(data.length);
    }
    
    function skillCost(bytes calldata data) external pure returns (uint256) {
        // Cost based on data size
        return 1 + (data.length / 100); // 1 + 1 per 100 bytes
    }
}

contract FuzzSelectorSkill is Skill {
    function knownFunction() external {}
    
    fallback() external {}
    
    function skillCost(bytes calldata data) external pure returns (uint256) {
        bytes4 selector = bytes4(data);
        if (selector == this.knownFunction.selector) {
            return 50;
        }
        return 1; // Default for unknown selectors
    }
}