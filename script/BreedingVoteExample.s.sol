// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {AminalFactory} from "src/AminalFactory.sol";
import {AminalBreedingVote} from "src/AminalBreedingVote.sol";
import {Aminal} from "src/Aminal.sol";
import {IGenes} from "src/interfaces/IGenes.sol";

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
        
        AminalFactory factory = new AminalFactory(
            deployer,
            "https://api.aminals.com/metadata/",
            firstParentData,
            secondParentData
        );
        // Note: This example assumes breeding tickets are created via BreedingSkill
        // For this example, we'll deploy with a placeholder address
        AminalBreedingVote breedingVote = new AminalBreedingVote(address(factory), address(0x123));
        
        vm.stopPrank();
        
        console.log("Factory deployed at:", address(factory));
        console.log("BreedingVote deployed at:", address(breedingVote));
        
        // Create two parent Aminals
        IGenes.Genes memory dragonTraits = IGenes.Genes({
            back: "Dragon Wings",
            arm: "Clawed Arms",
            tail: "Fire Tail",
            ears: "Horned Ears",
            body: "Scaled Body",
            face: "Fierce Face",
            mouth: "Sharp Teeth",
            misc: "Glowing Eyes"
        });
        
        address dragon = factory.createAminalWithTraits(
            "FireDragon",
            "FIRE",
            "A powerful fire dragon",
            "fire-dragon.json",
            dragonTraits
        );
        
        console.log("Dragon created at:", dragon);
        
        IGenes.Genes memory bunnyTraits = IGenes.Genes({
            back: "Angel Wings",
            arm: "Soft Arms",
            tail: "Cotton Tail",
            ears: "Bunny Ears",
            body: "Fluffy Body",
            face: "Cute Face",
            mouth: "Sweet Smile",
            misc: "Sparkles"
        });
        
        address bunny = factory.createAminalWithTraits(
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
        
        // Note: In real flow, breeding ticket would be created via BreedingSkill
        console.log("\n--- SIMULATING BREEDING TICKET CREATION ---");
        console.log("(In production, this happens through BreedingSkill)");
        uint256 ticketId = 1; // Simulated ticket ID
        
        // Check voting power
        console.log("\n--- VOTING POWER (SIMULATED) ---");
        console.log("Alice would have power based on love in both parents");
        console.log("Bob would have power based on love in both parents");
        console.log("Charlie would have power based on love in both parents");
        
        // Cast votes
        console.log("\n--- CASTING VOTES ---");
        
        // Alice votes for all dragon genes
        AminalBreedingVote.GeneType[] memory aliceGeneTypes = new AminalBreedingVote.GeneType[](8);
        bool[] memory aliceVotes = new bool[](8);
        for (uint256 i = 0; i < 8; i++) {
            aliceGeneTypes[i] = AminalBreedingVote.GeneType(i);
            aliceVotes[i] = true; // All dragon
        }
        
        // In real flow, voting would happen on actual ticket
        console.log("Alice would vote for all dragon genes");
        
        // Bob votes for specific traits
        AminalBreedingVote.GeneType[] memory bobGeneTypes = new AminalBreedingVote.GeneType[](4);
        bool[] memory bobVotes = new bool[](4);
        bobGeneTypes[0] = AminalBreedingVote.GeneType.BACK;   // Angel Wings
        bobGeneTypes[1] = AminalBreedingVote.GeneType.EARS;   // Bunny Ears
        bobGeneTypes[2] = AminalBreedingVote.GeneType.BODY;   // Fluffy Body
        bobGeneTypes[3] = AminalBreedingVote.GeneType.MOUTH;  // Sweet Smile
        // All false = bunny traits
        
        console.log("Bob would vote for bunny wings, ears, body, and mouth");
        
        // Charlie votes mixed
        AminalBreedingVote.GeneType[] memory charlieTraits = new AminalBreedingVote.GeneType[](4);
        bool[] memory charlieVotes = new bool[](4);
        charlieTraits[0] = AminalBreedingVote.GeneType.TAIL;  // Fire Tail
        charlieTraits[1] = AminalBreedingVote.GeneType.FACE;  // Fierce Face
        charlieTraits[2] = AminalBreedingVote.GeneType.MISC;  // Glowing Eyes
        charlieTraits[3] = AminalBreedingVote.GeneType.ARM;   // Soft Arms
        charlieVotes[0] = true;  // Dragon
        charlieVotes[1] = true;  // Dragon
        charlieVotes[2] = true;  // Dragon
        charlieVotes[3] = false; // Bunny
        
        console.log("Charlie would vote mixed traits");
        
        // Check current results
        console.log("\n--- VOTE RESULTS (SIMULATED) ---");
        // In real flow, we would call getVoteResults(ticketId)
        
        console.log("Each trait would show dragon vs bunny vote counts");
        console.log("Winners determined by highest vote count per trait");
        
        // Skip time to after voting period
        console.log("\n--- BREEDING EXECUTION (SIMULATED) ---");
        console.log("After 3 days, anyone could call executeBreeding(ticketId)");
        console.log("Child would be born with traits based on voting results");
        
        console.log("\n--- SUMMARY ---");
        console.log("Total Aminals in existence:", factory.totalAminals());
        console.log("\nThis example demonstrates the voting mechanics.");
        console.log("In production, breeding starts with BreedingSkill proposal/acceptance.");
    }
}