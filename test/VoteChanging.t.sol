// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {BreedingSkill} from "src/skills/BreedingSkill.sol";
import {AminalBreedingVote} from "src/AminalBreedingVote.sol";
import {AminalFactory} from "src/AminalFactory.sol";
import {Aminal} from "src/Aminal.sol";
import {IGenes} from "src/interfaces/IGenes.sol";
import {MockGene} from "./mocks/MockGene.sol";

contract VoteChangingTest is Test {
    BreedingSkill public breedingSkill;
    AminalBreedingVote public breedingVote;
    AminalFactory public factory;
    
    Aminal public parent1;
    Aminal public parent2;
    
    address public owner;
    address public breederA;
    address public breederB;
    address public voter;
    
    uint256 constant BREEDING_COST = 2500;
    
    function setUp() public {
        owner = makeAddr("owner");
        breederA = makeAddr("breederA");
        breederB = makeAddr("breederB");
        voter = makeAddr("voter");
        
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
        factory = new AminalFactory(owner, firstParentData, secondParentData);
        
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
        vm.deal(voter, 10 ether);
    }
    
    function test_VotingPowerLockedAtFirstVote() public {
        uint256 ticketId = _createBreedingTicket();
        
        // Warp to voting phase (after 3 days gene proposal phase)
        vm.warp(block.timestamp + 3 days + 1);
        
        // Voter feeds parents to get initial love
        vm.prank(voter);
        (bool success,) = address(parent1).call{value: 0.1 ether}("");
        assertTrue(success);
        vm.prank(voter);
        (success,) = address(parent2).call{value: 0.1 ether}("");
        assertTrue(success);
        
        // Check initial voting power
        (, uint256 initialPower) = breedingVote.canVote(ticketId, voter);
        uint256 expectedPower = parent1.loveFromUser(voter) + parent2.loveFromUser(voter);
        assertEq(initialPower, expectedPower);
        
        // Vote for first time
        AminalBreedingVote.GeneType[] memory geneTypes = new AminalBreedingVote.GeneType[](1);
        bool[] memory votes = new bool[](1);
        geneTypes[0] = AminalBreedingVote.GeneType.BACK;
        votes[0] = true;
        
        vm.prank(voter);
        breedingVote.vote(ticketId, geneTypes, votes);
        
        // Verify voting power is locked
        assertEq(breedingVote.voterPower(ticketId, voter), expectedPower);
        
        // Voter feeds more to increase love
        vm.prank(voter);
        (success,) = address(parent1).call{value: 0.5 ether}("");
        assertTrue(success);
        
        // Check that voting power is still the locked amount
        (, uint256 lockedPower) = breedingVote.canVote(ticketId, voter);
        assertEq(lockedPower, expectedPower); // Should be the same as initial
        
        // Verify actual love increased but voting power didn't
        uint256 newActualLove = parent1.loveFromUser(voter) + parent2.loveFromUser(voter);
        assertTrue(newActualLove > expectedPower);
        assertEq(breedingVote.voterPower(ticketId, voter), expectedPower);
    }
    
    function test_CanChangeTraitVotes() public {
        uint256 ticketId = _createBreedingTicket();
        
        // Warp to voting phase (after 3 days gene proposal phase)
        vm.warp(block.timestamp + 3 days + 1);
        
        // Voter feeds parents
        vm.prank(voter);
        (bool success,) = address(parent1).call{value: 0.2 ether}("");
        assertTrue(success);
        vm.prank(voter);
        (success,) = address(parent2).call{value: 0.2 ether}("");
        assertTrue(success);
        
        // Initial vote for parent1
        AminalBreedingVote.GeneType[] memory geneTypes = new AminalBreedingVote.GeneType[](2);
        bool[] memory votes = new bool[](2);
        geneTypes[0] = AminalBreedingVote.GeneType.BACK;
        geneTypes[1] = AminalBreedingVote.GeneType.ARM;
        votes[0] = true;  // parent1
        votes[1] = true;  // parent1
        
        vm.prank(voter);
        breedingVote.vote(ticketId, geneTypes, votes);
        
        // Check initial vote counts
        (uint256[8] memory parent1Votes, uint256[8] memory parent2Votes) = breedingVote.getVoteResults(ticketId);
        uint256 votingPower = breedingVote.voterPower(ticketId, voter);
        
        assertEq(parent1Votes[0], votingPower); // BACK
        assertEq(parent1Votes[1], votingPower); // ARM
        assertEq(parent2Votes[0], 0);
        assertEq(parent2Votes[1], 0);
        
        // Change vote to parent2
        votes[0] = false;  // parent2
        votes[1] = false;  // parent2
        
        vm.prank(voter);
        breedingVote.vote(ticketId, geneTypes, votes);
        
        // Check vote counts changed
        (parent1Votes, parent2Votes) = breedingVote.getVoteResults(ticketId);
        
        assertEq(parent1Votes[0], 0); // BACK moved to parent2
        assertEq(parent1Votes[1], 0); // ARM moved to parent2
        assertEq(parent2Votes[0], votingPower);
        assertEq(parent2Votes[1], votingPower);
    }
    
    function test_CanChangeVetoVote() public {
        uint256 ticketId = _createBreedingTicket();
        
        // Warp to voting phase (after 3 days gene proposal phase)
        vm.warp(block.timestamp + 3 days + 1);
        
        // Voter feeds parents
        vm.prank(voter);
        (bool success,) = address(parent1).call{value: 0.2 ether}("");
        assertTrue(success);
        
        // Initial vote for veto
        vm.prank(voter);
        breedingVote.voteOnVeto(ticketId, true);
        
        uint256 votingPower = breedingVote.voterPower(ticketId, voter);
        (uint256 vetoVotes, uint256 proceedVotes,) = breedingVote.getVetoStatus(ticketId);
        
        assertEq(vetoVotes, votingPower);
        assertEq(proceedVotes, 0);
        
        // Change vote to proceed
        vm.prank(voter);
        breedingVote.voteOnVeto(ticketId, false);
        
        (vetoVotes, proceedVotes,) = breedingVote.getVetoStatus(ticketId);
        
        assertEq(vetoVotes, 0);
        assertEq(proceedVotes, votingPower);
        
        // Change back to veto
        vm.prank(voter);
        breedingVote.voteOnVeto(ticketId, true);
        
        (vetoVotes, proceedVotes,) = breedingVote.getVetoStatus(ticketId);
        
        assertEq(vetoVotes, votingPower);
        assertEq(proceedVotes, 0);
    }
    
    function test_GeneVotesUseLockedPower() public {
        uint256 ticketId = _createBreedingTicket();
        
        // Voter feeds parents
        vm.prank(voter);
        (bool success,) = address(parent1).call{value: 0.1 ether}("");
        assertTrue(success);
        
        // Propose a gene first (in gene proposal phase)
        vm.prank(breederA);
        (success,) = address(parent1).call{value: 0.02 ether}("");
        assertTrue(success);
        
        // Create a mock gene contract
        MockGene geneContract = new MockGene();
        geneContract.mint(address(this), "<svg>Rainbow Wings</svg>", "back", "Rainbow Wings");
        
        // Propose the gene
        vm.prank(breederA);
        breedingVote.proposeGene(
            ticketId,
            AminalBreedingVote.GeneType.BACK,
            address(geneContract),
            1
        );
        
        // Warp to voting phase (after 3 days gene proposal phase)
        vm.warp(block.timestamp + 3 days + 1);
        
        // Vote on trait first to lock power
        AminalBreedingVote.GeneType[] memory geneTypes = new AminalBreedingVote.GeneType[](1);
        bool[] memory votes = new bool[](1);
        geneTypes[0] = AminalBreedingVote.GeneType.BACK;
        votes[0] = true;
        
        vm.prank(voter);
        breedingVote.vote(ticketId, geneTypes, votes);
        
        uint256 lockedPower = breedingVote.voterPower(ticketId, voter);
        
        // Feed more to increase actual love
        vm.prank(voter);
        (success,) = address(parent1).call{value: 0.5 ether}("");
        assertTrue(success);
        
        // Vote for gene - should use locked power, not current
        vm.prank(voter);
        breedingVote.voteForGene(ticketId, AminalBreedingVote.GeneType.BACK, 0);
        
        uint256 geneVotes = breedingVote.getGeneVotes(
            ticketId,
            AminalBreedingVote.GeneType.BACK,
            0
        );
        
        assertEq(geneVotes, lockedPower);
        
        // Verify locked power hasn't changed despite feeding more
        uint256 actualLove = parent1.loveFromUser(voter) + parent2.loveFromUser(voter);
        assertTrue(actualLove > lockedPower);
        assertEq(breedingVote.voterPower(ticketId, voter), lockedPower);
    }
    
    function test_PartialVoting() public {
        uint256 ticketId = _createBreedingTicket();
        
        // Warp to voting phase (after 3 days gene proposal phase)
        vm.warp(block.timestamp + 3 days + 1);
        
        // Voter feeds parents
        vm.prank(voter);
        (bool success,) = address(parent1).call{value: 0.2 ether}("");
        assertTrue(success);
        
        // Vote on some traits
        AminalBreedingVote.GeneType[] memory geneTypes = new AminalBreedingVote.GeneType[](2);
        bool[] memory votes = new bool[](2);
        geneTypes[0] = AminalBreedingVote.GeneType.BACK;
        geneTypes[1] = AminalBreedingVote.GeneType.FACE;
        votes[0] = true;  // parent1
        votes[1] = false; // parent2
        
        vm.prank(voter);
        breedingVote.vote(ticketId, geneTypes, votes);
        
        // Vote on different traits
        geneTypes = new AminalBreedingVote.GeneType[](2);
        votes = new bool[](2);
        geneTypes[0] = AminalBreedingVote.GeneType.ARM;
        geneTypes[1] = AminalBreedingVote.GeneType.TAIL;
        votes[0] = false; // parent2
        votes[1] = true;  // parent1
        
        vm.prank(voter);
        breedingVote.vote(ticketId, geneTypes, votes);
        
        // Change one of the previous votes
        geneTypes = new AminalBreedingVote.GeneType[](1);
        votes = new bool[](1);
        geneTypes[0] = AminalBreedingVote.GeneType.BACK;
        votes[0] = false; // Change to parent2
        
        vm.prank(voter);
        breedingVote.vote(ticketId, geneTypes, votes);
        
        // Verify all votes are correct
        (uint256[8] memory parent1Votes, uint256[8] memory parent2Votes) = breedingVote.getVoteResults(ticketId);
        uint256 votingPower = breedingVote.voterPower(ticketId, voter);
        
        assertEq(parent2Votes[0], votingPower); // BACK changed to parent2
        assertEq(parent2Votes[1], votingPower); // ARM voted parent2
        assertEq(parent1Votes[2], votingPower); // TAIL voted parent1
        assertEq(parent2Votes[5], votingPower); // FACE voted parent2
    }
    
    // Helper function to create breeding ticket
    function _createBreedingTicket() internal returns (uint256 ticketId) {
        // Breeder A creates proposal
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
        
        // Breeder B accepts
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