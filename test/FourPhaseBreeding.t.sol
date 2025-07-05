// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {BreedingSkill} from "src/skills/BreedingSkill.sol";
import {AminalBreedingVote} from "src/AminalBreedingVote.sol";
import {AminalFactory} from "src/AminalFactory.sol";
import {Aminal} from "src/Aminal.sol";
import {IGenes} from "src/interfaces/IGenes.sol";
import {MockGene} from "./mocks/MockGene.sol";

contract FourPhaseBreedingTest is Test {
    BreedingSkill public breedingSkill;
    AminalBreedingVote public breedingVote;
    AminalFactory public factory;
    MockGene public geneContract;
    
    Aminal public parent1;
    Aminal public parent2;
    
    address public owner;
    address public breederA;
    address public breederB;
    address public proposer1;
    address public proposer2;
    address public proposer3;
    address public voter1;
    address public voter2;
    
    uint256 constant BREEDING_COST = 2500;
    uint256 constant MIN_LOVE_FOR_GENE = 100;
    uint256 constant GENE_PROPOSAL_DURATION = 3 days;
    uint256 constant VOTING_DURATION = 4 days;
    
    function setUp() public {
        owner = makeAddr("owner");
        breederA = makeAddr("breederA");
        breederB = makeAddr("breederB");
        proposer1 = makeAddr("proposer1");
        proposer2 = makeAddr("proposer2");
        proposer3 = makeAddr("proposer3");
        voter1 = makeAddr("voter1");
        voter2 = makeAddr("voter2");
        
        // Create parent data
        AminalFactory.ParentData memory firstParentData = AminalFactory.ParentData({
            name: "Adam",
            symbol: "ADAM",
            description: "The first Aminal",
            tokenURI: "ipfs://adam",
            traits: IGenes.Genes({
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
            traits: IGenes.Genes({
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
        
        // Predict addresses for circular dependency
        uint256 nonce = vm.getNonce(address(this));
        address predictedBreedingSkill = vm.computeCreateAddress(address(this), nonce + 1);
        
        breedingVote = new AminalBreedingVote(address(factory), predictedBreedingSkill);
        breedingSkill = new BreedingSkill(address(factory), address(breedingVote));
        
        // Deploy gene contract
        geneContract = new MockGene();
        geneContract.createTestGenes();
        
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
        parent1 = Aminal(payable(factory.createAminalWithTraits(
            "FireDragon", "FIRE", "A fierce dragon", "dragon.json", traits1
        )));
        
        vm.prank(owner);
        parent2 = Aminal(payable(factory.createAminalWithTraits(
            "AngelBunny", "ANGEL", "A gentle bunny", "bunny.json", traits2
        )));
        
        // Give users ETH
        vm.deal(breederA, 10 ether);
        vm.deal(breederB, 10 ether);
        vm.deal(proposer1, 10 ether);
        vm.deal(proposer2, 10 ether);
        vm.deal(proposer3, 10 ether);
        vm.deal(voter1, 10 ether);
        vm.deal(voter2, 10 ether);
    }
    
    function test_FourPhaseFlow() public {
        // Phase 0: Proposal and Acceptance (existing system)
        uint256 ticketId = _createBreedingTicket();
        
        // Verify we're in gene proposal phase
        assertEq(uint256(breedingVote.getCurrentPhase(ticketId)), uint256(AminalBreedingVote.Phase.GENE_PROPOSAL));
        
        // Phase 1: Gene Proposal Phase
        _testGeneProposalPhase(ticketId);
        
        // Advance to voting phase
        vm.warp(block.timestamp + GENE_PROPOSAL_DURATION + 1);
        assertEq(uint256(breedingVote.getCurrentPhase(ticketId)), uint256(AminalBreedingVote.Phase.VOTING));
        
        // Phase 2: Voting Phase
        _testVotingPhase(ticketId);
        
        // Advance to execution phase
        vm.warp(block.timestamp + VOTING_DURATION);
        assertEq(uint256(breedingVote.getCurrentPhase(ticketId)), uint256(AminalBreedingVote.Phase.EXECUTION));
        
        // Phase 3: Execution Phase
        address childAddress = breedingVote.executeBreeding(ticketId);
        
        // Verify child was created
        assertTrue(childAddress != address(0), "Child should have been created");
        assertEq(uint256(breedingVote.getCurrentPhase(ticketId)), uint256(AminalBreedingVote.Phase.COMPLETED));
        
        // Verify child was created with expected traits
        Aminal child = Aminal(payable(childAddress));
        IGenes.Genes memory childTraits = child.getTraits();
        
        // Based on voting, Rainbow Wings gene should have won for back trait
        assertEq(childTraits.back, "Rainbow Wings");
    }
    
    function test_CannotProposeGeneInWrongPhase() public {
        uint256 ticketId = _createBreedingTicket();
        
        // Give proposer some love
        vm.prank(proposer1);
        (bool success,) = address(parent1).call{value: 0.02 ether}("");
        assertTrue(success);
        
        // Move to voting phase
        vm.warp(block.timestamp + GENE_PROPOSAL_DURATION + 1);
        
        // Try to propose gene in voting phase
        vm.prank(proposer1);
        vm.expectRevert(abi.encodeWithSelector(
            AminalBreedingVote.WrongPhase.selector,
            AminalBreedingVote.Phase.VOTING,
            AminalBreedingVote.Phase.GENE_PROPOSAL
        ));
        breedingVote.proposeGene(
            ticketId,
            AminalBreedingVote.GeneType.BACK,
            address(geneContract),
            1
        );
    }
    
    function test_CannotVoteInWrongPhase() public {
        uint256 ticketId = _createBreedingTicket();
        
        // Give voter some love
        vm.prank(voter1);
        (bool success,) = address(parent1).call{value: 0.1 ether}("");
        assertTrue(success);
        
        // Try to vote in gene proposal phase
        AminalBreedingVote.GeneType[] memory geneTypes = new AminalBreedingVote.GeneType[](1);
        bool[] memory votes = new bool[](1);
        geneTypes[0] = AminalBreedingVote.GeneType.BACK;
        votes[0] = true;
        
        vm.prank(voter1);
        vm.expectRevert(abi.encodeWithSelector(
            AminalBreedingVote.WrongPhase.selector,
            AminalBreedingVote.Phase.GENE_PROPOSAL,
            AminalBreedingVote.Phase.VOTING
        ));
        breedingVote.vote(ticketId, geneTypes, votes);
    }
    
    function test_OneGeneProposalPerUser() public {
        uint256 ticketId = _createBreedingTicket();
        
        // Give proposer love in both parents
        vm.prank(proposer1);
        (bool success,) = address(parent1).call{value: 0.01 ether}("");
        assertTrue(success);
        vm.prank(proposer1);
        (success,) = address(parent2).call{value: 0.01 ether}("");
        assertTrue(success);
        
        // First proposal
        vm.prank(proposer1);
        breedingVote.proposeGene(
            ticketId,
            AminalBreedingVote.GeneType.BACK,
            address(geneContract),
            1 // Rainbow Wings
        );
        
        // Check active proposal
        (AminalBreedingVote.GeneType geneType, uint256 proposalId, bool hasProposal) = 
            breedingVote.userActiveProposal(ticketId, proposer1);
        assertTrue(hasProposal);
        assertEq(uint256(geneType), uint256(AminalBreedingVote.GeneType.BACK));
        assertEq(proposalId, 0);
        
        // Replace with new proposal
        vm.prank(proposer1);
        breedingVote.proposeGene(
            ticketId,
            AminalBreedingVote.GeneType.ARM,
            address(geneContract),
            3 // Laser Arms
        );
        
        // Check updated active proposal
        (geneType, proposalId, hasProposal) = breedingVote.userActiveProposal(ticketId, proposer1);
        assertTrue(hasProposal);
        assertEq(uint256(geneType), uint256(AminalBreedingVote.GeneType.ARM));
        assertEq(proposalId, 0); // First gene proposal for ARM category
        
        // Verify old proposal was marked as replaced
        AminalBreedingVote.GeneProposal[] memory allBackProposals = breedingVote.getGeneProposals(
            ticketId, 
            AminalBreedingVote.GeneType.BACK
        );
        assertEq(allBackProposals[0].proposer, address(0)); // Replaced proposals have proposer cleared
    }
    
    function test_GetActiveGeneProposals() public {
        uint256 ticketId = _createBreedingTicket();
        
        // Multiple proposers create and replace proposals
        address[] memory proposers = new address[](3);
        proposers[0] = proposer1;
        proposers[1] = proposer2;
        proposers[2] = proposer3;
        
        // Give all proposers love
        for (uint i = 0; i < proposers.length; i++) {
            vm.prank(proposers[i]);
            (bool s1,) = address(parent1).call{value: 0.01 ether}("");
            vm.prank(proposers[i]);
            (bool s2,) = address(parent2).call{value: 0.01 ether}("");
            assertTrue(s1 && s2);
        }
        
        // Proposer1: Creates then replaces
        vm.prank(proposer1);
        breedingVote.proposeGene(ticketId, AminalBreedingVote.GeneType.BACK, address(geneContract), 1);
        vm.prank(proposer1);
        breedingVote.proposeGene(ticketId, AminalBreedingVote.GeneType.BACK, address(geneContract), 2);
        
        // Proposer2: Creates one
        vm.prank(proposer2);
        breedingVote.proposeGene(ticketId, AminalBreedingVote.GeneType.BACK, address(geneContract), 1);
        
        // Proposer3: Creates for different gene category
        vm.prank(proposer3);
        breedingVote.proposeGene(ticketId, AminalBreedingVote.GeneType.ARM, address(geneContract), 3);
        
        // Get active proposals for BACK gene category
        (AminalBreedingVote.GeneProposal[] memory activeProposals, uint256 activeCount) = 
            breedingVote.getActiveGeneProposals(ticketId, AminalBreedingVote.GeneType.BACK);
        
        assertEq(activeCount, 2); // proposer1's second proposal and proposer2's proposal
        assertEq(activeProposals.length, 2);
        
        // Verify the active proposals
        assertEq(activeProposals[0].proposer, proposer1);
        assertEq(activeProposals[0].tokenId, 2); // Crystal Wings
        
        assertEq(activeProposals[1].proposer, proposer2);
        assertEq(activeProposals[1].tokenId, 1); // Rainbow Wings
    }
    
    function test_ReplacedGenesCannotWinVoting() public {
        uint256 ticketId = _createBreedingTicket();
        
        // Proposer1 creates gene proposal then replaces it
        vm.prank(proposer1);
        (bool success,) = address(parent1).call{value: 0.02 ether}("");
        assertTrue(success);
        
        vm.prank(proposer1);
        breedingVote.proposeGene(
            ticketId,
            AminalBreedingVote.GeneType.BACK,
            address(geneContract),
            1 // Rainbow Wings
        );
        
        // Proposer1 replaces their proposal with a different one
        vm.prank(proposer1);
        breedingVote.proposeGene(
            ticketId,
            AminalBreedingVote.GeneType.ARM,
            address(geneContract),
            3 // Laser Arms - different gene type
        );
        
        // Move to voting phase
        vm.warp(block.timestamp + GENE_PROPOSAL_DURATION + 1);
        
        // Voter tries to vote for the replaced gene (should revert)
        vm.prank(voter1);
        (success,) = address(parent1).call{value: 1 ether}("");
        assertTrue(success);
        
        vm.prank(voter1);
        vm.expectRevert("Gene proposal was replaced");
        breedingVote.voteForGene(ticketId, AminalBreedingVote.GeneType.BACK, 0);
        
        // Voter2 votes to proceed
        vm.prank(voter2);
        (success,) = address(parent1).call{value: 0.1 ether}("");
        assertTrue(success);
        
        vm.prank(voter2);
        breedingVote.voteOnVeto(ticketId, false);
        
        // Move to execution phase
        vm.warp(block.timestamp + VOTING_DURATION);
        
        // Execute breeding
        address childAddress = breedingVote.executeBreeding(ticketId);
        
        // Check that child was created (not vetoed)
        assertTrue(childAddress != address(0), "Child should have been created");
        
        Aminal child = Aminal(payable(childAddress));
        
        // Verify the replaced gene didn't win despite having votes
        IGenes.Genes memory childTraits = child.getTraits();
        assertEq(childTraits.back, "Dragon Wings"); // Parent1's trait wins (no votes)
    }
    
    // Helper functions
    
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
        
        return 1; // First ticket ID
    }
    
    function _testGeneProposalPhase(uint256 ticketId) internal {
        // Proposer1 feeds parent2 (not parent1) to get some love
        vm.prank(proposer1);
        (bool success,) = address(parent2).call{value: 0.02 ether}("");
        assertTrue(success);
        
        // Proposer2 feeds both parents
        vm.prank(proposer2);
        (success,) = address(parent1).call{value: 0.01 ether}("");
        assertTrue(success);
        vm.prank(proposer2);
        (success,) = address(parent2).call{value: 0.01 ether}("");
        assertTrue(success);
        
        // Proposer1 proposes Rainbow Wings
        vm.prank(proposer1);
        breedingVote.proposeGene(
            ticketId,
            AminalBreedingVote.GeneType.BACK,
            address(geneContract),
            1
        );
        
        // Proposer2 proposes Crystal Wings
        vm.prank(proposer2);
        breedingVote.proposeGene(
            ticketId,
            AminalBreedingVote.GeneType.BACK,
            address(geneContract),
            2
        );
        
        // Verify proposals exist
        (AminalBreedingVote.GeneProposal[] memory activeProposals,) = 
            breedingVote.getActiveGeneProposals(ticketId, AminalBreedingVote.GeneType.BACK);
        assertEq(activeProposals.length, 2);
    }
    
    function _testVotingPhase(uint256 ticketId) internal {
        // Voter1 feeds both parents to get high voting power
        vm.prank(voter1);
        (bool success,) = address(parent1).call{value: 1 ether}("");
        assertTrue(success);
        vm.prank(voter1);
        (success,) = address(parent2).call{value: 1 ether}("");
        assertTrue(success);
        
        // Voter2 feeds with less to have lower voting power
        vm.prank(voter2);
        (success,) = address(parent1).call{value: 0.1 ether}("");
        assertTrue(success);
        vm.prank(voter2);
        (success,) = address(parent2).call{value: 0.1 ether}("");
        assertTrue(success);
        
        // Voter1 votes for Rainbow Wings gene (proposalId 0) with high voting power
        vm.prank(voter1);
        breedingVote.voteForGene(ticketId, AminalBreedingVote.GeneType.BACK, 0);
        
        // Check vote was recorded
        uint256 geneVotes = breedingVote.getGeneVotes(ticketId, AminalBreedingVote.GeneType.BACK, 0);
        console.log("Gene votes for Rainbow Wings:", geneVotes);
        
        // Voter2 votes for parent traits
        AminalBreedingVote.GeneType[] memory geneTypes = new AminalBreedingVote.GeneType[](1);
        bool[] memory votes = new bool[](1);
        geneTypes[0] = AminalBreedingVote.GeneType.BACK;
        votes[0] = true; // parent1
        
        vm.prank(voter2);
        breedingVote.vote(ticketId, geneTypes, votes);
        
        // Vote to proceed (not veto)
        vm.prank(voter1);
        breedingVote.voteOnVeto(ticketId, false);
        vm.prank(voter2);
        breedingVote.voteOnVeto(ticketId, false);
        
        // Debug: Check final vote counts
        (uint256[8] memory parent1Votes, uint256[8] memory parent2Votes) = breedingVote.getVoteResults(ticketId);
        console.log("Parent1 back votes:", parent1Votes[0]);
        console.log("Parent2 back votes:", parent2Votes[0]);
        console.log("Gene 0 (Rainbow) votes:", breedingVote.getGeneVotes(ticketId, AminalBreedingVote.GeneType.BACK, 0));
        console.log("Gene 1 (Crystal) votes:", breedingVote.getGeneVotes(ticketId, AminalBreedingVote.GeneType.BACK, 1));
    }
}