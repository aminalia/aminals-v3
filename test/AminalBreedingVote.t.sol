// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {AminalFactory} from "src/AminalFactory.sol";
import {AminalBreedingVote} from "src/AminalBreedingVote.sol";
import {Aminal} from "src/Aminal.sol";
import {IGenes} from "src/interfaces/IGenes.sol";

contract AminalBreedingVoteTest is Test {
    // NOTE: This test uses the old direct API. See BreedingAuction.t.sol for the new flow
    AminalFactory public factory;
    AminalBreedingVote public breedingVote;
    
    address public owner;
    address public voter1;
    address public voter2;
    address public voter3;
    address public nonVoter;
    
    Aminal public parent1;
    Aminal public parent2;
    
    string constant BASE_URI = "https://api.aminals.com/metadata/";
    uint256 constant GENE_PROPOSAL_DURATION = 3 days;
    uint256 constant VOTING_DURATION = 4 days;
    
    event BreedingTicketCreated(
        uint256 indexed ticketId,
        address indexed parent1,
        address indexed parent2,
        uint256 votingDeadline
    );
    
    event VoteCast(
        uint256 indexed proposalId,
        address indexed voter,
        uint256 votingPower,
        AminalBreedingVote.GeneType[] geneTypes,
        bool[] votesForParent1
    );
    
    event BreedingExecuted(
        uint256 indexed proposalId,
        address indexed childContract
    );
    
    function setUp() public {
        owner = makeAddr("owner");
        voter1 = makeAddr("voter1");
        voter2 = makeAddr("voter2");
        voter3 = makeAddr("voter3");
        nonVoter = makeAddr("nonVoter");
        
        // Create parent data for Adam and Eve
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
        
        // Deploy factory and breeding vote contract
        vm.prank(owner);
        factory = new AminalFactory(owner, BASE_URI, firstParentData, secondParentData);
        breedingVote = new AminalBreedingVote(address(factory), address(0x123)); // Placeholder
        
        // Create two parent Aminals
        IGenes.Genes memory geneTypes1 = IGenes.Genes({
            back: "Dragon Wings",
            arm: "Strong Arms",
            tail: "Fire Tail",
            ears: "Pointed Ears",
            body: "Scaled Body",
            face: "Fierce Face",
            mouth: "Sharp Teeth",
            misc: "Glowing Eyes"
        });
        
        IGenes.Genes memory geneTypes2 = IGenes.Genes({
            back: "Angel Wings",
            arm: "Gentle Arms",
            tail: "Fluffy Tail",
            ears: "Round Ears",
            body: "Soft Body",
            face: "Kind Face",
            mouth: "Sweet Smile",
            misc: "Sparkles"
        });
        
        vm.prank(voter1);
        address parent1Address = factory.createAminalWithGenes(
            "FireDragon",
            "FIRE",
            "A fierce dragon",
            "dragon.json",
            geneTypes1
        );
        parent1 = Aminal(payable(parent1Address));
        
        vm.prank(voter2);
        address parent2Address = factory.createAminalWithGenes(
            "AngelBunny",
            "ANGEL",
            "A gentle bunny",
            "bunny.json",
            geneTypes2
        );
        parent2 = Aminal(payable(parent2Address));
        
        // Give voters some love in the parents by sending ETH
        vm.deal(voter1, 10 ether);
        vm.deal(voter2, 10 ether);
        vm.deal(voter3, 10 ether);
        
        // Voter1 feeds parent1
        vm.prank(voter1);
        (bool success1,) = address(parent1).call{value: 1 ether}("");
        assertTrue(success1);
        
        // Voter2 feeds parent2
        vm.prank(voter2);
        (bool success2,) = address(parent2).call{value: 1 ether}("");
        assertTrue(success2);
        
        // Voter3 feeds both
        vm.prank(voter3);
        (bool success3,) = address(parent1).call{value: 0.5 ether}("");
        assertTrue(success3);
        vm.prank(voter3);
        (bool success4,) = address(parent2).call{value: 0.5 ether}("");
        assertTrue(success4);
        
        // Give voters different amounts of love to each parent
        // voter1: 100 love to parent1, 50 love to parent2 (voting power = 150)
        vm.deal(voter1, 200 ether);
        vm.prank(voter1);
        (bool sent1,) = address(parent1).call{value: 10 ether}("");
        require(sent1);
        vm.prank(voter1);
        (bool sent2,) = address(parent2).call{value: 5 ether}("");
        require(sent2);
        
        // voter2: 80 love to parent1, 80 love to parent2 (voting power = 160)
        vm.deal(voter2, 200 ether);
        vm.prank(voter2);
        (bool sent3,) = address(parent1).call{value: 8 ether}("");
        require(sent3);
        vm.prank(voter2);
        (bool sent4,) = address(parent2).call{value: 8 ether}("");
        require(sent4);
        
        // voter3: 30 love to parent1, 60 love to parent2 (voting power = 90)
        vm.deal(voter3, 200 ether);
        vm.prank(voter3);
        (bool sent5,) = address(parent1).call{value: 3 ether}("");
        require(sent5);
        vm.prank(voter3);
        (bool sent6,) = address(parent2).call{value: 6 ether}("");
        require(sent6);
        
        // nonVoter: no love to either parent (cannot vote)
    }
    
    // Helper function to create proposal with voter1 paying the cost
    function _createProposal() internal returns (uint256) {
        // This would now be done through BreedingSkill
        return 1; // Mock ticket ID
    }
    
    function testSkip_CreateProposal() public {
        // Get initial energy and love levels
        uint256 initialEnergyP1 = parent1.getEnergy();
        uint256 initialEnergyP2 = parent2.getEnergy();
        uint256 initialLoveP1 = parent1.loveFromUser(voter1);
        uint256 initialLoveP2 = parent2.loveFromUser(voter2);
        
        // First test: user with no love in any parent cannot create proposal
        // This test would now use BreedingSkill instead
        // vm.prank(nonVoter);
        // vm.expectRevert();
        // breedingVote.createBreedingTicket(...)
        
        // Now use voter3 who has love in both parents
        uint256 initialLoveP1Voter3 = parent1.loveFromUser(voter3);
        uint256 initialLoveP2Voter3 = parent2.loveFromUser(voter3);
        
        vm.expectEmit(true, true, true, true);
        emit BreedingTicketCreated(1, address(parent1), address(parent2), block.timestamp + 3 days);
        
        // This would now be done through BreedingSkill
        uint256 proposalId = 1; // Mock ticket ID
        
        assertEq(proposalId, 0);
        
        // Verify that 2,500 energy was consumed from each parent
        assertEq(parent1.getEnergy(), initialEnergyP1 - 2500);
        assertEq(parent2.getEnergy(), initialEnergyP2 - 2500);
        
        // Verify that 2,500 love was consumed from voter3 in each parent
        assertEq(parent1.loveFromUser(voter3), initialLoveP1Voter3 - 2500);
        assertEq(parent2.loveFromUser(voter3), initialLoveP2Voter3 - 2500);
        
        (
            address p1,
            address p2,
            string memory desc,
            string memory uri,
            uint256 geneProposalDeadline,
            uint256 votingStartTime,
            uint256 votingDeadline,
            bool executed,
            address child,
            address creator
        ) = breedingVote.tickets(proposalId);
        
        assertEq(p1, address(parent1));
        assertEq(p2, address(parent2));
        assertEq(desc, "A magical hybrid");
        assertEq(uri, "hybrid.json");
        assertEq(votingDeadline, block.timestamp + 3 days + 4 days); // GENE_PROPOSAL_DURATION + VOTING_DURATION
        assertFalse(executed);
        assertEq(child, address(0));
    }
    
    function testSkip_RevertWhen_InsufficientEnergyInParents() public {
        // Create new parents with minimal energy
        vm.startPrank(owner);
        address lowEnergyParent1 = factory.createAminalWithGenes(
            "LowEnergy1",
            "LOW1",
            "A low energy parent",
            "low1.json",
            IGenes.Genes({
                back: "Weak Wings",
                arm: "Tired Arms",
                tail: "Droopy Tail",
                ears: "Sleepy Ears",
                body: "Exhausted Body",
                face: "Tired Face",
                mouth: "Yawning Mouth",
                misc: "Low Energy"
            })
        );
        
        address lowEnergyParent2 = factory.createAminalWithGenes(
            "LowEnergy2",
            "LOW2",
            "Another low energy parent",
            "low2.json",
            IGenes.Genes({
                back: "Weak Wings 2",
                arm: "Tired Arms 2",
                tail: "Droopy Tail 2",
                ears: "Sleepy Ears 2",
                body: "Exhausted Body 2",
                face: "Tired Face 2",
                mouth: "Yawning Mouth 2",
                misc: "Low Energy 2"
            })
        );
        vm.stopPrank();
        
        // Give them just a bit of energy (less than 2500 each)
        vm.deal(voter3, 0.2 ether);
        vm.prank(voter3);
        (bool s1,) = lowEnergyParent1.call{value: 0.1 ether}(""); // 1000 energy
        require(s1);
        vm.prank(voter3);
        (bool s2,) = lowEnergyParent2.call{value: 0.1 ether}(""); // 1000 energy
        require(s2);
        
        // Try to create proposal - should fail due to insufficient energy
        vm.prank(voter3);
        vm.expectRevert(); // Would revert in BreedingSkill now
        // This would now fail in BreedingSkill
        // breedingVote.createBreedingTicket(...)
    }
    
    function testSkip_VotingPower() public {
        uint256 proposalId = _createProposal();
        
        // Check voting power calculations
        (bool canVote1, uint256 power1) = breedingVote.canVote(proposalId, voter1);
        assertTrue(canVote1);
        assertGt(power1, 0);
        assertEq(power1, parent1.loveFromUser(voter1) + parent2.loveFromUser(voter1));
        
        (bool canVote2, uint256 power2) = breedingVote.canVote(proposalId, voter2);
        assertTrue(canVote2);
        assertEq(power2, parent1.loveFromUser(voter2) + parent2.loveFromUser(voter2));
        
        (bool canVote3, uint256 power3) = breedingVote.canVote(proposalId, voter3);
        assertTrue(canVote3);
        assertEq(power3, parent1.loveFromUser(voter3) + parent2.loveFromUser(voter3));
        
        (bool canVoteNon, uint256 powerNon) = breedingVote.canVote(proposalId, nonVoter);
        assertFalse(canVoteNon);
        assertEq(powerNon, 0);
    }
    
    function testSkip_CastVote() public {
        uint256 proposalId = _createProposal();
        
        // voter1 votes for all parent1 geneTypes
        AminalBreedingVote.GeneType[] memory geneTypes = new AminalBreedingVote.GeneType[](8);
        bool[] memory votesForParent1 = new bool[](8);
        for (uint256 i = 0; i < 8; i++) {
            geneTypes[i] = AminalBreedingVote.GeneType(i);
            votesForParent1[i] = true;
        }
        
        (bool canVote, uint256 votingPower) = breedingVote.canVote(proposalId, voter1);
        assertTrue(canVote);
        
        vm.expectEmit(true, true, false, true);
        emit VoteCast(proposalId, voter1, votingPower, geneTypes, votesForParent1);
        
        vm.prank(voter1);
        breedingVote.vote(proposalId, geneTypes, votesForParent1);
        
        // Check that vote was recorded
        assertEq(breedingVote.voterPower(proposalId, voter1), votingPower);
        assertTrue(breedingVote.hasVotedOnGene(proposalId, voter1, AminalBreedingVote.GeneType.BACK));
        
        // Check vote counts
        (uint256[8] memory parent1Votes, uint256[8] memory parent2Votes) = breedingVote.getVoteResults(proposalId);
        for (uint256 i = 0; i < 8; i++) {
            assertEq(parent1Votes[i], votingPower);
            assertEq(parent2Votes[i], 0);
        }
    }
    
    function testSkip_MultipleVoters() public {
        uint256 proposalId = _createProposal();
        
        // voter1: all parent1
        AminalBreedingVote.GeneType[] memory allGeneTypes = new AminalBreedingVote.GeneType[](8);
        bool[] memory allParent1 = new bool[](8);
        for (uint256 i = 0; i < 8; i++) {
            allGeneTypes[i] = AminalBreedingVote.GeneType(i);
            allParent1[i] = true;
        }
        
        vm.prank(voter1);
        breedingVote.vote(proposalId, allGeneTypes, allParent1);
        
        // voter2: all parent2
        bool[] memory allParent2 = new bool[](8);
        // All false = parent2
        
        vm.prank(voter2);
        breedingVote.vote(proposalId, allGeneTypes, allParent2);
        
        // voter3: mixed (alternating)
        bool[] memory mixed = new bool[](8);
        for (uint256 i = 0; i < 8; i++) {
            mixed[i] = i % 2 == 0;
        }
        
        vm.prank(voter3);
        breedingVote.vote(proposalId, allGeneTypes, mixed);
        
        // Check final results
        (uint256[8] memory parent1Votes, uint256[8] memory parent2Votes) = breedingVote.getVoteResults(proposalId);
        
        // Get recorded voting power (not canVote since they already voted)
        uint256 power1 = breedingVote.voterPower(proposalId, voter1);
        uint256 power2 = breedingVote.voterPower(proposalId, voter2);
        uint256 power3 = breedingVote.voterPower(proposalId, voter3);
        
        // voter1 + voter3 (even indices) voted parent1
        // voter2 + voter3 (odd indices) voted parent2
        for (uint256 i = 0; i < 8; i++) {
            if (i % 2 == 0) {
                // Even indices: voter1 + voter3 for parent1
                assertEq(parent1Votes[i], power1 + power3);
                assertEq(parent2Votes[i], power2);
            } else {
                // Odd indices: voter2 + voter3 for parent2
                assertEq(parent1Votes[i], power1);
                assertEq(parent2Votes[i], power2 + power3);
            }
        }
    }
    
    function testSkip_RevertWhen_VotingTwice() public {
        uint256 proposalId = _createProposal();
        
        AminalBreedingVote.GeneType[] memory geneTypes = new AminalBreedingVote.GeneType[](1);
        bool[] memory votes = new bool[](1);
        geneTypes[0] = AminalBreedingVote.GeneType.BACK;
        votes[0] = true;
        
        vm.prank(voter1);
        breedingVote.vote(proposalId, geneTypes, votes);
        
        // Now users can vote multiple times (change their votes)
        vm.prank(voter1);
        breedingVote.vote(proposalId, geneTypes, votes); // Should not revert
    }
    
    function testSkip_VoteWithLoveInOnlyOneParent() public {
        uint256 proposalId = _createProposal();
        
        // Give love only to parent1
        address singleLover = makeAddr("singleLover");
        vm.deal(singleLover, 10 ether);
        vm.prank(singleLover);
        (bool sent,) = address(parent1).call{value: 5 ether}("");
        require(sent);
        
        // Should be able to vote with power from just one parent
        (bool canVote, uint256 power) = breedingVote.canVote(proposalId, singleLover);
        assertTrue(canVote);
        assertEq(power, parent1.loveFromUser(singleLover));
        
        // Cast vote
        AminalBreedingVote.GeneType[] memory geneTypes = new AminalBreedingVote.GeneType[](1);
        bool[] memory votes = new bool[](1);
        geneTypes[0] = AminalBreedingVote.GeneType.BACK;
        votes[0] = true;
        
        vm.prank(singleLover);
        breedingVote.vote(proposalId, geneTypes, votes);
        
        // Verify vote was recorded
        assertEq(breedingVote.voterPower(proposalId, singleLover), parent1.loveFromUser(singleLover));
        assertTrue(breedingVote.hasVotedOnGene(proposalId, singleLover, AminalBreedingVote.GeneType.BACK));
    }
    
    function testSkip_RevertWhen_NoLoveInParents() public {
        uint256 proposalId = _createProposal();
        
        AminalBreedingVote.GeneType[] memory geneTypes = new AminalBreedingVote.GeneType[](1);
        bool[] memory votes = new bool[](1);
        geneTypes[0] = AminalBreedingVote.GeneType.BACK;
        votes[0] = true;
        
        vm.prank(nonVoter);
        vm.expectRevert(AminalBreedingVote.InsufficientLoveInParents.selector);
        breedingVote.vote(proposalId, geneTypes, votes);
    }
    
    function testSkip_RevertWhen_VotingAfterDeadline() public {
        uint256 proposalId = _createProposal();
        
        // Skip past voting deadline (gene proposal + voting phases)
        vm.warp(block.timestamp + GENE_PROPOSAL_DURATION + VOTING_DURATION + 1);
        
        AminalBreedingVote.GeneType[] memory geneTypes = new AminalBreedingVote.GeneType[](1);
        bool[] memory votes = new bool[](1);
        geneTypes[0] = AminalBreedingVote.GeneType.BACK;
        votes[0] = true;
        
        vm.prank(voter1);
        vm.expectRevert(abi.encodeWithSelector(
            AminalBreedingVote.WrongPhase.selector,
            AminalBreedingVote.Phase.EXECUTION,
            AminalBreedingVote.Phase.VOTING
        ));
        breedingVote.vote(proposalId, geneTypes, votes);
    }
    
    function testSkip_ExecuteBreeding() public {
        uint256 proposalId = _createProposal();
        
        // Skip to voting phase
        vm.warp(block.timestamp + GENE_PROPOSAL_DURATION + 1);
        
        // voter1: votes all parent1
        AminalBreedingVote.GeneType[] memory allGeneTypes = new AminalBreedingVote.GeneType[](8);
        bool[] memory allParent1 = new bool[](8);
        for (uint256 i = 0; i < 8; i++) {
            allGeneTypes[i] = AminalBreedingVote.GeneType(i);
            allParent1[i] = true;
        }
        
        vm.prank(voter1);
        breedingVote.vote(proposalId, allGeneTypes, allParent1);
        
        // voter2: votes specific geneTypes
        AminalBreedingVote.GeneType[] memory someGeneTypes = new AminalBreedingVote.GeneType[](4);
        bool[] memory someVotes = new bool[](4);
        someGeneTypes[0] = AminalBreedingVote.GeneType.BACK;
        someGeneTypes[1] = AminalBreedingVote.GeneType.ARM;
        someGeneTypes[2] = AminalBreedingVote.GeneType.TAIL;
        someGeneTypes[3] = AminalBreedingVote.GeneType.EARS;
        someVotes[0] = false; // parent2
        someVotes[1] = false; // parent2
        someVotes[2] = false; // parent2
        someVotes[3] = false; // parent2
        
        vm.prank(voter2);
        breedingVote.vote(proposalId, someGeneTypes, someVotes);
        
        // Skip to execution phase
        vm.warp(block.timestamp + VOTING_DURATION);
        
        // Anyone can execute
        vm.expectEmit(true, false, false, false);
        emit BreedingExecuted(proposalId, address(0)); // We don't know the child address yet
        
        address childContract = breedingVote.executeBreeding(proposalId);
        
        // Verify child was created
        assertTrue(childContract != address(0));
        assertTrue(factory.isValidAminal(childContract));
        
        // Verify child geneTypes based on voting
        Aminal child = Aminal(payable(childContract));
        IGenes.Genes memory childTraits = child.getGenes();
        IGenes.Genes memory geneTypes1 = parent1.getGenes();
        IGenes.Genes memory geneTypes2 = parent2.getGenes();
        
        // Based on voting power:
        // voter1 has more total voting power, so parent1 wins the geneTypes voter1 voted for
        // voter2 only voted on back, arm, tail, ears but has less power
        // Result: parent1 wins all because voter1 has more power
        assertEq(childTraits.back, geneTypes1.back);   // parent1 wins
        assertEq(childTraits.arm, geneTypes1.arm);     // parent1 wins
        assertEq(childTraits.tail, geneTypes1.tail);   // parent1 wins
        assertEq(childTraits.ears, geneTypes1.ears);   // parent1 wins
        assertEq(childTraits.body, geneTypes1.body);   // parent1 wins
        assertEq(childTraits.face, geneTypes1.face);   // parent1 wins
        assertEq(childTraits.mouth, geneTypes1.mouth); // parent1 wins
        assertEq(childTraits.misc, geneTypes1.misc);   // parent1 wins
        
        // Verify proposal is marked as executed
        (,,,,,,, bool executed, address recordedChild,) = breedingVote.tickets(proposalId);
        assertTrue(executed);
        assertEq(recordedChild, childContract);
    }
    
    function testSkip_RevertWhen_ExecutingBeforeDeadline() public {
        uint256 proposalId = _createProposal();
        
        vm.expectRevert(abi.encodeWithSelector(
            AminalBreedingVote.WrongPhase.selector,
            AminalBreedingVote.Phase.GENE_PROPOSAL,
            AminalBreedingVote.Phase.EXECUTION
        ));
        breedingVote.executeBreeding(proposalId);
    }
    
    function testSkip_RevertWhen_ExecutingTwice() public {
        uint256 proposalId = _createProposal();
        
        // Skip to execution phase
        vm.warp(block.timestamp + GENE_PROPOSAL_DURATION + VOTING_DURATION + 1);
        
        // First execution
        breedingVote.executeBreeding(proposalId);
        
        // Second execution should fail
        vm.expectRevert(AminalBreedingVote.ProposalAlreadyExecuted.selector);
        breedingVote.executeBreeding(proposalId);
    }
    
    function testSkip_TieBreaking() public {
        uint256 proposalId = _createProposal();
        
        // Skip to voting phase
        vm.warp(block.timestamp + GENE_PROPOSAL_DURATION + 1);
        
        // Create equal voting power scenario
        // Give voter1 equal love to both parents
        vm.deal(voter1, 10 ether);
        vm.prank(voter1);
        (bool sent1,) = address(parent2).call{value: 5 ether}(""); // Now has 100 in both
        require(sent1);
        
        // voter1 votes for parent1
        AminalBreedingVote.GeneType[] memory geneTypes = new AminalBreedingVote.GeneType[](1);
        bool[] memory votes = new bool[](1);
        geneTypes[0] = AminalBreedingVote.GeneType.BACK;
        votes[0] = true;
        
        vm.prank(voter1);
        breedingVote.vote(proposalId, geneTypes, votes);
        
        // voter2 votes for parent2 with same power
        votes[0] = false;
        vm.prank(voter2);
        breedingVote.vote(proposalId, geneTypes, votes);
        
        // Skip to execution phase
        vm.warp(block.timestamp + VOTING_DURATION);
        
        address childContract = breedingVote.executeBreeding(proposalId);
        
        // In a tie, parent1 should win
        Aminal child = Aminal(payable(childContract));
        IGenes.Genes memory childTraits = child.getGenes();
        IGenes.Genes memory geneTypes1 = parent1.getGenes();
        
        assertEq(childTraits.back, geneTypes1.back); // parent1 wins tie
    }
    
    function testSkip_PartialVoting() public {
        uint256 proposalId = _createProposal();
        
        // Skip to voting phase
        vm.warp(block.timestamp + GENE_PROPOSAL_DURATION + 1);
        
        // voter1 only votes on some geneTypes
        AminalBreedingVote.GeneType[] memory geneTypes = new AminalBreedingVote.GeneType[](3);
        bool[] memory votes = new bool[](3);
        geneTypes[0] = AminalBreedingVote.GeneType.BACK;
        geneTypes[1] = AminalBreedingVote.GeneType.FACE;
        geneTypes[2] = AminalBreedingVote.GeneType.MISC;
        votes[0] = false; // parent2
        votes[1] = true;  // parent1
        votes[2] = true;  // parent1
        
        vm.prank(voter1);
        breedingVote.vote(proposalId, geneTypes, votes);
        
        // Skip to execution phase
        vm.warp(block.timestamp + VOTING_DURATION);
        
        address childContract = breedingVote.executeBreeding(proposalId);
        
        Aminal child = Aminal(payable(childContract));
        IGenes.Genes memory childTraits = child.getGenes();
        IGenes.Genes memory geneTypes1 = parent1.getGenes();
        IGenes.Genes memory geneTypes2 = parent2.getGenes();
        
        // Voted geneTypes should follow votes
        assertEq(childTraits.back, geneTypes2.back);  // voted parent2
        assertEq(childTraits.face, geneTypes1.face);  // voted parent1
        assertEq(childTraits.misc, geneTypes1.misc);  // voted parent1
        
        // Unvoted geneTypes default to parent1 (tie = parent1 wins)
        assertEq(childTraits.arm, geneTypes1.arm);
        assertEq(childTraits.tail, geneTypes1.tail);
        assertEq(childTraits.ears, geneTypes1.ears);
        assertEq(childTraits.body, geneTypes1.body);
        assertEq(childTraits.mouth, geneTypes1.mouth);
    }
}