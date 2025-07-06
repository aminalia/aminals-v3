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
        factory = new AminalFactory(owner, firstParentData, secondParentData);
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
}