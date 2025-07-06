// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {BreedingSkill} from "src/skills/BreedingSkill.sol";
import {AminalBreedingVote} from "src/AminalBreedingVote.sol";
import {AminalFactory} from "src/AminalFactory.sol";
import {Aminal} from "src/Aminal.sol";
import {IGenes} from "src/interfaces/IGenes.sol";

/**
 * @title BreedingTestBase
 * @notice Base contract for all breeding-related tests to reduce duplication
 */
abstract contract BreedingTestBase is Test {
    // Contracts
    BreedingSkill public breedingSkill;
    AminalBreedingVote public breedingVote;
    AminalFactory public factory;
    
    // Standard Aminals
    Aminal public parent1;
    Aminal public parent2;
    
    // Common test users
    address public owner;
    address public breederA;
    address public breederB;
    address public voter1;
    address public voter2;
    address public voter3;
    
    // Constants
    uint256 constant BREEDING_COST = 2500;
    uint256 constant MIN_LOVE_FOR_GENE = 100;
    uint256 constant GENE_PROPOSAL_DURATION = 3 days;
    uint256 constant VOTING_DURATION = 4 days;
    
    string constant BASE_URI = "https://api.aminals.com/metadata/";
    
    // Standard parent data
    AminalFactory.ParentData public adamData = AminalFactory.ParentData({
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
    
    AminalFactory.ParentData public eveData = AminalFactory.ParentData({
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
    
    // Standard test traits
    IGenes.Genes public dragonTraits = IGenes.Genes({
        back: "Dragon Wings",
        arm: "Strong Arms",
        tail: "Fire Tail",
        ears: "Pointed Ears",
        body: "Scaled Body",
        face: "Fierce Face",
        mouth: "Sharp Teeth",
        misc: "Glowing Eyes"
    });
    
    IGenes.Genes public bunnyTraits = IGenes.Genes({
        back: "Angel Wings",
        arm: "Gentle Arms",
        tail: "Fluffy Tail",
        ears: "Round Ears",
        body: "Soft Body",
        face: "Kind Face",
        mouth: "Sweet Smile",
        misc: "Sparkles"
    });
    
    function setUp() public virtual {
        // Setup standard users
        owner = makeAddr("owner");
        breederA = makeAddr("breederA");
        breederB = makeAddr("breederB");
        voter1 = makeAddr("voter1");
        voter2 = makeAddr("voter2");
        voter3 = makeAddr("voter3");
        
        // Deploy contracts with circular dependency resolution
        _deployContracts();
        
        // Create standard parent Aminals
        _createStandardParents();
        
        // Fund users
        _fundUsers();
    }
    
    function _deployContracts() internal {
        vm.prank(owner);
        factory = new AminalFactory(owner, BASE_URI, adamData, eveData);
        
        // Resolve circular dependency
        uint256 nonce = vm.getNonce(address(this));
        address predictedBreedingSkill = vm.computeCreateAddress(address(this), nonce + 1);
        
        breedingVote = new AminalBreedingVote(address(factory), predictedBreedingSkill);
        breedingSkill = new BreedingSkill(address(factory), address(breedingVote));
        
        // Set the breeding vote contract in factory
        vm.prank(owner);
        factory.setBreedingVoteContract(address(breedingVote));
    }
    
    function _createStandardParents() internal {
        vm.prank(owner);
        address parent1Address = factory.createAminalWithGenes(
            "FireDragon",
            "FIRE",
            "A fierce dragon",
            "dragon.json",
            dragonTraits
        );
        parent1 = Aminal(payable(parent1Address));
        
        vm.prank(owner);
        address parent2Address = factory.createAminalWithGenes(
            "AngelBunny",
            "ANGEL",
            "A gentle bunny",
            "bunny.json",
            bunnyTraits
        );
        parent2 = Aminal(payable(parent2Address));
    }
    
    function _fundUsers() internal {
        vm.deal(owner, 100 ether);
        vm.deal(breederA, 10 ether);
        vm.deal(breederB, 10 ether);
        vm.deal(voter1, 10 ether);
        vm.deal(voter2, 10 ether);
        vm.deal(voter3, 10 ether);
    }
    
    // Helper functions
    function _feedAminal(address user, address aminal, uint256 amount) internal {
        vm.prank(user);
        (bool success,) = aminal.call{value: amount}("");
        assertTrue(success, "Failed to feed Aminal");
    }
    
    function _createBreedingTicket() internal returns (uint256 ticketId) {
        return _createBreedingTicket(breederA, breederB);
    }
    
    function _createBreedingTicket(address proposer, address acceptor) internal returns (uint256 ticketId) {
        // Feed both parents to enable breeding
        _feedAminal(proposer, address(parent1), 0.5 ether);
        _feedAminal(acceptor, address(parent2), 0.5 ether);
        
        // Create proposal
        bytes memory proposalData = abi.encodeWithSelector(
            BreedingSkill.createProposal.selector,
            address(parent2),
            "Test breeding",
            "test.json"
        );
        
        vm.prank(proposer);
        parent1.useSkill(address(breedingSkill), proposalData);
        
        // Accept proposal
        bytes memory acceptData = abi.encodeWithSelector(
            BreedingSkill.acceptProposal.selector,
            uint256(1)
        );
        
        vm.prank(acceptor);
        parent2.useSkill(address(breedingSkill), acceptData);
        
        return 1; // First ticket ID
    }
    
    function _warpToVotingPhase() internal {
        vm.warp(block.timestamp + GENE_PROPOSAL_DURATION + 1);
    }
    
    function _warpToExecutionPhase() internal {
        vm.warp(block.timestamp + GENE_PROPOSAL_DURATION + VOTING_DURATION + 1);
    }
    
    function _getCurrentPhase(uint256 ticketId) internal view returns (AminalBreedingVote.Phase) {
        return breedingVote.getCurrentPhase(ticketId);
    }
    
    function _assertPhase(uint256 ticketId, AminalBreedingVote.Phase expectedPhase) internal {
        AminalBreedingVote.Phase currentPhase = _getCurrentPhase(ticketId);
        assertEq(uint256(currentPhase), uint256(expectedPhase), "Wrong breeding phase");
    }
    
    function _voteOnTraits(
        address voter,
        uint256 ticketId,
        AminalBreedingVote.GeneType[] memory geneTypes,
        bool[] memory votesForParent1
    ) internal {
        vm.prank(voter);
        breedingVote.vote(ticketId, geneTypes, votesForParent1);
    }
    
    function _voteOnVeto(address voter, uint256 ticketId, bool voteForVeto) internal {
        vm.prank(voter);
        breedingVote.voteOnVeto(ticketId, voteForVeto);
    }
}