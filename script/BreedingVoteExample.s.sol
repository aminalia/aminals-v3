// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {AminalFactory} from "src/AminalFactory.sol";
import {AminalBreedingVote} from "src/AminalBreedingVote.sol";
import {Aminal} from "src/Aminal.sol";
import {ITraits} from "src/interfaces/ITraits.sol";

/**
 * @title BreedingVoteExample
 * @notice Example script demonstrating the Aminal breeding vote system
 * @dev Run with: forge script script/BreedingVoteExample.s.sol -vvv
 */
contract BreedingVoteExample is Script {
    function run() public {
        // Deploy factory and voting contract
        address deployer = makeAddr("deployer");
        vm.startPrank(deployer);
        
        AminalFactory factory = new AminalFactory(
            deployer,
            "https://api.aminals.com/metadata/"
        );
        AminalBreedingVote breedingVote = new AminalBreedingVote(address(factory));
        
        vm.stopPrank();
        
        console.log("Factory deployed at:", address(factory));
        console.log("BreedingVote deployed at:", address(breedingVote));
        
        // Create two parent Aminals
        ITraits.Traits memory dragonTraits = ITraits.Traits({
            back: "Dragon Wings",
            arm: "Clawed Arms",
            tail: "Fire Tail",
            ears: "Horned Ears",
            body: "Scaled Body",
            face: "Fierce Face",
            mouth: "Sharp Teeth",
            misc: "Glowing Eyes"
        });
        
        address dragon = factory.createAminal(
            "FireDragon",
            "FIRE",
            "A powerful fire dragon",
            "fire-dragon.json",
            dragonTraits
        );
        
        console.log("Dragon created at:", dragon);
        
        ITraits.Traits memory bunnyTraits = ITraits.Traits({
            back: "Angel Wings",
            arm: "Soft Arms",
            tail: "Cotton Tail",
            ears: "Bunny Ears",
            body: "Fluffy Body",
            face: "Cute Face",
            mouth: "Sweet Smile",
            misc: "Sparkles"
        });
        
        address bunny = factory.createAminal(
            "AngelBunny",
            "ANGEL",
            "A gentle angel bunny",
            "angel-bunny.json",
            bunnyTraits
        );
        
        console.log("Bunny created at:", bunny);
        
        // Create voters and give them love
        address alice = makeAddr("alice");
        address bob = makeAddr("bob");
        address charlie = makeAddr("charlie");
        
        console.log("\n--- GIVING LOVE TO AMINALS ---");
        
        // Alice: 100 love to dragon, 50 love to bunny (voting power = 50)
        vm.deal(alice, 20 ether);
        vm.prank(alice);
        (bool sent1,) = dragon.call{value: 10 ether}("");
        require(sent1);
        vm.prank(alice);
        (bool sent2,) = bunny.call{value: 5 ether}("");
        require(sent2);
        console.log("Alice gave love - Dragon:", Aminal(payable(dragon)).loveFromUser(alice), "Bunny:", Aminal(payable(bunny)).loveFromUser(alice));
        
        // Bob: 80 love to both (voting power = 80)
        vm.deal(bob, 20 ether);
        vm.prank(bob);
        (bool sent3,) = dragon.call{value: 8 ether}("");
        require(sent3);
        vm.prank(bob);
        (bool sent4,) = bunny.call{value: 8 ether}("");
        require(sent4);
        console.log("Bob gave love - Dragon:", Aminal(payable(dragon)).loveFromUser(bob), "Bunny:", Aminal(payable(bunny)).loveFromUser(bob));
        
        // Charlie: 30 love to dragon, 60 love to bunny (voting power = 30)
        vm.deal(charlie, 20 ether);
        vm.prank(charlie);
        (bool sent5,) = dragon.call{value: 3 ether}("");
        require(sent5);
        vm.prank(charlie);
        (bool sent6,) = bunny.call{value: 6 ether}("");
        require(sent6);
        console.log("Charlie gave love - Dragon:", Aminal(payable(dragon)).loveFromUser(charlie), "Bunny:", Aminal(payable(bunny)).loveFromUser(charlie));
        
        // Create breeding proposal
        console.log("\n--- CREATING BREEDING PROPOSAL ---");
        uint256 proposalId = breedingVote.createProposal(
            dragon,
            bunny,
            "A magical hybrid of dragon and bunny",
            "dragon-bunny-hybrid.json",
            1 hours // 1 hour voting period
        );
        console.log("Proposal created with ID:", proposalId);
        
        // Check voting power
        console.log("\n--- VOTING POWER ---");
        {
            (bool canVoteAlice, uint256 powerAlice) = breedingVote.canVote(proposalId, alice);
            console.log("Alice can vote:", canVoteAlice, "with power:", powerAlice);
        }
        {
            (bool canVoteBob, uint256 powerBob) = breedingVote.canVote(proposalId, bob);
            console.log("Bob can vote:", canVoteBob, "with power:", powerBob);
        }
        {
            (bool canVoteCharlie, uint256 powerCharlie) = breedingVote.canVote(proposalId, charlie);
            console.log("Charlie can vote:", canVoteCharlie, "with power:", powerCharlie);
        }
        
        // Cast votes
        console.log("\n--- CASTING VOTES ---");
        
        // Alice votes for all dragon traits
        AminalBreedingVote.TraitType[] memory aliceTraits = new AminalBreedingVote.TraitType[](8);
        bool[] memory aliceVotes = new bool[](8);
        for (uint256 i = 0; i < 8; i++) {
            aliceTraits[i] = AminalBreedingVote.TraitType(i);
            aliceVotes[i] = true; // All dragon
        }
        
        vm.prank(alice);
        breedingVote.vote(proposalId, aliceTraits, aliceVotes);
        console.log("Alice voted for all dragon traits");
        
        // Bob votes for specific traits
        AminalBreedingVote.TraitType[] memory bobTraits = new AminalBreedingVote.TraitType[](4);
        bool[] memory bobVotes = new bool[](4);
        bobTraits[0] = AminalBreedingVote.TraitType.BACK;   // Angel Wings
        bobTraits[1] = AminalBreedingVote.TraitType.EARS;   // Bunny Ears
        bobTraits[2] = AminalBreedingVote.TraitType.BODY;   // Fluffy Body
        bobTraits[3] = AminalBreedingVote.TraitType.MOUTH;  // Sweet Smile
        // All false = bunny traits
        
        vm.prank(bob);
        breedingVote.vote(proposalId, bobTraits, bobVotes);
        console.log("Bob voted for bunny wings, ears, body, and mouth");
        
        // Charlie votes mixed
        AminalBreedingVote.TraitType[] memory charlieTraits = new AminalBreedingVote.TraitType[](4);
        bool[] memory charlieVotes = new bool[](4);
        charlieTraits[0] = AminalBreedingVote.TraitType.TAIL;  // Fire Tail
        charlieTraits[1] = AminalBreedingVote.TraitType.FACE;  // Fierce Face
        charlieTraits[2] = AminalBreedingVote.TraitType.MISC;  // Glowing Eyes
        charlieTraits[3] = AminalBreedingVote.TraitType.ARM;   // Soft Arms
        charlieVotes[0] = true;  // Dragon
        charlieVotes[1] = true;  // Dragon
        charlieVotes[2] = true;  // Dragon
        charlieVotes[3] = false; // Bunny
        
        vm.prank(charlie);
        breedingVote.vote(proposalId, charlieTraits, charlieVotes);
        console.log("Charlie voted mixed traits");
        
        // Check current results
        console.log("\n--- VOTE RESULTS BEFORE EXECUTION ---");
        AminalBreedingVote.TraitVote[8] memory results = breedingVote.getVoteResults(proposalId);
        
        string[8] memory traitNames = ["Back", "Arm", "Tail", "Ears", "Body", "Face", "Mouth", "Misc"];
        for (uint256 i = 0; i < 8; i++) {
            console.log(string.concat(traitNames[i], " - Dragon: ", vm.toString(results[i].parent1Votes)));
            console.log(string.concat("    Bunny: ", vm.toString(results[i].parent2Votes)));
            console.log(string.concat("    Winner: ", results[i].parent1Votes >= results[i].parent2Votes ? "Dragon" : "Bunny"));
        }
        
        // Skip time to after voting period
        console.log("\n--- EXECUTING BREEDING ---");
        vm.warp(block.timestamp + 2 hours);
        
        address childAddress = breedingVote.executeBreeding(proposalId);
        console.log("Child born at:", childAddress);
        
        // Display child details
        Aminal child = Aminal(payable(childAddress));
        ITraits.Traits memory childTraits = child.getTraits();
        
        console.log("\n--- CHILD TRAITS (Based on Voting) ---");
        console.log("Back:", childTraits.back);
        console.log("Arm:", childTraits.arm);
        console.log("Tail:", childTraits.tail);
        console.log("Ears:", childTraits.ears);
        console.log("Body:", childTraits.body);
        console.log("Face:", childTraits.face);
        console.log("Mouth:", childTraits.mouth);
        console.log("Misc:", childTraits.misc);
        
        console.log("\nTotal Aminals in existence:", factory.totalAminals());
    }
}