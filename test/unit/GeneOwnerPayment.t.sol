// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {AminalBreedingVote} from "src/AminalBreedingVote.sol";
import {AminalFactory} from "src/AminalFactory.sol";
import {BreedingSkill} from "src/skills/BreedingSkill.sol";
import {Aminal} from "src/Aminal.sol";
import {Gene} from "src/Gene.sol";
import {IGenes} from "src/interfaces/IGenes.sol";
import {BreedingTestBase} from "../base/BreedingTestBase.sol";

contract GeneOwnerPaymentTest is BreedingTestBase {
    Gene public geneContract;
    
    address public geneOwner1 = makeAddr("geneOwner1");
    address public geneOwner2 = makeAddr("geneOwner2");
    
    uint256 public geneTokenId1;
    uint256 public geneTokenId2;
    
    function setUp() public override {
        super.setUp();
        
        
        // Deploy gene contract
        geneContract = new Gene(address(this), "TestGene", "GENE", "");
        
        // Mint gene NFTs to owners
        geneTokenId1 = geneContract.mint(
            geneOwner1,
            "back",
            "Dragon Wings",
            '<rect width="100" height="100" fill="red"/>',
            "Epic dragon wings"
        );
        
        geneTokenId2 = geneContract.mint(
            geneOwner2,
            "tail",
            "Fire Tail",
            '<rect width="50" height="50" fill="orange"/>',
            "Flaming tail"
        );
        
        // Feed parents to give them energy and love
        // Each breeder needs love in BOTH parents to propose genes
        _feedAminal(breederA, address(parent1), 5 ether);
        _feedAminal(breederA, address(parent2), 5 ether);
        _feedAminal(breederB, address(parent1), 5 ether);
        _feedAminal(breederB, address(parent2), 5 ether);
        
        // Give breeders more funds for testing
        vm.deal(breederA, 100 ether);
        vm.deal(breederB, 100 ether);
    }
    
    function test_GeneOwnerPayment_FullFlow() public {
        // Create breeding proposal
        uint256 ticketId = _createBreedingTicketForTest();
        
        
        // Propose genes
        _proposeGenes(ticketId);
        
        // Vote for proposed genes
        _voteForProposedGenes(ticketId);
        
        // Record initial balances
        uint256 geneOwner1BalanceBefore = geneOwner1.balance;
        uint256 geneOwner2BalanceBefore = geneOwner2.balance;
        uint256 parent1BalanceBefore = address(parent1).balance;
        uint256 parent2BalanceBefore = address(parent2).balance;
        
        // Execute breeding - this should automatically pay gene owners
        _executeBreeding(ticketId);
        
        // Verify balances changed correctly
        // Each parent should have paid 10% of their balance
        uint256 parent1Payment = parent1BalanceBefore / 10;
        uint256 parent2Payment = parent2BalanceBefore / 10;
        uint256 totalPayment = parent1Payment + parent2Payment;
        uint256 expectedPaymentPerOwner = totalPayment / 2;
        
        // Gene owners should have received payments
        assertEq(geneOwner1.balance, geneOwner1BalanceBefore + expectedPaymentPerOwner);
        assertEq(geneOwner2.balance, geneOwner2BalanceBefore + expectedPaymentPerOwner);
        
        // Parents should have paid 10% each
        assertEq(address(parent1).balance, parent1BalanceBefore - parent1Payment);
        assertEq(address(parent2).balance, parent2BalanceBefore - parent2Payment);
    }
    
    function test_GeneOwnerPayment_NoGeneOwners() public {
        // Create breeding without proposed genes
        uint256 ticketId = _createBreedingTicketForTest();
        
        // Skip to voting phase
        vm.warp(block.timestamp + 3 days + 1);
        
        // Vote for parent genes only
        vm.prank(breederA);
        AminalBreedingVote.GeneType[] memory geneTypes = new AminalBreedingVote.GeneType[](2);
        bool[] memory votesForParent1 = new bool[](2);
        geneTypes[0] = AminalBreedingVote.GeneType.BACK;
        geneTypes[1] = AminalBreedingVote.GeneType.TAIL;
        votesForParent1[0] = true;
        votesForParent1[1] = false;
        breedingVote.vote(ticketId, geneTypes, votesForParent1);
        
        // Record balances before breeding
        uint256 parent1BalanceBefore = address(parent1).balance;
        uint256 parent2BalanceBefore = address(parent2).balance;
        
        // Execute breeding
        vm.warp(block.timestamp + 4 days + 1);
        breedingVote.executeBreeding(ticketId);
        
        // Verify no payments were made (balances unchanged)
        assertEq(address(parent1).balance, parent1BalanceBefore);
        assertEq(address(parent2).balance, parent2BalanceBefore);
    }
    
    function test_GeneOwnerPayment_InsufficientBalance() public {
        // Create breeding proposal
        uint256 ticketId = _createBreedingTicketForTest();
        
        // Propose genes
        _proposeGenes(ticketId);
        
        // Vote for proposed genes
        _voteForProposedGenes(ticketId);
        
        // Drain parent1's balance
        vm.prank(address(parent1));
        payable(breederA).transfer(address(parent1).balance);
        
        // Record balances
        uint256 geneOwner1BalanceBefore = geneOwner1.balance;
        uint256 geneOwner2BalanceBefore = geneOwner2.balance;
        uint256 parent2BalanceBefore = address(parent2).balance;
        
        // Execute breeding - parent1 payment should fail but parent2 should succeed
        _executeBreeding(ticketId);
        
        // Only parent2 should have paid
        uint256 parent2Payment = parent2BalanceBefore / 10;
        uint256 expectedPaymentPerOwner = parent2Payment / 2;
        
        assertEq(geneOwner1.balance, geneOwner1BalanceBefore + expectedPaymentPerOwner);
        assertEq(geneOwner2.balance, geneOwner2BalanceBefore + expectedPaymentPerOwner);
        assertEq(address(parent2).balance, parent2BalanceBefore - parent2Payment);
        assertEq(address(parent1).balance, 0); // Parent1 had no balance to pay
    }
    
    // Helper functions
    function _createBreedingTicketForTest() internal returns (uint256) {
        // BreederA proposes breeding using createProposal function
        vm.prank(breederA);
        bytes memory proposeData = abi.encodeWithSelector(
            BreedingSkill.createProposal.selector,
            address(parent2),
            "Child Description",
            "ipfs://child"
        );
        parent1.useSkill(address(breedingSkill), proposeData);
        
        // Get the proposal ID (nextProposalId is the current proposal ID after pre-increment)
        uint256 proposalId = breedingSkill.nextProposalId();
        
        // BreederB accepts breeding using acceptProposal function
        vm.prank(breederB);
        bytes memory acceptData = abi.encodeWithSelector(
            BreedingSkill.acceptProposal.selector,
            proposalId
        );
        parent2.useSkill(address(breedingSkill), acceptData);
        
        // nextTicketId was pre-incremented, so it equals the current ticket ID
        return breedingVote.nextTicketId();
    }
    
    function _proposeGenes(uint256 ticketId) internal {
        // Propose gene 1
        vm.prank(breederA);
        breedingVote.proposeGene(
            ticketId,
            AminalBreedingVote.GeneType.BACK,
            address(geneContract),
            geneTokenId1
        );
        
        // Propose gene 2
        vm.prank(breederB);
        breedingVote.proposeGene(
            ticketId,
            AminalBreedingVote.GeneType.TAIL,
            address(geneContract),
            geneTokenId2
        );
    }
    
    function _voteForProposedGenes(uint256 ticketId) internal {
        // Skip to voting phase
        vm.warp(block.timestamp + 3 days + 1);
        
        // Vote for proposed genes
        vm.startPrank(breederA);
        breedingVote.voteForGene(ticketId, AminalBreedingVote.GeneType.BACK, 0);
        breedingVote.voteForGene(ticketId, AminalBreedingVote.GeneType.TAIL, 0);
        // Vote to proceed with breeding (not veto)
        breedingVote.voteOnVeto(ticketId, false); // false = proceed
        vm.stopPrank();
    }
    
    function _executeBreeding(uint256 ticketId) internal {
        // Skip to execution phase
        vm.warp(block.timestamp + 4 days + 1);
        
        // Execute breeding
        breedingVote.executeBreeding(ticketId);
    }
    
    function _executeBreedingWithProposedGenes(uint256 ticketId) internal {
        _proposeGenes(ticketId);
        _voteForProposedGenes(ticketId);
        _executeBreeding(ticketId);
    }
}