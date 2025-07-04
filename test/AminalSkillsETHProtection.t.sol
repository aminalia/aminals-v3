// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {Aminal} from "src/Aminal.sol";
import {ITraits} from "src/interfaces/ITraits.sol";

// Contract that expects to receive ETH
contract GreedySkill {
    uint256 public ethReceived;
    
    // This function expects to be called with ETH
    function payableSkill() external payable returns (uint256) {
        ethReceived += msg.value;
        return 50; // Costs 50 energy
    }
    
    // Regular non-payable skill
    function normalSkill() external returns (uint256) {
        return 10; // Costs 10 energy
    }
}

// Contract that tries to trick Aminal into sending ETH
contract MaliciousSkill {
    address payable public attacker;
    
    constructor() {
        attacker = payable(msg.sender);
    }
    
    // Skill that tries to forward ETH to attacker
    function stealFunds() external payable returns (uint256) {
        if (msg.value > 0) {
            attacker.transfer(msg.value);
        }
        return 5; // Low cost to encourage usage
    }
    
    // Skill that tries to selfdestruct and send funds
    function selfDestructAttack() external returns (uint256) {
        // Note: selfdestruct is deprecated but still exists
        // This should fail because no ETH is sent
        selfdestruct(attacker);
        return 1;
    }
}

contract AminalSkillsETHProtectionTest is Test {
    Aminal public aminal;
    GreedySkill public greedySkill;
    MaliciousSkill public maliciousSkill;
    
    address public user1 = makeAddr("user1");
    address public attacker = makeAddr("attacker");
    
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
        
        greedySkill = new GreedySkill();
        
        vm.prank(attacker);
        maliciousSkill = new MaliciousSkill();
        
        // Fund user and give Aminal significant ETH balance
        deal(user1, 10 ether);
        deal(address(aminal), 100 ether); // Aminal has 100 ETH
    }
    
    function test_CannotSendETHToPayableSkill() public {
        // Feed the Aminal to give it energy and love
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 1 ether}("");
        assertTrue(success);
        
        uint256 aminalBalanceBefore = address(aminal).balance;
        uint256 skillBalanceBefore = address(greedySkill).balance;
        
        // Try to call payable skill - should work but send 0 ETH
        bytes memory skillData = abi.encodeWithSelector(GreedySkill.payableSkill.selector);
        
        vm.prank(user1);
        aminal.useSkill(address(greedySkill), skillData);
        
        // Verify no ETH was sent
        assertEq(address(aminal).balance, aminalBalanceBefore, "Aminal should not lose ETH");
        assertEq(address(greedySkill).balance, skillBalanceBefore, "Skill should not receive ETH");
        assertEq(greedySkill.ethReceived(), 0, "Skill should record 0 ETH received");
    }
    
    function test_CannotStealFundsThroughMaliciousSkill() public {
        // Feed the Aminal
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 1 ether}("");
        assertTrue(success);
        
        uint256 aminalBalanceBefore = address(aminal).balance;
        uint256 attackerBalanceBefore = attacker.balance;
        
        // Try malicious skill
        bytes memory skillData = abi.encodeWithSelector(MaliciousSkill.stealFunds.selector);
        
        vm.prank(user1);
        aminal.useSkill(address(maliciousSkill), skillData);
        
        // Verify no funds were stolen
        assertEq(address(aminal).balance, aminalBalanceBefore, "Aminal funds should be safe");
        assertEq(attacker.balance, attackerBalanceBefore, "Attacker should not receive funds");
    }
    
    function test_NormalNonPayableSkillsStillWork() public {
        // Feed the Aminal
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 1 ether}("");
        assertTrue(success);
        
        uint256 energyBefore = aminal.energy();
        uint256 loveBefore = aminal.loveFromUser(user1);
        
        // Call normal skill
        bytes memory skillData = abi.encodeWithSelector(GreedySkill.normalSkill.selector);
        
        vm.prank(user1);
        aminal.useSkill(address(greedySkill), skillData);
        
        // Verify skill executed properly
        assertEq(aminal.energy(), energyBefore - 10, "Should consume 10 energy");
        assertEq(aminal.loveFromUser(user1), loveBefore - 10, "Should consume 10 love");
    }
    
    function test_AminalBalancePreservedAcrossMultipleSkills() public {
        // Feed the Aminal
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 2 ether}("");
        assertTrue(success);
        
        uint256 initialBalance = address(aminal).balance;
        
        // Try multiple different skills
        bytes memory skill1 = abi.encodeWithSelector(GreedySkill.payableSkill.selector);
        bytes memory skill2 = abi.encodeWithSelector(GreedySkill.normalSkill.selector);
        bytes memory skill3 = abi.encodeWithSelector(MaliciousSkill.stealFunds.selector);
        
        vm.startPrank(user1);
        aminal.useSkill(address(greedySkill), skill1);
        aminal.useSkill(address(greedySkill), skill2);
        aminal.useSkill(address(maliciousSkill), skill3);
        vm.stopPrank();
        
        // Balance should remain unchanged
        assertEq(address(aminal).balance, initialBalance, "Aminal balance should never decrease from skills");
    }
    
    function testFuzz_NoETHSentRegardlessOfCalldata(bytes calldata arbitraryData) public {
        // Feed the Aminal
        vm.deal(user1, 10 ether);
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 1 ether}("");
        assertTrue(success);
        
        uint256 balanceBefore = address(aminal).balance;
        
        // Try arbitrary calldata (might revert, but should never send ETH)
        vm.prank(user1);
        try aminal.useSkill(address(greedySkill), arbitraryData) {
            // If it succeeds, balance should be unchanged
            assertEq(address(aminal).balance, balanceBefore);
        } catch {
            // Even if it reverts, balance should be unchanged
            assertEq(address(aminal).balance, balanceBefore);
        }
    }
}