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
    
    // Mock the breedingVoteContract function that Aminal.payBreedingFee will call
    function breedingVoteContract() external pure returns (address) {
        // Return a different address so the attacker's call will fail
        return address(0xDEADBEEF);
    }
    
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
        
        // Should revert - only authorized breeding vote contract can call
        vm.expectRevert(bytes("Only authorized breeding vote contract"));
        aminal.payBreedingFee(recipients, 12345); // Random ticket ID
        
        vm.stopPrank();
        
        // Verify the security worked - no funds were stolen
        uint256 aminalBalanceAfter = address(aminal).balance;
        uint256 attackerBalanceAfter = attacker.balance;
        
        assertEq(aminalBalanceAfter, aminalBalanceBefore);
        assertEq(attackerBalanceAfter, attackerBalanceBefore); // Attacker gained no ETH
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
        
        // Should revert - only authorized breeding vote contract can call
        vm.prank(attacker);
        vm.expectRevert(bytes("Only authorized breeding vote contract"));
        aminal.payBreedingFee(recipients, 1);
        
        // Verify no funds were stolen
        assertEq(address(aminal).balance, aminalBalanceBefore);
        assertEq(attacker.balance, 10 ether); // Initial balance
        assertEq(attacker2.balance, 0);
        assertEq(attacker3.balance, 0);
    }
    
    function test_SecurityVulnerability_NoTicketValidation() public {
        // Attacker can use ANY ticket ID - even non-existent ones
        address[] memory recipients = new address[](1);
        recipients[0] = attacker;
        
        vm.startPrank(attacker);
        
        // All attempts should fail - only authorized breeding vote contract can call
        vm.expectRevert(bytes("Only authorized breeding vote contract"));
        aminal.payBreedingFee(recipients, 0);
        
        vm.expectRevert(bytes("Only authorized breeding vote contract"));
        aminal.payBreedingFee(recipients, type(uint256).max);
        
        vm.expectRevert(bytes("Only authorized breeding vote contract"));
        aminal.payBreedingFee(recipients, 424242424242);
        
        vm.stopPrank();
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
        vm.expectRevert(bytes("Only authorized breeding vote contract"));
        aminal.payBreedingFee(recipients, 1);
        
        // Verify no reentrancy occurred
        assertEq(address(aminal).balance, balanceBefore);
        assertEq(address(malicious).balance, 0);
        assertEq(malicious.reentrancyAttempts(), 0);
    }
    
    function testFuzz_DrainAmountCalculation(uint256 balance) public {
        balance = bound(balance, 1 ether, 1000 ether);
        
        // Record initial balance
        uint256 initialBalance = address(aminal).balance;
        
        // Fund an Aminal
        vm.deal(address(this), balance);
        (bool success,) = address(aminal).call{value: balance}("");
        require(success);
        
        address[] memory recipients = new address[](1);
        recipients[0] = attacker;
        
        // Should revert - only authorized breeding vote contract can call
        vm.prank(attacker);
        vm.expectRevert(bytes("Only authorized breeding vote contract"));
        aminal.payBreedingFee(recipients, 1);
        
        // Verify balance unchanged
        assertEq(address(aminal).balance, initialBalance + balance);
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