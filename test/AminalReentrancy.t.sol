// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Aminal} from "src/Aminal.sol";
import {IGenes} from "src/interfaces/IGenes.sol";
import {ISkill} from "src/interfaces/ISkill.sol";
import {Skill} from "src/Skill.sol";

// Malicious skill that attempts reentrancy
contract ReentrantSkill is Skill {
    Aminal public aminal;
    uint256 public attackCount;
    bool public reentrancyAttempted;
    
    constructor(address _aminal) {
        aminal = Aminal(payable(_aminal));
    }
    
    function attack() external {
        attackCount++;
        
        // Try to call useSkill again (reentrancy attempt)
        if (attackCount < 3) {
            reentrancyAttempted = true;
            try aminal.useSkill(address(this), abi.encodeWithSelector(this.attack.selector)) {
                // If this succeeds, reentrancy protection failed
            } catch {
                // Expected - reentrancy should fail
            }
        }
    }
    
    function skillCost(bytes calldata) external pure returns (uint256) {
        return 10;
    }
}

// Safe skill for testing legitimate calls
contract SafeSkill is Skill {
    uint256 public callCount;
    
    function action() external {
        callCount++;
    }
    
    function skillCost(bytes calldata) external pure returns (uint256) {
        return 5;
    }
}

contract AminalReentrancyTest is Test {
    Aminal public aminal;
    ReentrantSkill public reentrantSkill;
    SafeSkill public safeSkill;
    
    address public user1 = makeAddr("user1");
    
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
        
        // Deploy Aminal
        aminal = new Aminal("TestAminal", "TAMINAL", "https://test.com/", traits);
        aminal.initialize("test-uri");
        
        // Deploy skills
        reentrantSkill = new ReentrantSkill(address(aminal));
        safeSkill = new SafeSkill();
        
        // Fund user
        deal(user1, 10 ether);
    }
    
    function test_ReentrancyProtection() public {
        // Feed the Aminal
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 1 ether}("");
        assertTrue(success);
        
        // Attempt reentrancy attack
        bytes memory attackData = abi.encodeWithSelector(ReentrantSkill.attack.selector);
        
        // The skill will execute and try to reenter, which will fail
        vm.prank(user1);
        aminal.useSkill(address(reentrantSkill), attackData);
        
        // Attack should have been called
        assertEq(reentrantSkill.attackCount(), 1);
        assertTrue(reentrantSkill.reentrancyAttempted(), "Should have attempted reentrancy");
        
        // Energy SHOULD have been consumed for the successful first call
        assertEq(aminal.energy(), 9990); // 10000 - 10
        
        // The reentrancy protection prevents attackCount from going above 1
        // because the nested call fails
    }
    
    function test_LegitimateSequentialCalls() public {
        // Feed the Aminal
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 1 ether}("");
        assertTrue(success);
        
        bytes memory actionData = abi.encodeWithSelector(SafeSkill.action.selector);
        
        // Make multiple legitimate sequential calls
        vm.startPrank(user1);
        
        aminal.useSkill(address(safeSkill), actionData);
        assertEq(safeSkill.callCount(), 1);
        assertEq(aminal.energy(), 9995); // 10000 - 5
        
        aminal.useSkill(address(safeSkill), actionData);
        assertEq(safeSkill.callCount(), 2);
        assertEq(aminal.energy(), 9990); // 9995 - 5
        
        aminal.useSkill(address(safeSkill), actionData);
        assertEq(safeSkill.callCount(), 3);
        assertEq(aminal.energy(), 9985); // 9990 - 5
        
        vm.stopPrank();
    }
    
    function test_ProtectionAcrossMultipleContracts() public {
        // Test that reentrancy protection works even through different contracts
        ChainedReentrantSkill chainedSkill = new ChainedReentrantSkill(address(aminal), address(reentrantSkill));
        
        // Feed the Aminal
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 1 ether}("");
        assertTrue(success);
        
        // Try chained reentrancy
        bytes memory chainData = abi.encodeWithSelector(ChainedReentrantSkill.chainAttack.selector);
        
        vm.prank(user1);
        vm.expectRevert(Aminal.SkillCallFailed.selector);
        aminal.useSkill(address(chainedSkill), chainData);
    }
}

// Skill that chains to another reentrant skill
contract ChainedReentrantSkill is Skill {
    Aminal public aminal;
    address public otherSkill;
    
    constructor(address _aminal, address _otherSkill) {
        aminal = Aminal(payable(_aminal));
        otherSkill = _otherSkill;
    }
    
    function chainAttack() external {
        // Try to call another skill that will attempt reentrancy
        bytes memory data = abi.encodeWithSelector(ReentrantSkill.attack.selector);
        aminal.useSkill(otherSkill, data);
    }
    
    function skillCost(bytes calldata) external pure returns (uint256) {
        return 15;
    }
}