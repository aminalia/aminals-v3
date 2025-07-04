// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {Aminal} from "src/Aminal.sol";
import {ITraits} from "src/interfaces/ITraits.sol";

// Malicious contract that attempts reentrancy
contract ReentrantSkill {
    Aminal public aminal;
    uint256 public attackCount;
    bool public attacking;
    
    constructor(Aminal _aminal) {
        aminal = _aminal;
    }
    
    // This skill attempts to re-enter useSkill during execution
    function maliciousSkill() external returns (uint256) {
        attackCount++;
        
        if (!attacking) {
            attacking = true;
            // Try to call useSkill again (reentrancy attempt)
            bytes memory data = abi.encodeWithSelector(this.maliciousSkill.selector);
            try aminal.useSkill(address(this), data) {
                // If this succeeds, reentrancy protection failed
            } catch {
                // Expected - reentrancy should be blocked
            }
            attacking = false;
        }
        
        return 10; // Cost 10 energy
    }
}

contract AminalReentrancyTest is Test {
    Aminal public aminal;
    ReentrantSkill public reentrantSkill;
    
    address public user1 = makeAddr("user1");
    
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
        
        reentrantSkill = new ReentrantSkill(aminal);
        
        // Fund user
        deal(user1, 10 ether);
    }
    
    function test_ReentrancyProtection() public {
        // Feed the Aminal to give it energy and love
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 1 ether}("");
        assertTrue(success);
        
        uint256 initialEnergy = aminal.energy();
        uint256 initialLove = aminal.loveFromUser(user1);
        
        // Call the malicious skill
        bytes memory skillData = abi.encodeWithSelector(ReentrantSkill.maliciousSkill.selector);
        
        vm.prank(user1);
        aminal.useSkill(address(reentrantSkill), skillData);
        
        // Should have only executed once despite reentrancy attempt
        assertEq(reentrantSkill.attackCount(), 1, "Skill should only execute once");
        
        // Should have consumed energy/love only once
        assertEq(aminal.energy(), initialEnergy - 10);
        assertEq(aminal.loveFromUser(user1), initialLove - 10);
    }
    
    function test_LegitimateSequentialCalls() public {
        // Feed the Aminal
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 1 ether}("");
        assertTrue(success);
        
        uint256 initialEnergy = aminal.energy();
        uint256 initialLove = aminal.loveFromUser(user1);
        
        // Make two legitimate sequential calls
        bytes memory skillData = abi.encodeWithSelector(ReentrantSkill.maliciousSkill.selector);
        
        vm.prank(user1);
        aminal.useSkill(address(reentrantSkill), skillData);
        
        vm.prank(user1);
        aminal.useSkill(address(reentrantSkill), skillData);
        
        // Both calls should succeed (nested call is blocked by reentrancy guard)
        assertEq(reentrantSkill.attackCount(), 2, "Should count two successful calls (nested attempts blocked)");
        
        // Should have consumed energy/love twice
        assertEq(aminal.energy(), initialEnergy - 20);
        assertEq(aminal.loveFromUser(user1), initialLove - 20);
    }
}