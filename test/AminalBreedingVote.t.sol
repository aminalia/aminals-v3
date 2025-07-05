// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {AminalFactory} from "src/AminalFactory.sol";
import {AminalBreedingVote} from "src/AminalBreedingVote.sol";
import {Aminal} from "src/Aminal.sol";
import {ITraits} from "src/interfaces/ITraits.sol";

contract AminalBreedingVoteTest is Test {
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
    uint256 constant VOTING_DURATION = 1 days;
    
    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed parent1,
        address indexed parent2,
        uint256 votingDeadline
    );
    
    event VoteCast(
        uint256 indexed proposalId,
        address indexed voter,
        uint256 votingPower,
        AminalBreedingVote.TraitType[] traits,
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
        
        // Deploy factory and breeding vote contract
        vm.prank(owner);
        factory = new AminalFactory(owner, BASE_URI);
        breedingVote = new AminalBreedingVote(address(factory));
        
        // Create two parent Aminals
        ITraits.Traits memory traits1 = ITraits.Traits({
            back: "Dragon Wings",
            arm: "Strong Arms",
            tail: "Fire Tail",
            ears: "Pointed Ears",
            body: "Scaled Body",
            face: "Fierce Face",
            mouth: "Sharp Teeth",
            misc: "Glowing Eyes"
        });
        
        ITraits.Traits memory traits2 = ITraits.Traits({
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
        address parent1Address = factory.createAminal(
            "FireDragon",
            "FIRE",
            "A fierce dragon",
            "dragon.json",
            traits1
        );
        parent1 = Aminal(payable(parent1Address));
        
        vm.prank(voter2);
        address parent2Address = factory.createAminal(
            "AngelBunny",
            "ANGEL",
            "A gentle bunny",
            "bunny.json",
            traits2
        );
        parent2 = Aminal(payable(parent2Address));
        
        // Give voters different amounts of love to each parent
        // voter1: 100 love to parent1, 50 love to parent2 (voting power = 50)
        vm.deal(voter1, 200 ether);
        vm.prank(voter1);
        (bool sent1,) = address(parent1).call{value: 10 ether}("");
        require(sent1);
        vm.prank(voter1);
        (bool sent2,) = address(parent2).call{value: 5 ether}("");
        require(sent2);
        
        // voter2: 80 love to parent1, 80 love to parent2 (voting power = 80)
        vm.deal(voter2, 200 ether);
        vm.prank(voter2);
        (bool sent3,) = address(parent1).call{value: 8 ether}("");
        require(sent3);
        vm.prank(voter2);
        (bool sent4,) = address(parent2).call{value: 8 ether}("");
        require(sent4);
        
        // voter3: 30 love to parent1, 60 love to parent2 (voting power = 30)
        vm.deal(voter3, 200 ether);
        vm.prank(voter3);
        (bool sent5,) = address(parent1).call{value: 3 ether}("");
        require(sent5);
        vm.prank(voter3);
        (bool sent6,) = address(parent2).call{value: 6 ether}("");
        require(sent6);
        
        // nonVoter: no love to either parent (cannot vote)
    }
    
    function test_CreateProposal() public {
        vm.expectEmit(true, true, true, true);
        emit ProposalCreated(0, address(parent1), address(parent2), block.timestamp + VOTING_DURATION);
        
        uint256 proposalId = breedingVote.createProposal(
            address(parent1),
            address(parent2),
            "A magical hybrid",
            "hybrid.json",
            VOTING_DURATION
        );
        
        assertEq(proposalId, 0);
        
        (
            address p1,
            address p2,
            string memory desc,
            string memory uri,
            uint256 deadline,
            bool executed,
            address child
        ) = breedingVote.proposals(proposalId);
        
        assertEq(p1, address(parent1));
        assertEq(p2, address(parent2));
        assertEq(desc, "A magical hybrid");
        assertEq(uri, "hybrid.json");
        assertEq(deadline, block.timestamp + VOTING_DURATION);
        assertFalse(executed);
        assertEq(child, address(0));
    }
    
    function test_VotingPower() public {
        uint256 proposalId = breedingVote.createProposal(
            address(parent1),
            address(parent2),
            "A magical hybrid",
            "hybrid.json",
            VOTING_DURATION
        );
        
        // Check voting power calculations
        (bool canVote1, uint256 power1) = breedingVote.canVote(proposalId, voter1);
        assertTrue(canVote1);
        assertGt(power1, 0);
        assertLe(power1, parent1.loveFromUser(voter1));
        assertLe(power1, parent2.loveFromUser(voter1));
        
        (bool canVote2, uint256 power2) = breedingVote.canVote(proposalId, voter2);
        assertTrue(canVote2);
        assertEq(power2, parent1.loveFromUser(voter2)); // Both equal
        
        (bool canVote3, uint256 power3) = breedingVote.canVote(proposalId, voter3);
        assertTrue(canVote3);
        assertEq(power3, parent1.loveFromUser(voter3)); // Parent1 has less
        
        (bool canVoteNon, uint256 powerNon) = breedingVote.canVote(proposalId, nonVoter);
        assertFalse(canVoteNon);
        assertEq(powerNon, 0);
    }
    
    function test_CastVote() public {
        uint256 proposalId = breedingVote.createProposal(
            address(parent1),
            address(parent2),
            "A magical hybrid",
            "hybrid.json",
            VOTING_DURATION
        );
        
        // voter1 votes for all parent1 traits
        AminalBreedingVote.TraitType[] memory traits = new AminalBreedingVote.TraitType[](8);
        bool[] memory votesForParent1 = new bool[](8);
        for (uint256 i = 0; i < 8; i++) {
            traits[i] = AminalBreedingVote.TraitType(i);
            votesForParent1[i] = true;
        }
        
        (bool canVote, uint256 votingPower) = breedingVote.canVote(proposalId, voter1);
        assertTrue(canVote);
        
        vm.expectEmit(true, true, false, true);
        emit VoteCast(proposalId, voter1, votingPower, traits, votesForParent1);
        
        vm.prank(voter1);
        breedingVote.vote(proposalId, traits, votesForParent1);
        
        // Check that vote was recorded
        assertTrue(breedingVote.hasVoted(proposalId, voter1));
        assertEq(breedingVote.voterPower(proposalId, voter1), votingPower);
        
        // Check vote counts
        AminalBreedingVote.TraitVote[8] memory results = breedingVote.getVoteResults(proposalId);
        for (uint256 i = 0; i < 8; i++) {
            assertEq(results[i].parent1Votes, votingPower);
            assertEq(results[i].parent2Votes, 0);
        }
    }
    
    function test_MultipleVoters() public {
        uint256 proposalId = breedingVote.createProposal(
            address(parent1),
            address(parent2),
            "A magical hybrid",
            "hybrid.json",
            VOTING_DURATION
        );
        
        // voter1: all parent1
        AminalBreedingVote.TraitType[] memory allTraits = new AminalBreedingVote.TraitType[](8);
        bool[] memory allParent1 = new bool[](8);
        for (uint256 i = 0; i < 8; i++) {
            allTraits[i] = AminalBreedingVote.TraitType(i);
            allParent1[i] = true;
        }
        
        vm.prank(voter1);
        breedingVote.vote(proposalId, allTraits, allParent1);
        
        // voter2: all parent2
        bool[] memory allParent2 = new bool[](8);
        // All false = parent2
        
        vm.prank(voter2);
        breedingVote.vote(proposalId, allTraits, allParent2);
        
        // voter3: mixed (alternating)
        bool[] memory mixed = new bool[](8);
        for (uint256 i = 0; i < 8; i++) {
            mixed[i] = i % 2 == 0;
        }
        
        vm.prank(voter3);
        breedingVote.vote(proposalId, allTraits, mixed);
        
        // Check final results
        AminalBreedingVote.TraitVote[8] memory results = breedingVote.getVoteResults(proposalId);
        
        // Get recorded voting power (not canVote since they already voted)
        uint256 power1 = breedingVote.voterPower(proposalId, voter1);
        uint256 power2 = breedingVote.voterPower(proposalId, voter2);
        uint256 power3 = breedingVote.voterPower(proposalId, voter3);
        
        // voter1 + voter3 (even indices) voted parent1
        // voter2 + voter3 (odd indices) voted parent2
        for (uint256 i = 0; i < 8; i++) {
            if (i % 2 == 0) {
                // Even indices: voter1 + voter3 for parent1
                assertEq(results[i].parent1Votes, power1 + power3);
                assertEq(results[i].parent2Votes, power2);
            } else {
                // Odd indices: voter2 + voter3 for parent2
                assertEq(results[i].parent1Votes, power1);
                assertEq(results[i].parent2Votes, power2 + power3);
            }
        }
    }
    
    function test_RevertWhen_VotingTwice() public {
        uint256 proposalId = breedingVote.createProposal(
            address(parent1),
            address(parent2),
            "A magical hybrid",
            "hybrid.json",
            VOTING_DURATION
        );
        
        AminalBreedingVote.TraitType[] memory traits = new AminalBreedingVote.TraitType[](1);
        bool[] memory votes = new bool[](1);
        traits[0] = AminalBreedingVote.TraitType.BACK;
        votes[0] = true;
        
        vm.prank(voter1);
        breedingVote.vote(proposalId, traits, votes);
        
        vm.prank(voter1);
        vm.expectRevert(AminalBreedingVote.AlreadyVoted.selector);
        breedingVote.vote(proposalId, traits, votes);
    }
    
    function test_RevertWhen_NoLoveInParents() public {
        uint256 proposalId = breedingVote.createProposal(
            address(parent1),
            address(parent2),
            "A magical hybrid",
            "hybrid.json",
            VOTING_DURATION
        );
        
        AminalBreedingVote.TraitType[] memory traits = new AminalBreedingVote.TraitType[](1);
        bool[] memory votes = new bool[](1);
        traits[0] = AminalBreedingVote.TraitType.BACK;
        votes[0] = true;
        
        vm.prank(nonVoter);
        vm.expectRevert(AminalBreedingVote.InsufficientLoveInParents.selector);
        breedingVote.vote(proposalId, traits, votes);
    }
    
    function test_RevertWhen_VotingAfterDeadline() public {
        uint256 proposalId = breedingVote.createProposal(
            address(parent1),
            address(parent2),
            "A magical hybrid",
            "hybrid.json",
            VOTING_DURATION
        );
        
        // Skip past deadline
        vm.warp(block.timestamp + VOTING_DURATION + 1);
        
        AminalBreedingVote.TraitType[] memory traits = new AminalBreedingVote.TraitType[](1);
        bool[] memory votes = new bool[](1);
        traits[0] = AminalBreedingVote.TraitType.BACK;
        votes[0] = true;
        
        vm.prank(voter1);
        vm.expectRevert(AminalBreedingVote.VotingEnded.selector);
        breedingVote.vote(proposalId, traits, votes);
    }
    
    function test_ExecuteBreeding() public {
        uint256 proposalId = breedingVote.createProposal(
            address(parent1),
            address(parent2),
            "A magical hybrid",
            "hybrid.json",
            VOTING_DURATION
        );
        
        // voter1: votes all parent1
        AminalBreedingVote.TraitType[] memory allTraits = new AminalBreedingVote.TraitType[](8);
        bool[] memory allParent1 = new bool[](8);
        for (uint256 i = 0; i < 8; i++) {
            allTraits[i] = AminalBreedingVote.TraitType(i);
            allParent1[i] = true;
        }
        
        vm.prank(voter1);
        breedingVote.vote(proposalId, allTraits, allParent1);
        
        // voter2: votes specific traits
        AminalBreedingVote.TraitType[] memory someTraits = new AminalBreedingVote.TraitType[](4);
        bool[] memory someVotes = new bool[](4);
        someTraits[0] = AminalBreedingVote.TraitType.BACK;
        someTraits[1] = AminalBreedingVote.TraitType.ARM;
        someTraits[2] = AminalBreedingVote.TraitType.TAIL;
        someTraits[3] = AminalBreedingVote.TraitType.EARS;
        someVotes[0] = false; // parent2
        someVotes[1] = false; // parent2
        someVotes[2] = false; // parent2
        someVotes[3] = false; // parent2
        
        vm.prank(voter2);
        breedingVote.vote(proposalId, someTraits, someVotes);
        
        // Skip to after deadline
        vm.warp(block.timestamp + VOTING_DURATION + 1);
        
        // Anyone can execute
        vm.expectEmit(true, false, false, false);
        emit BreedingExecuted(proposalId, address(0)); // We don't know the child address yet
        
        address childContract = breedingVote.executeBreeding(proposalId);
        
        // Verify child was created
        assertTrue(childContract != address(0));
        assertTrue(factory.isValidAminal(childContract));
        
        // Verify child traits based on voting
        Aminal child = Aminal(payable(childContract));
        ITraits.Traits memory childTraits = child.getTraits();
        ITraits.Traits memory traits1 = parent1.getTraits();
        ITraits.Traits memory traits2 = parent2.getTraits();
        
        // Based on voting power:
        // voter1: 50 power for all parent1
        // voter2: 80 power for parent2 on back, arm, tail, ears
        // Result: parent2 wins back, arm, tail, ears; parent1 wins others
        assertEq(childTraits.back, traits2.back);   // parent2 wins (80 > 50)
        assertEq(childTraits.arm, traits2.arm);     // parent2 wins (80 > 50)
        assertEq(childTraits.tail, traits2.tail);   // parent2 wins (80 > 50)
        assertEq(childTraits.ears, traits2.ears);   // parent2 wins (80 > 50)
        assertEq(childTraits.body, traits1.body);   // parent1 wins (50 > 0)
        assertEq(childTraits.face, traits1.face);   // parent1 wins (50 > 0)
        assertEq(childTraits.mouth, traits1.mouth); // parent1 wins (50 > 0)
        assertEq(childTraits.misc, traits1.misc);   // parent1 wins (50 > 0)
        
        // Verify proposal is marked as executed
        (,,,,, bool executed, address recordedChild) = breedingVote.proposals(proposalId);
        assertTrue(executed);
        assertEq(recordedChild, childContract);
    }
    
    function test_RevertWhen_ExecutingBeforeDeadline() public {
        uint256 proposalId = breedingVote.createProposal(
            address(parent1),
            address(parent2),
            "A magical hybrid",
            "hybrid.json",
            VOTING_DURATION
        );
        
        vm.expectRevert(AminalBreedingVote.VotingNotEnded.selector);
        breedingVote.executeBreeding(proposalId);
    }
    
    function test_RevertWhen_ExecutingTwice() public {
        uint256 proposalId = breedingVote.createProposal(
            address(parent1),
            address(parent2),
            "A magical hybrid",
            "hybrid.json",
            VOTING_DURATION
        );
        
        // Skip to after deadline
        vm.warp(block.timestamp + VOTING_DURATION + 1);
        
        // First execution
        breedingVote.executeBreeding(proposalId);
        
        // Second execution should fail
        vm.expectRevert(AminalBreedingVote.ProposalAlreadyExecuted.selector);
        breedingVote.executeBreeding(proposalId);
    }
    
    function test_TieBreaking() public {
        uint256 proposalId = breedingVote.createProposal(
            address(parent1),
            address(parent2),
            "A magical hybrid",
            "hybrid.json",
            VOTING_DURATION
        );
        
        // Create equal voting power scenario
        // Give voter1 equal love to both parents
        vm.deal(voter1, 10 ether);
        vm.prank(voter1);
        (bool sent1,) = address(parent2).call{value: 5 ether}(""); // Now has 100 in both
        require(sent1);
        
        // voter1 votes for parent1
        AminalBreedingVote.TraitType[] memory traits = new AminalBreedingVote.TraitType[](1);
        bool[] memory votes = new bool[](1);
        traits[0] = AminalBreedingVote.TraitType.BACK;
        votes[0] = true;
        
        vm.prank(voter1);
        breedingVote.vote(proposalId, traits, votes);
        
        // voter2 votes for parent2 with same power
        votes[0] = false;
        vm.prank(voter2);
        breedingVote.vote(proposalId, traits, votes);
        
        // Skip to after deadline
        vm.warp(block.timestamp + VOTING_DURATION + 1);
        
        address childContract = breedingVote.executeBreeding(proposalId);
        
        // In a tie, parent1 should win
        Aminal child = Aminal(payable(childContract));
        ITraits.Traits memory childTraits = child.getTraits();
        ITraits.Traits memory traits1 = parent1.getTraits();
        
        assertEq(childTraits.back, traits1.back); // parent1 wins tie
    }
    
    function test_PartialVoting() public {
        uint256 proposalId = breedingVote.createProposal(
            address(parent1),
            address(parent2),
            "A magical hybrid",
            "hybrid.json",
            VOTING_DURATION
        );
        
        // voter1 only votes on some traits
        AminalBreedingVote.TraitType[] memory traits = new AminalBreedingVote.TraitType[](3);
        bool[] memory votes = new bool[](3);
        traits[0] = AminalBreedingVote.TraitType.BACK;
        traits[1] = AminalBreedingVote.TraitType.FACE;
        traits[2] = AminalBreedingVote.TraitType.MISC;
        votes[0] = false; // parent2
        votes[1] = true;  // parent1
        votes[2] = true;  // parent1
        
        vm.prank(voter1);
        breedingVote.vote(proposalId, traits, votes);
        
        // Skip to after deadline
        vm.warp(block.timestamp + VOTING_DURATION + 1);
        
        address childContract = breedingVote.executeBreeding(proposalId);
        
        Aminal child = Aminal(payable(childContract));
        ITraits.Traits memory childTraits = child.getTraits();
        ITraits.Traits memory traits1 = parent1.getTraits();
        ITraits.Traits memory traits2 = parent2.getTraits();
        
        // Voted traits should follow votes
        assertEq(childTraits.back, traits2.back);  // voted parent2
        assertEq(childTraits.face, traits1.face);  // voted parent1
        assertEq(childTraits.misc, traits1.misc);  // voted parent1
        
        // Unvoted traits default to parent1 (tie = parent1 wins)
        assertEq(childTraits.arm, traits1.arm);
        assertEq(childTraits.tail, traits1.tail);
        assertEq(childTraits.ears, traits1.ears);
        assertEq(childTraits.body, traits1.body);
        assertEq(childTraits.mouth, traits1.mouth);
    }
}