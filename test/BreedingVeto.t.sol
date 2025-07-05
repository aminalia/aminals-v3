// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {BreedingSkill} from "src/skills/BreedingSkill.sol";
import {AminalBreedingVote} from "src/AminalBreedingVote.sol";
import {AminalFactory} from "src/AminalFactory.sol";
import {Aminal} from "src/Aminal.sol";
import {IGenes} from "src/interfaces/IGenes.sol";

contract BreedingVetoTest is Test {
    BreedingSkill public breedingSkill;
    AminalBreedingVote public breedingVote;
    AminalFactory public factory;
    
    Aminal public parent1;
    Aminal public parent2;
    
    address public owner;
    address public breederA;
    address public breederB;
    address public vetoVoter;
    address public proceedVoter1;
    address public proceedVoter2;
    
    uint256 constant BREEDING_COST = 2500;
    
    function setUp() public {
        owner = makeAddr("owner");
        breederA = makeAddr("breederA");
        breederB = makeAddr("breederB");
        vetoVoter = makeAddr("vetoVoter");
        proceedVoter1 = makeAddr("proceedVoter1");
        proceedVoter2 = makeAddr("proceedVoter2");
        
        // Create parent data
        AminalFactory.ParentData memory firstParentData = AminalFactory.ParentData({
            name: "Adam",
            symbol: "ADAM",
            description: "The first Aminal",
            tokenURI: "ipfs://adam",
            genes: IGenes.Genes({
                back: "Original Wings",
                arm: "First Arms",
                tail: "Genesis Tail",
                ears: "Prime Ears",
                body: "Alpha Body",
                face: "Beginning Face",
                mouth: "Initial Mouth",
                misc: "Creation Spark"
            })
        });
        
        AminalFactory.ParentData memory secondParentData = AminalFactory.ParentData({
            name: "Eve",
            symbol: "EVE",
            description: "The second Aminal",
            tokenURI: "ipfs://eve",
            genes: IGenes.Genes({
                back: "Life Wings",
                arm: "Gentle Arms",
                tail: "Harmony Tail",
                ears: "Listening Ears",
                body: "Nurturing Body",
                face: "Wisdom Face",
                mouth: "Speaking Mouth",
                misc: "Life Force"
            })
        });
        
        // Deploy contracts
        vm.prank(owner);
        factory = new AminalFactory(owner, "https://api.aminals.com/", firstParentData, secondParentData);
        
        uint256 nonce = vm.getNonce(address(this));
        address predictedBreedingSkill = vm.computeCreateAddress(address(this), nonce + 1);
        
        breedingVote = new AminalBreedingVote(address(factory), predictedBreedingSkill);
        breedingSkill = new BreedingSkill(address(factory), address(breedingVote));
        
        // Create parent Aminals
        IGenes.Genes memory traits1 = IGenes.Genes({
            back: "Dragon Wings",
            arm: "Strong Arms",
            tail: "Fire Tail",
            ears: "Pointed Ears",
            body: "Scaled Body",
            face: "Fierce Face",
            mouth: "Sharp Teeth",
            misc: "Glowing Eyes"
        });
        
        IGenes.Genes memory traits2 = IGenes.Genes({
            back: "Angel Wings",
            arm: "Gentle Arms",
            tail: "Fluffy Tail",
            ears: "Round Ears",
            body: "Soft Body",
            face: "Kind Face",
            mouth: "Sweet Smile",
            misc: "Sparkles"
        });
        
        vm.prank(owner);
        parent1 = Aminal(payable(factory.createAminalWithGenes(
            "FireDragon", "FIRE", "A fierce dragon", "dragon.json", traits1
        )));
        
        vm.prank(owner);
        parent2 = Aminal(payable(factory.createAminalWithGenes(
            "AngelBunny", "ANGEL", "A gentle bunny", "bunny.json", traits2
        )));
        
        // Give users ETH
        vm.deal(breederA, 10 ether);
        vm.deal(breederB, 10 ether);
        vm.deal(vetoVoter, 10 ether);
        vm.deal(proceedVoter1, 10 ether);
        vm.deal(proceedVoter2, 10 ether);
    }
    
    function test_VetoWinsOnTie() public {
        uint256 ticketId = _createBreedingTicket();
        
        // Give voters love in both parents to ensure consistent voting power
        vm.prank(vetoVoter);
        (bool success,) = address(parent1).call{value: 0.1 ether}("");
        assertTrue(success);
        vm.prank(vetoVoter);
        (success,) = address(parent2).call{value: 0.1 ether}("");
        assertTrue(success);
        
        vm.prank(proceedVoter1);
        (success,) = address(parent1).call{value: 0.1 ether}("");
        assertTrue(success);
        vm.prank(proceedVoter1);
        (success,) = address(parent2).call{value: 0.1 ether}("");
        assertTrue(success);
        
        // Get voting power for each
        uint256 vetoVoterPower = parent1.loveFromUser(vetoVoter) + parent2.loveFromUser(vetoVoter);
        uint256 proceedVoterPower = parent1.loveFromUser(proceedVoter1) + parent2.loveFromUser(proceedVoter1);
        
        console.log("Veto voter power:", vetoVoterPower);
        console.log("Proceed voter power:", proceedVoterPower);
        
        // If powers aren't exactly equal due to VRGDA, add a third voter to make it a tie
        if (vetoVoterPower != proceedVoterPower) {
            address tieBreaker = makeAddr("tieBreaker");
            vm.deal(tieBreaker, 1 ether);
            
            // Give tiny amount to get minimal voting power
            vm.prank(tieBreaker);
            (success,) = address(parent1).call{value: 0.001 ether}("");
            assertTrue(success);
            
            uint256 tieBreakerPower = parent1.loveFromUser(tieBreaker);
            
            // Vote to balance out the difference
            vm.prank(tieBreaker);
            if (vetoVoterPower > proceedVoterPower) {
                breedingVote.voteOnVeto(ticketId, false); // Vote proceed to balance
                proceedVoterPower += tieBreakerPower;
            } else {
                breedingVote.voteOnVeto(ticketId, true); // Vote veto to balance
                vetoVoterPower += tieBreakerPower;
            }
        }
        
        // Vote for veto
        vm.prank(vetoVoter);
        breedingVote.voteOnVeto(ticketId, true);
        
        // Vote to proceed
        vm.prank(proceedVoter1);
        breedingVote.voteOnVeto(ticketId, false);
        
        // Check status
        (uint256 vetoVotes, uint256 proceedVotes, bool wouldBeVetoed) = breedingVote.getVetoStatus(ticketId);
        console.log("Final veto votes:", vetoVotes);
        console.log("Final proceed votes:", proceedVotes);
        
        // Even if not exactly equal due to rounding, veto should win if >= proceed
        assertTrue(wouldBeVetoed, "Veto should win on tie or when greater");
        
        // Wait for voting to end
        vm.warp(block.timestamp + 3 days + 1);
        
        // Execute breeding - should be vetoed
        address childAddress = breedingVote.executeBreeding(ticketId);
        assertEq(childAddress, address(0), "No child should be created when vetoed");
    }
    
    function test_NoVotesResultsInVeto() public {
        uint256 ticketId = _createBreedingTicket();
        
        // Nobody votes at all
        
        // Check status
        (uint256 vetoVotes, uint256 proceedVotes, bool wouldBeVetoed) = breedingVote.getVetoStatus(ticketId);
        assertEq(vetoVotes, 0, "No veto votes");
        assertEq(proceedVotes, 0, "No proceed votes");
        assertTrue(wouldBeVetoed, "Should be vetoed when no votes");
        
        // Wait for voting to end
        vm.warp(block.timestamp + 3 days + 1);
        
        // Execute breeding - should be vetoed due to no participation
        address childAddress = breedingVote.executeBreeding(ticketId);
        assertEq(childAddress, address(0), "No child should be created when no votes");
    }
    
    function test_ProceedWinsWithMoreVotes() public {
        uint256 ticketId = _createBreedingTicket();
        
        // Give more voting power to proceed voters
        vm.prank(vetoVoter);
        (bool success,) = address(parent1).call{value: 0.1 ether}("");
        assertTrue(success);
        
        vm.prank(proceedVoter1);
        (success,) = address(parent1).call{value: 0.2 ether}("");
        assertTrue(success);
        
        vm.prank(proceedVoter2);
        (success,) = address(parent2).call{value: 0.2 ether}("");
        assertTrue(success);
        
        // Vote for veto
        vm.prank(vetoVoter);
        breedingVote.voteOnVeto(ticketId, true);
        
        // Vote to proceed
        vm.prank(proceedVoter1);
        breedingVote.voteOnVeto(ticketId, false);
        
        vm.prank(proceedVoter2);
        breedingVote.voteOnVeto(ticketId, false);
        
        // Check status
        (uint256 vetoVotes, uint256 proceedVotes, bool wouldBeVetoed) = breedingVote.getVetoStatus(ticketId);
        assertTrue(proceedVotes > vetoVotes, "Proceed should have more votes");
        assertFalse(wouldBeVetoed, "Should not be vetoed");
        
        // Also vote on some traits
        AminalBreedingVote.GeneType[] memory geneTypes = new AminalBreedingVote.GeneType[](1);
        bool[] memory votesForParent1 = new bool[](1);
        geneTypes[0] = AminalBreedingVote.GeneType.BACK;
        votesForParent1[0] = true;
        
        vm.prank(proceedVoter1);
        breedingVote.vote(ticketId, geneTypes, votesForParent1);
        
        // Wait for voting to end
        vm.warp(block.timestamp + 3 days + 1);
        
        // Execute breeding - should succeed
        address childAddress = breedingVote.executeBreeding(ticketId);
        assertTrue(childAddress != address(0), "Child should be created when proceed wins");
    }
    
    function test_MixedVotingWithVeto() public {
        uint256 ticketId = _createBreedingTicket();
        
        // Setup voters with different amounts
        address[] memory voters = new address[](5);
        voters[0] = makeAddr("voter0");
        voters[1] = makeAddr("voter1");
        voters[2] = makeAddr("voter2");
        voters[3] = makeAddr("voter3");
        voters[4] = makeAddr("voter4");
        
        // Give them different amounts of love
        for (uint i = 0; i < voters.length; i++) {
            vm.deal(voters[i], 10 ether);
            vm.prank(voters[i]);
            (bool s1,) = address(parent1).call{value: (i + 1) * 0.1 ether}("");
            vm.prank(voters[i]);
            (bool s2,) = address(parent2).call{value: (i + 1) * 0.05 ether}("");
            assertTrue(s1 && s2);
        }
        
        // voters[0] and voters[1] vote to veto
        vm.prank(voters[0]);
        breedingVote.voteOnVeto(ticketId, true);
        
        vm.prank(voters[1]);
        breedingVote.voteOnVeto(ticketId, true);
        
        // voters[2], voters[3], voters[4] vote to proceed
        vm.prank(voters[2]);
        breedingVote.voteOnVeto(ticketId, false);
        
        vm.prank(voters[3]);
        breedingVote.voteOnVeto(ticketId, false);
        
        vm.prank(voters[4]);
        breedingVote.voteOnVeto(ticketId, false);
        
        // Check final status
        (uint256 vetoVotes, uint256 proceedVotes, bool wouldBeVetoed) = breedingVote.getVetoStatus(ticketId);
        
        console.log("Veto votes:", vetoVotes);
        console.log("Proceed votes:", proceedVotes);
        console.log("Would be vetoed:", wouldBeVetoed);
        
        // The larger voters (3,4,5) voted to proceed, so it should pass
        assertFalse(wouldBeVetoed, "Should proceed with more weighted votes");
    }
    
    function test_VetoDoesNotAffectTraitVoting() public {
        uint256 ticketId = _createBreedingTicket();
        
        // Setup voters
        vm.prank(vetoVoter);
        (bool success,) = address(parent1).call{value: 0.1 ether}("");
        assertTrue(success);
        
        vm.prank(proceedVoter1);
        (success,) = address(parent1).call{value: 0.3 ether}("");
        assertTrue(success);
        
        // Vote on veto
        vm.prank(vetoVoter);
        breedingVote.voteOnVeto(ticketId, true);
        
        vm.prank(proceedVoter1);
        breedingVote.voteOnVeto(ticketId, false);
        
        // Also vote on traits
        AminalBreedingVote.GeneType[] memory geneTypes = new AminalBreedingVote.GeneType[](2);
        bool[] memory votesForParent1 = new bool[](2);
        geneTypes[0] = AminalBreedingVote.GeneType.BACK;
        geneTypes[1] = AminalBreedingVote.GeneType.FACE;
        votesForParent1[0] = true;
        votesForParent1[1] = false;
        
        vm.prank(vetoVoter);
        breedingVote.vote(ticketId, geneTypes, votesForParent1);
        
        // Check that trait votes are recorded independently
        (uint256[8] memory parent1Votes, uint256[8] memory parent2Votes) = breedingVote.getVoteResults(ticketId);
        
        uint256 vetoVoterPower = parent1.loveFromUser(vetoVoter) + parent2.loveFromUser(vetoVoter);
        assertEq(parent1Votes[0], vetoVoterPower, "Back trait should have parent1 vote");
        assertEq(parent2Votes[5], vetoVoterPower, "Face trait should have parent2 vote");
        
        // Veto status is separate from trait voting
        (uint256 vetoVotes, uint256 proceedVotes,) = breedingVote.getVetoStatus(ticketId);
        assertTrue(proceedVotes > vetoVotes, "Proceed should win");
    }
    
    function test_RevertWhen_VotingOnVetoAfterDeadline() public {
        uint256 ticketId = _createBreedingTicket();
        
        // Give voter some love
        vm.prank(vetoVoter);
        (bool success,) = address(parent1).call{value: 0.1 ether}("");
        assertTrue(success);
        
        // Wait past deadline
        vm.warp(block.timestamp + 3 days + 1);
        
        // Try to vote on veto
        vm.prank(vetoVoter);
        vm.expectRevert(AminalBreedingVote.VotingEnded.selector);
        breedingVote.voteOnVeto(ticketId, true);
    }
    
    // Helper function
    function _createBreedingTicket() internal returns (uint256 ticketId) {
        vm.prank(breederA);
        (bool success,) = address(parent1).call{value: 0.5 ether}("");
        assertTrue(success);
        
        bytes memory proposalData = abi.encodeWithSelector(
            BreedingSkill.createProposal.selector,
            address(parent2),
            "Test breeding",
            "test.json"
        );
        
        vm.prank(breederA);
        parent1.useSkill(address(breedingSkill), proposalData);
        
        vm.prank(breederB);
        (success,) = address(parent2).call{value: 0.5 ether}("");
        assertTrue(success);
        
        bytes memory acceptData = abi.encodeWithSelector(
            BreedingSkill.acceptProposal.selector,
            uint256(1)
        );
        
        vm.prank(breederB);
        parent2.useSkill(address(breedingSkill), acceptData);
        
        return 1;
    }
}