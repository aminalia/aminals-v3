// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {Aminal} from "src/Aminal.sol";
import {ITraits} from "src/interfaces/ITraits.sol";
import {ISkill} from "src/interfaces/ISkill.sol";
import {Skill} from "src/Skill.sol";

// Skill that expects ETH
contract GreedySkill is Skill {
    uint256 public ethReceived;
    
    function payableAction() external payable {
        ethReceived += msg.value;
    }
    
    function normalAction() external pure returns (string memory) {
        return "Normal action";
    }
    
    function skillCost(bytes calldata data) external pure returns (uint256) {
        bytes4 selector = bytes4(data);
        if (selector == this.payableAction.selector) {
            return 50;
        } else if (selector == this.normalAction.selector) {
            return 10;
        }
        return 1;
    }
}

// Malicious skill trying to drain funds
contract MaliciousSkill is Skill {
    address payable public attacker;
    
    constructor() {
        attacker = payable(msg.sender);
    }
    
    function stealFunds() external payable {
        if (msg.value > 0) {
            attacker.transfer(msg.value);
        }
    }
    
    function selfdestructAttack() external {
        selfdestruct(attacker);
    }
    
    function skillCost(bytes calldata) external pure returns (uint256) {
        return 5; // Low cost to encourage usage
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
        // Feed the Aminal
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 1 ether}("");
        assertTrue(success);
        
        uint256 aminalBalanceBefore = address(aminal).balance;
        uint256 skillBalanceBefore = address(greedySkill).balance;
        
        // Call payable skill - should work but send 0 ETH
        bytes memory skillData = abi.encodeWithSelector(GreedySkill.payableAction.selector);
        
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
    
    function test_NormalNonPayableSkillsWork() public {
        // Feed the Aminal
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 1 ether}("");
        assertTrue(success);
        
        uint256 energyBefore = aminal.energy();
        uint256 loveBefore = aminal.loveFromUser(user1);
        
        // Call normal skill
        bytes memory skillData = abi.encodeWithSelector(GreedySkill.normalAction.selector);
        
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
        bytes memory skill1 = abi.encodeWithSelector(GreedySkill.payableAction.selector);
        bytes memory skill2 = abi.encodeWithSelector(GreedySkill.normalAction.selector);
        bytes memory skill3 = abi.encodeWithSelector(MaliciousSkill.stealFunds.selector);
        
        vm.startPrank(user1);
        aminal.useSkill(address(greedySkill), skill1);
        aminal.useSkill(address(greedySkill), skill2);
        aminal.useSkill(address(maliciousSkill), skill3);
        vm.stopPrank();
        
        // Balance should remain unchanged
        assertEq(address(aminal).balance, initialBalance, "Aminal balance should never decrease from skills");
    }
    
    function test_SelfdestructDoesNotDrainFunds() public {
        // Feed the Aminal
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 1 ether}("");
        assertTrue(success);
        
        uint256 aminalBalanceBefore = address(aminal).balance;
        
        // Try selfdestruct attack
        bytes memory skillData = abi.encodeWithSelector(MaliciousSkill.selfdestructAttack.selector);
        
        vm.prank(user1);
        aminal.useSkill(address(maliciousSkill), skillData);
        
        // Verify no funds were transferred (post-Cancun, selfdestruct doesn't transfer funds)
        assertEq(address(aminal).balance, aminalBalanceBefore, "Aminal funds should be safe");
        
        // Note: Post-Cancun, selfdestruct only transfers funds if called in the same transaction
        // as contract creation, so attacker balance should remain the same
    }
}