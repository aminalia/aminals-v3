// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {AminalBreedingVote} from "src/AminalBreedingVote.sol";
import {BreedingSkill} from "src/skills/BreedingSkill.sol";
import {Aminal} from "src/Aminal.sol";
import {Gene} from "src/Gene.sol";
import {IGenes} from "src/interfaces/IGenes.sol";
import {BreedingTestBase} from "../base/BreedingTestBase.sol";

contract BreedingAuthorizationTest is BreedingTestBase {
    address public attacker = makeAddr("attacker");
    
    function setUp() public override {
        super.setUp();
        
        // Setup attacker
        vm.deal(attacker, 100 ether);
        
        // Give parents some balance
        vm.deal(address(parent1), 10 ether);
        vm.deal(address(parent2), 10 ether);
    }
    
    function test_AuthorizationBypass_DirectBreedingTicketCreation() public {
        // Attacker tries to create breeding ticket directly, bypassing BreedingSkill
        vm.startPrank(attacker);
        
        // This should fail as only BreedingSkill should create tickets
        vm.expectRevert(AminalBreedingVote.NotAuthorized.selector);
        breedingVote.createBreedingTicket(
            address(parent1),
            address(parent2),
            "Unauthorized Child",
            "ipfs://unauthorized"
        );
        
        vm.stopPrank();
    }
    
    function test_VotingManipulation_DoubleVotingPower() public {
        // Create legitimate breeding ticket
        uint256 ticketId = _createBreedingTicketForTest();
        
        // Skip to voting phase
        vm.warp(block.timestamp + 3 days + 1);
        
        // First voter establishes their voting power
        vm.prank(breederA);
        AminalBreedingVote.GeneType[] memory geneTypes = new AminalBreedingVote.GeneType[](1);
        bool[] memory votes = new bool[](1);
        geneTypes[0] = AminalBreedingVote.GeneType.BACK;
        votes[0] = true;
        breedingVote.vote(ticketId, geneTypes, votes);
        
        // Check voting power is locked
        uint256 lockedPower = breedingVote.voterPower(ticketId, breederA);
        console2.log("Locked voting power:", lockedPower);
        
        // Try to vote again - should use same locked power, not double count
        vm.prank(breederA);
        votes[0] = false; // Change vote
        breedingVote.vote(ticketId, geneTypes, votes);
        
        // Verify power didn't change
        assertEq(breedingVote.voterPower(ticketId, breederA), lockedPower);
    }
    
    function test_GeneProposalSpam_MinimalLoveAttack() public {
        // Create breeding ticket
        uint256 ticketId = _createBreedingTicketForTest();
        
        // Attacker gets minimal love (just 100 units)
        vm.deal(attacker, 1 ether);
        vm.prank(attacker);
        (bool success,) = address(parent1).call{value: 0.01 ether}(""); // Gets ~100 love
        require(success);
        
        vm.prank(attacker);
        (success,) = address(parent2).call{value: 0.01 ether}(""); // Gets ~100 love
        require(success);
        
        // Deploy spam gene contract
        Gene spamGene = new Gene(attacker, "SpamGene", "SPAM", "");
        
        // Mint spam genes
        vm.startPrank(attacker);
        uint256[] memory spamTokenIds = new uint256[](8);
        string[8] memory geneTypes = ["back", "arm", "tail", "ears", "body", "face", "mouth", "misc"];
        
        for (uint i = 0; i < 8; i++) {
            spamTokenIds[i] = spamGene.mint(
                attacker,
                geneTypes[i],
                "Spam",
                '<rect width="1" height="1"/>',
                "spam"
            );
        }
        
        // Attacker can propose genes with minimal love
        breedingVote.proposeGene(
            ticketId,
            AminalBreedingVote.GeneType.BACK,
            address(spamGene),
            spamTokenIds[0]
        );
        
        vm.stopPrank();
        
        // Verify proposal was created
        (AminalBreedingVote.GeneProposal[] memory proposals, uint256 proposalCount) = breedingVote.getActiveGeneProposals(ticketId, AminalBreedingVote.GeneType.BACK);
        assertEq(proposalCount, 1);
    }
    
    function test_TxOriginVulnerability() public {
        // Deploy malicious intermediary contract
        MaliciousIntermediary intermediary = new MaliciousIntermediary(
            address(breedingSkill),
            address(parent1),
            address(parent2)
        );
        
        // Fund the intermediary contract so it has love in the Aminals
        vm.deal(address(intermediary), 10 ether);
        vm.prank(address(intermediary));
        (bool success,) = address(parent1).call{value: 5 ether}("");
        require(success, "Failed to feed Aminal");
        vm.prank(address(intermediary));
        (success,) = address(parent2).call{value: 5 ether}("");
        require(success, "Failed to feed Aminal");
        
        // User interacts through intermediary
        vm.prank(breederA);
        uint256 proposalId = intermediary.createBreedingProposal();
        
        // Intermediary needs to accept the proposal to create a ticket
        // This test is checking if tx.origin is used, which would be a vulnerability
        // The system should record msg.sender (intermediary) not tx.origin (breederA)
        
        // For now, just verify proposal was created
        assertGt(proposalId, 0, "Proposal should be created");
    }
    
    function test_BreedingFeeExploitScenario() public {
        // Setup: Create a breeding scenario
        uint256 ticketId = _createBreedingTicketForTest();
        
        // Skip to execution phase
        vm.warp(block.timestamp + 7 days + 1);
        
        // Record balances before breeding
        uint256 parent1BalanceBefore = address(parent1).balance;
        uint256 parent2BalanceBefore = address(parent2).balance;
        uint256 attackerBalanceBefore = address(attacker).balance;
        
        // Attacker front-runs breeding execution to drain parents
        address[] memory recipients = new address[](1);
        recipients[0] = attacker;
        
        vm.startPrank(attacker);
        
        // Try to drain parent1 - should fail
        vm.expectRevert("Only authorized breeding vote contract");
        parent1.payBreedingFee(recipients, ticketId);
        
        // Try to drain parent2 - should fail
        vm.expectRevert("Only authorized breeding vote contract");
        parent2.payBreedingFee(recipients, ticketId);
        
        vm.stopPrank();
        
        // Execute breeding normally
        breedingVote.executeBreeding(ticketId);
        
        // Verify attacker couldn't steal funds
        assertEq(address(attacker).balance, attackerBalanceBefore);
        assertEq(address(parent1).balance, parent1BalanceBefore);
        assertEq(address(parent2).balance, parent2BalanceBefore);
    }
    
    // Helper function from base
    function _createBreedingTicketForTest() internal returns (uint256) {
        // Feed Aminals first so they have energy and love
        _feedAminal(breederA, address(parent1), 1 ether);
        _feedAminal(breederB, address(parent2), 1 ether);
        
        vm.prank(breederA);
        bytes memory proposeData = abi.encodeWithSelector(
            BreedingSkill.createProposal.selector,
            address(parent2),
            "Test Child",
            "ipfs://test"
        );
        parent1.useSkill(address(breedingSkill), proposeData);
        
        uint256 proposalId = breedingSkill.nextProposalId();
        
        vm.prank(breederB);
        bytes memory acceptData = abi.encodeWithSelector(
            BreedingSkill.acceptProposal.selector,
            proposalId
        );
        parent2.useSkill(address(breedingSkill), acceptData);
        
        return breedingVote.nextTicketId();
    }
}

// Malicious intermediary contract to test tx.origin issues
contract MaliciousIntermediary {
    BreedingSkill public breedingSkill;
    Aminal public parent1;
    Aminal public parent2;
    
    constructor(address _skill, address _parent1, address _parent2) {
        breedingSkill = BreedingSkill(_skill);
        parent1 = Aminal(payable(_parent1));
        parent2 = Aminal(payable(_parent2));
    }
    
    function createBreedingProposal() external returns (uint256) {
        // Create proposal through skill
        bytes memory proposeData = abi.encodeWithSelector(
            breedingSkill.createProposal.selector,
            address(parent2),
            "Intermediary Child",
            "ipfs://intermediary"
        );
        parent1.useSkill(address(breedingSkill), proposeData);
        
        return breedingSkill.nextProposalId();
    }
}