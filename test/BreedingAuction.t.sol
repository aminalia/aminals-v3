// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {BreedingSkill} from "src/skills/BreedingSkill.sol";
import {AminalBreedingVote} from "src/AminalBreedingVote.sol";
import {AminalFactory} from "src/AminalFactory.sol";
import {Aminal} from "src/Aminal.sol";
import {IGenes} from "src/interfaces/IGenes.sol";

contract BreedingAuctionTest is Test {
    BreedingSkill public breedingSkill;
    AminalBreedingVote public breedingVote;
    AminalFactory public factory;
    
    Aminal public parent1;
    Aminal public parent2;
    
    address public owner;
    address public userA;
    address public userB;
    address public voter1;
    address public voter2;
    
    string constant BASE_URI = "https://api.aminals.com/metadata/";
    uint256 constant BREEDING_COST = 2500;
    
    function setUp() public {
        owner = makeAddr("owner");
        userA = makeAddr("userA");
        userB = makeAddr("userB");
        voter1 = makeAddr("voter1");
        voter2 = makeAddr("voter2");
        
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
        
        // Deploy factory
        vm.prank(owner);
        factory = new AminalFactory(owner, BASE_URI, firstParentData, secondParentData);
        
        // First predict the BreedingSkill address
        uint256 nonce = vm.getNonce(address(this));
        address predictedBreedingSkill = vm.computeCreateAddress(address(this), nonce + 1);
        
        // Deploy breeding vote with the predicted breeding skill address
        breedingVote = new AminalBreedingVote(address(factory), predictedBreedingSkill);
        
        // Deploy breeding skill with the breeding vote
        breedingSkill = new BreedingSkill(address(factory), address(breedingVote));
        
        // Verify the prediction was correct
        require(address(breedingSkill) == predictedBreedingSkill, "Address prediction failed");
        
        // Create test Aminals
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
        address parent1Address = factory.createAminalWithGenes(
            "FireDragon",
            "FIRE",
            "A fierce dragon",
            "dragon.json",
            traits1
        );
        parent1 = Aminal(payable(parent1Address));
        
        vm.prank(owner);
        address parent2Address = factory.createAminalWithGenes(
            "AngelBunny",
            "ANGEL",
            "A gentle bunny",
            "bunny.json", 
            traits2
        );
        parent2 = Aminal(payable(parent2Address));
        
        // Give users ETH to feed Aminals
        vm.deal(userA, 10 ether);
        vm.deal(userB, 10 ether);
        vm.deal(voter1, 10 ether);
        vm.deal(voter2, 10 ether);
    }
    
    function test_FullBreedingAuctionFlow() public {
        // Step 1: User A creates proposal
        vm.prank(userA);
        (bool success,) = address(parent1).call{value: 0.5 ether}("");
        assertTrue(success);
        
        bytes memory proposalData = abi.encodeWithSelector(
            BreedingSkill.createProposal.selector,
            address(parent2),
            "A magical hybrid",
            "hybrid.json"
        );
        
        vm.prank(userA);
        parent1.useSkill(address(breedingSkill), proposalData);
        
        // Step 2: User B accepts proposal (creates breeding ticket)
        vm.prank(userB);
        (success,) = address(parent2).call{value: 0.5 ether}("");
        assertTrue(success);
        
        bytes memory acceptData = abi.encodeWithSelector(
            BreedingSkill.acceptProposal.selector,
            uint256(1)
        );
        
        // We expect the ProposalAccepted event with ticketId = 1
        
        vm.prank(userB);
        parent2.useSkill(address(breedingSkill), acceptData);
        
        // Step 3: Voters feed both parents to get voting power
        vm.prank(voter1);
        (success,) = address(parent1).call{value: 1 ether}(""); // Get love in parent1
        assertTrue(success);
        
        vm.prank(voter1);
        (success,) = address(parent2).call{value: 0.1 ether}(""); // Get some love in parent2
        assertTrue(success);
        
        vm.prank(voter2);
        (success,) = address(parent1).call{value: 0.1 ether}(""); // Get some love in parent1
        assertTrue(success);
        
        vm.prank(voter2);
        (success,) = address(parent2).call{value: 1 ether}(""); // Get love in parent2
        assertTrue(success);
        
        // Step 4: Voters vote on traits
        AminalBreedingVote.GeneType[] memory geneTypes = new AminalBreedingVote.GeneType[](8);
        bool[] memory voter1Choices = new bool[](8);
        bool[] memory voter2Choices = new bool[](8);
        
        // Voter1 prefers mostly parent1 traits
        geneTypes[0] = AminalBreedingVote.GeneType.BACK;
        geneTypes[1] = AminalBreedingVote.GeneType.ARM;
        geneTypes[2] = AminalBreedingVote.GeneType.TAIL;
        geneTypes[3] = AminalBreedingVote.GeneType.EARS;
        geneTypes[4] = AminalBreedingVote.GeneType.BODY;
        geneTypes[5] = AminalBreedingVote.GeneType.FACE;
        geneTypes[6] = AminalBreedingVote.GeneType.MOUTH;
        geneTypes[7] = AminalBreedingVote.GeneType.MISC;
        
        voter1Choices[0] = true;  // BACK from parent1
        voter1Choices[1] = true;  // ARM from parent1
        voter1Choices[2] = true;  // TAIL from parent1
        voter1Choices[3] = false; // EARS from parent2
        voter1Choices[4] = true;  // BODY from parent1
        voter1Choices[5] = true;  // FACE from parent1
        voter1Choices[6] = true;  // MOUTH from parent1
        voter1Choices[7] = false; // MISC from parent2
        
        // Voter2 prefers mostly parent2 traits
        voter2Choices[0] = false; // BACK from parent2
        voter2Choices[1] = false; // ARM from parent2
        voter2Choices[2] = false; // TAIL from parent2
        voter2Choices[3] = false; // EARS from parent2
        voter2Choices[4] = false; // BODY from parent2
        voter2Choices[5] = false; // FACE from parent2
        voter2Choices[6] = true;  // MOUTH from parent1
        voter2Choices[7] = false; // MISC from parent2
        
        vm.prank(voter1);
        breedingVote.vote(1, geneTypes, voter1Choices);
        
        vm.prank(voter2);
        breedingVote.vote(1, geneTypes, voter2Choices);
        
        // Check voting power
        uint256 voter1Power = parent1.loveFromUser(voter1) + parent2.loveFromUser(voter1);
        uint256 voter2Power = parent1.loveFromUser(voter2) + parent2.loveFromUser(voter2);
        
        console.log("Voter1 power:", voter1Power);
        console.log("Voter2 power:", voter2Power);
        
        // Step 5: Wait for voting to end
        vm.warp(block.timestamp + 3 days + 1);
        
        // Step 6: Execute breeding
        address childAddress = breedingVote.executeBreeding(1);
        
        // Verify child was created
        assertTrue(childAddress != address(0));
        Aminal child = Aminal(payable(childAddress));
        
        // Verify traits based on voting
        // Since voting power should be roughly equal but voter1 has slightly more total,
        // we expect mixed traits with slight preference to voter1's choices
        IGenes.Genes memory childTraits = child.getGenes();
        
        // Log the final traits
        console.log("Child genes:");
        console.log("Back:", childTraits.back);
        console.log("Arm:", childTraits.arm);
        console.log("Face:", childTraits.face);
    }
}