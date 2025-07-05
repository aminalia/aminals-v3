// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {BreedingSkill} from "src/skills/BreedingSkill.sol";
import {AminalBreedingVote} from "src/AminalBreedingVote.sol";
import {AminalFactory} from "src/AminalFactory.sol";
import {Aminal} from "src/Aminal.sol";
import {IGenes} from "src/interfaces/IGenes.sol";
import {MockGene} from "./mocks/MockGene.sol";

contract BreedingWithGenesTest is Test {
    BreedingSkill public breedingSkill;
    AminalBreedingVote public breedingVote;
    AminalFactory public factory;
    MockGene public geneContract;
    
    Aminal public parent1;
    Aminal public parent2;
    
    address public owner;
    address public breederA;
    address public breederB;
    address public geneProposer;
    address public voter1;
    address public voter2;
    address public poorUser;
    
    uint256 constant BREEDING_COST = 2500;
    uint256 constant MIN_LOVE_FOR_GENE = 100;
    
    function setUp() public {
        owner = makeAddr("owner");
        breederA = makeAddr("breederA");
        breederB = makeAddr("breederB");
        geneProposer = makeAddr("geneProposer");
        voter1 = makeAddr("voter1");
        voter2 = makeAddr("voter2");
        poorUser = makeAddr("poorUser");
        
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
        vm.deal(geneProposer, 10 ether);
        vm.deal(voter1, 10 ether);
        vm.deal(voter2, 10 ether);
        vm.deal(poorUser, 1 ether);
    }
    
    function test_ProposeGeneWithSufficientLove() public {
        // Start breeding process
        uint256 ticketId = _createBreedingTicket();
        
        // Gene proposer feeds both parents to get love
        vm.prank(geneProposer);
        (bool success,) = address(parent1).call{value: 0.01 ether}("");
        assertTrue(success);
        
        vm.prank(geneProposer);
        (success,) = address(parent2).call{value: 0.01 ether}("");
        assertTrue(success);
        
        // Check love levels
        uint256 loveInParent1 = parent1.loveFromUser(geneProposer);
        uint256 loveInParent2 = parent2.loveFromUser(geneProposer);
        uint256 totalLove = loveInParent1 + loveInParent2;
        
        console.log("Love in parent1:", loveInParent1);
        console.log("Love in parent2:", loveInParent2);
        console.log("Total love:", totalLove);
        
        assertGe(totalLove, MIN_LOVE_FOR_GENE);
        
        // Propose a rainbow wings gene for the back trait
        vm.prank(geneProposer);
        breedingVote.proposeGene(
            ticketId,
            AminalBreedingVote.GeneType.BACK,
            address(geneContract),
            1 // Rainbow Wings token ID
        );
        
        // Verify proposal was created
        AminalBreedingVote.GeneProposal[] memory proposals = breedingVote.getGeneProposals(
            ticketId,
            AminalBreedingVote.GeneType.BACK
        );
        
        assertEq(proposals.length, 1);
        assertEq(proposals[0].geneContract, address(geneContract));
        assertEq(proposals[0].tokenId, 1);
        assertEq(proposals[0].proposer, geneProposer);
    }
    
    function test_RevertWhen_InsufficientLoveForGeneProposal() public {
        uint256 ticketId = _createBreedingTicket();
        
        // Poor user has no love in either parent
        vm.prank(poorUser);
        vm.expectRevert(AminalBreedingVote.InsufficientLoveInParents.selector);
        breedingVote.proposeGene(
            ticketId,
            AminalBreedingVote.GeneType.BACK,
            address(geneContract),
            1
        );
    }
    
    function test_RevertWhen_WrongGeneType() public {
        uint256 ticketId = _createBreedingTicket();
        
        // Give proposer enough love
        vm.prank(geneProposer);
        (bool success,) = address(parent1).call{value: 0.02 ether}("");
        assertTrue(success);
        
        // Try to propose arm gene for back trait
        vm.prank(geneProposer);
        vm.expectRevert("Gene trait type mismatch");
        breedingVote.proposeGene(
            ticketId,
            AminalBreedingVote.GeneType.BACK,
            address(geneContract),
            3 // Laser Arms - wrong type
        );
    }
    
    function test_VoteForGene() public {
        uint256 ticketId = _createBreedingTicket();
        
        // Proposer creates gene proposal
        vm.prank(geneProposer);
        (bool success,) = address(parent1).call{value: 0.02 ether}("");
        assertTrue(success);
        
        vm.prank(geneProposer);
        breedingVote.proposeGene(
            ticketId,
            AminalBreedingVote.GeneType.BACK,
            address(geneContract),
            1 // Rainbow Wings
        );
        
        // Voter1 feeds parents and votes for the gene
        vm.prank(voter1);
        (success,) = address(parent1).call{value: 0.5 ether}("");
        assertTrue(success);
        
        vm.prank(voter1);
        (success,) = address(parent2).call{value: 0.5 ether}("");
        assertTrue(success);
        
        uint256 votingPower = parent1.loveFromUser(voter1) + parent2.loveFromUser(voter1);
        
        // Vote for the gene
        vm.prank(voter1);
        breedingVote.voteForGene(ticketId, AminalBreedingVote.GeneType.BACK, 0);
        
        // Check vote was recorded
        uint256 geneVotes = breedingVote.getGeneVotes(
            ticketId,
            AminalBreedingVote.GeneType.BACK,
            0
        );
        assertEq(geneVotes, votingPower);
    }
    
    function test_GeneWinsVoting() public {
        uint256 ticketId = _createBreedingTicket();
        
        // Proposer creates multiple gene proposals
        vm.prank(geneProposer);
        (bool success,) = address(parent1).call{value: 0.02 ether}("");
        assertTrue(success);
        
        // Propose Rainbow Wings and Crystal Wings
        vm.prank(geneProposer);
        breedingVote.proposeGene(
            ticketId,
            AminalBreedingVote.GeneType.BACK,
            address(geneContract),
            1 // Rainbow Wings
        );
        
        vm.prank(geneProposer);
        breedingVote.proposeGene(
            ticketId,
            AminalBreedingVote.GeneType.BACK,
            address(geneContract),
            2 // Crystal Wings
        );
        
        // Voter1 votes for parent1 trait
        vm.prank(voter1);
        (success,) = address(parent1).call{value: 0.1 ether}("");
        assertTrue(success);
        
        AminalBreedingVote.GeneType[] memory geneTypes = new AminalBreedingVote.GeneType[](1);
        bool[] memory votesForParent1 = new bool[](1);
        geneTypes[0] = AminalBreedingVote.GeneType.BACK;
        votesForParent1[0] = true;
        
        vm.prank(voter1);
        breedingVote.vote(ticketId, geneTypes, votesForParent1);
        
        // Voter2 votes for Rainbow Wings gene with MORE voting power
        vm.prank(voter2);
        (success,) = address(parent1).call{value: 0.5 ether}("");
        assertTrue(success);
        vm.prank(voter2);
        (success,) = address(parent2).call{value: 0.5 ether}("");
        assertTrue(success);
        
        vm.prank(voter2);
        breedingVote.voteForGene(ticketId, AminalBreedingVote.GeneType.BACK, 0);
        
        // Also vote to proceed with breeding (not veto)
        vm.prank(voter2);
        breedingVote.voteOnVeto(ticketId, false);
        
        // Wait for voting to end
        vm.warp(block.timestamp + 3 days + 1);
        
        // Execute breeding
        address childAddress = breedingVote.executeBreeding(ticketId);
        Aminal child = Aminal(payable(childAddress));
        
        // Verify the gene trait won
        IGenes.Genes memory childTraits = child.getTraits();
        assertEq(childTraits.back, "Rainbow Wings", "Gene should have won the vote");
    }
    
    function test_MultipleGenesCompeting() public {
        uint256 ticketId = _createBreedingTicket();
        
        // Multiple proposers add different genes
        address[] memory proposers = new address[](3);
        proposers[0] = makeAddr("proposer1");
        proposers[1] = makeAddr("proposer2");
        proposers[2] = makeAddr("proposer3");
        
        // Fund proposers
        for (uint i = 0; i < proposers.length; i++) {
            vm.deal(proposers[i], 1 ether);
            vm.prank(proposers[i]);
            (bool s1,) = address(parent1).call{value: 0.01 ether}("");
            vm.prank(proposers[i]);
            (bool s2,) = address(parent2).call{value: 0.01 ether}("");
            assertTrue(s1 && s2);
        }
        
        // Each proposer proposes a different gene
        vm.prank(proposers[0]);
        breedingVote.proposeGene(ticketId, AminalBreedingVote.GeneType.BACK, address(geneContract), 1); // Rainbow
        
        vm.prank(proposers[1]);
        breedingVote.proposeGene(ticketId, AminalBreedingVote.GeneType.BACK, address(geneContract), 2); // Crystal
        
        // Also test other trait types
        vm.prank(proposers[2]);
        breedingVote.proposeGene(ticketId, AminalBreedingVote.GeneType.ARM, address(geneContract), 3); // Laser Arms
        
        // Verify all proposals exist
        AminalBreedingVote.GeneProposal[] memory backProposals = breedingVote.getGeneProposals(
            ticketId,
            AminalBreedingVote.GeneType.BACK
        );
        assertEq(backProposals.length, 2);
        
        AminalBreedingVote.GeneProposal[] memory armProposals = breedingVote.getGeneProposals(
            ticketId,
            AminalBreedingVote.GeneType.ARM
        );
        assertEq(armProposals.length, 1);
    }
    
    function test_MixedVoting_ParentsAndGenes() public {
        uint256 ticketId = _createBreedingTicket();
        
        // Setup gene proposal
        vm.prank(geneProposer);
        (bool success,) = address(parent1).call{value: 0.02 ether}("");
        assertTrue(success);
        
        vm.prank(geneProposer);
        breedingVote.proposeGene(
            ticketId,
            AminalBreedingVote.GeneType.BACK,
            address(geneContract),
            1 // Rainbow Wings
        );
        
        // Create 3 voters with different preferences
        address voterParent1 = makeAddr("voterP1");
        address voterParent2 = makeAddr("voterP2");
        address voterGene = makeAddr("voterGene");
        
        // Fund and setup voters
        address[3] memory voters = [voterParent1, voterParent2, voterGene];
        uint256[3] memory amounts = [uint256(0.2 ether), 0.15 ether, 0.3 ether];
        
        for (uint i = 0; i < voters.length; i++) {
            vm.deal(voters[i], 1 ether);
            vm.prank(voters[i]);
            (bool s1,) = address(parent1).call{value: amounts[i]}("");
            vm.prank(voters[i]);
            (bool s2,) = address(parent2).call{value: amounts[i] / 2}("");
            assertTrue(s1 && s2);
        }
        
        // Vote for parent1 trait
        AminalBreedingVote.GeneType[] memory geneTypes = new AminalBreedingVote.GeneType[](1);
        bool[] memory votesForParent1 = new bool[](1);
        geneTypes[0] = AminalBreedingVote.GeneType.BACK;
        votesForParent1[0] = true;
        
        vm.prank(voterParent1);
        breedingVote.vote(ticketId, geneTypes, votesForParent1);
        
        // Vote for parent2 trait
        votesForParent1[0] = false;
        vm.prank(voterParent2);
        breedingVote.vote(ticketId, geneTypes, votesForParent1);
        
        // Vote for gene
        vm.prank(voterGene);
        breedingVote.voteForGene(ticketId, AminalBreedingVote.GeneType.BACK, 0);
        
        // Check current standings
        uint256 p1Votes = parent1.loveFromUser(voterParent1) + parent2.loveFromUser(voterParent1);
        uint256 p2Votes = parent1.loveFromUser(voterParent2) + parent2.loveFromUser(voterParent2);
        uint256 geneVotes = parent1.loveFromUser(voterGene) + parent2.loveFromUser(voterGene);
        
        console.log("Parent1 votes:", p1Votes);
        console.log("Parent2 votes:", p2Votes);
        console.log("Gene votes:", geneVotes);
        
        // Gene should have most votes
        assertTrue(geneVotes > p1Votes && geneVotes > p2Votes);
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
        
        return 1; // First ticket ID
    }
}