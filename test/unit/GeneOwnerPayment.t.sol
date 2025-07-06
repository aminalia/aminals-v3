// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {AminalBreedingVote} from "src/AminalBreedingVote.sol";
import {AminalFactory} from "src/AminalFactory.sol";
import {BreedingSkill} from "src/skills/BreedingSkill.sol";
import {BreedingPaymentSkill} from "src/skills/BreedingPaymentSkill.sol";
import {Aminal} from "src/Aminal.sol";
import {Gene} from "src/Gene.sol";
import {IGenes} from "src/interfaces/IGenes.sol";
import {BreedingTestBase} from "../base/BreedingTestBase.sol";

contract GeneOwnerPaymentTest is BreedingTestBase {
    BreedingPaymentSkill public paymentSkill;
    Gene public geneContract;
    
    address public geneOwner1 = makeAddr("geneOwner1");
    address public geneOwner2 = makeAddr("geneOwner2");
    
    uint256 public geneTokenId1;
    uint256 public geneTokenId2;
    
    function setUp() public override {
        super.setUp();
        
        // Deploy payment skill
        paymentSkill = new BreedingPaymentSkill(address(breedingVote));
        
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
        _feedAminal(breederA, address(parent1), 10 ether);
        _feedAminal(breederB, address(parent2), 10 ether);
        
        // Give breeders more funds for testing
        vm.deal(breederA, 100 ether);
        vm.deal(breederB, 100 ether);
    }
    
    function test_GeneOwnerPayment_FullFlow() public {
        // Create breeding proposal
        uint256 ticketId = _createBreedingTicketForTest();
        console2.log("Breeding ticket ID:", ticketId);
        
        // Check if ticket exists
        (address p1, address p2,,,,,bool executed,,) = breedingVote.tickets(ticketId);
        console2.log("Parent1:", p1);
        console2.log("Parent2:", p2);
        console2.log("Executed:", executed);
        
        // Propose genes
        _proposeGenes(ticketId);
        
        // Vote for proposed genes
        _voteForProposedGenes(ticketId);
        
        // Execute breeding
        _executeBreeding(ticketId);
        
        // Verify gene owners need to be paid
        (address[] memory geneOwners, bool parent1Paid, bool parent2Paid,) = 
            breedingVote.getPendingPaymentInfo(ticketId);
        
        assertEq(geneOwners.length, 2);
        assertFalse(parent1Paid);
        assertFalse(parent2Paid);
        
        // Record initial balances
        uint256 geneOwner1BalanceBefore = geneOwner1.balance;
        uint256 geneOwner2BalanceBefore = geneOwner2.balance;
        uint256 parent1BalanceBefore = address(parent1).balance;
        uint256 parent2BalanceBefore = address(parent2).balance;
        
        // Parent1 pays gene owners using skill
        vm.prank(breederA);
        bytes memory paymentData = abi.encode(ticketId);
        parent1.useSkill(address(paymentSkill), paymentData);
        
        // Verify parent1 paid
        (,parent1Paid,,) = breedingVote.getPendingPaymentInfo(ticketId);
        assertTrue(parent1Paid);
        
        // Verify balances changed correctly (10% of parent1's balance split between 2 gene owners)
        uint256 expectedPaymentPerOwner = (parent1BalanceBefore / 10) / 2;
        assertEq(geneOwner1.balance, geneOwner1BalanceBefore + expectedPaymentPerOwner);
        assertEq(geneOwner2.balance, geneOwner2BalanceBefore + expectedPaymentPerOwner);
        
        // Parent2 pays gene owners
        vm.prank(breederB);
        parent2.useSkill(address(paymentSkill), paymentData);
        
        // Verify both parents have paid
        (,parent1Paid, parent2Paid,) = breedingVote.getPendingPaymentInfo(ticketId);
        assertTrue(parent1Paid);
        assertTrue(parent2Paid);
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
        
        // Execute breeding
        vm.warp(block.timestamp + 4 days + 1);
        breedingVote.executeBreeding(ticketId);
        
        // Verify no gene owners to pay
        (address[] memory geneOwners,,,) = breedingVote.getPendingPaymentInfo(ticketId);
        assertEq(geneOwners.length, 0);
        
        // Payment should succeed but do nothing
        vm.prank(breederA);
        bytes memory paymentData = abi.encode(ticketId);
        parent1.useSkill(address(paymentSkill), paymentData);
    }
    
    function test_GeneOwnerPayment_OnlyParentsCanPay() public {
        uint256 ticketId = _createBreedingTicketForTest();
        _executeBreedingWithProposedGenes(ticketId);
        
        // Non-parent tries to pay
        address nonParent = makeAddr("nonParent");
        vm.deal(nonParent, 10 ether);
        
        vm.prank(nonParent);
        vm.expectRevert("Only parents can pay");
        breedingVote.payGeneOwners{value: 1 ether}(ticketId);
    }
    
    function test_GeneOwnerPayment_PreventDoublePaying() public {
        uint256 ticketId = _createBreedingTicketForTest();
        _executeBreedingWithProposedGenes(ticketId);
        
        // Parent1 pays first time
        vm.prank(breederA);
        bytes memory paymentData = abi.encode(ticketId);
        parent1.useSkill(address(paymentSkill), paymentData);
        
        // Parent1 tries to pay again
        vm.prank(breederA);
        vm.expectRevert("Payment call failed");
        parent1.useSkill(address(paymentSkill), paymentData);
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
        
        // Get the proposal ID (nextProposalId has already been incremented, so it's the current value)
        uint256 proposalId = breedingSkill.nextProposalId();
        
        // BreederB accepts breeding using acceptProposal function
        vm.prank(breederB);
        bytes memory acceptData = abi.encodeWithSelector(
            BreedingSkill.acceptProposal.selector,
            proposalId
        );
        parent2.useSkill(address(breedingSkill), acceptData);
        
        // nextTicketId is incremented after creation, so the current ticket is nextTicketId - 1
        // But we need to check if nextTicketId is 0 (nothing created yet)
        uint256 nextId = breedingVote.nextTicketId();
        require(nextId > 0, "No breeding ticket created");
        return nextId - 1;
    }
    
    function _proposeGenes(uint256 ticketId) internal {
        // Wait for gene proposal phase (not needed since we're already in it)
        // vm.warp(block.timestamp + 1);
        
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
        vm.prank(breederA);
        breedingVote.voteForGene(ticketId, AminalBreedingVote.GeneType.BACK, 0);
        breedingVote.voteForGene(ticketId, AminalBreedingVote.GeneType.TAIL, 0);
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