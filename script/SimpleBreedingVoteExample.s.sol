// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {AminalFactory} from "src/AminalFactory.sol";
import {AminalBreedingVote} from "src/AminalBreedingVote.sol";
import {Aminal} from "src/Aminal.sol";
import {IGenes} from "src/interfaces/IGenes.sol";

/**
 * @title SimpleBreedingVoteExample
 * @notice Simplified example of the breeding vote system
 * @dev Run with: forge script script/SimpleBreedingVoteExample.s.sol
 */
contract SimpleBreedingVoteExample is Script {
    function run() public {
        // Setup
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
        
        AminalFactory factory = new AminalFactory(deployer, "https://api.aminals.com/", firstParentData, secondParentData);
        AminalBreedingVote breedingVote = new AminalBreedingVote(address(factory), address(0x123)); // Placeholder breeding skill
        
        vm.stopPrank();
        
        console.log("Deployed contracts");
        
        // Create parents
        IGenes.Genes memory traits1 = IGenes.Genes({
            back: "Dragon Wings",
            arm: "Clawed Arms", 
            tail: "Fire Tail",
            ears: "Horned Ears",
            body: "Scaled Body",
            face: "Fierce Face",
            mouth: "Sharp Teeth",
            misc: "Glowing Eyes"
        });
        
        address parent1 = factory.createAminal("Dragon", "DRAG", "Dragon", "dragon.json", traits1);
        
        IGenes.Genes memory traits2 = IGenes.Genes({
            back: "Angel Wings",
            arm: "Soft Arms",
            tail: "Cotton Tail", 
            ears: "Bunny Ears",
            body: "Fluffy Body",
            face: "Cute Face",
            mouth: "Sweet Smile",
            misc: "Sparkles"
        });
        
        address parent2 = factory.createAminal("Bunny", "BUN", "Bunny", "bunny.json", traits2);
        
        console.log("Created parents");
        
        // Give love
        address voter = makeAddr("voter");
        vm.deal(voter, 20 ether);
        vm.startPrank(voter);
        
        // Give equal love to both
        (bool s1,) = parent1.call{value: 5 ether}("");
        (bool s2,) = parent2.call{value: 5 ether}("");
        require(s1 && s2);
        
        vm.stopPrank();
        
        console.log("Gave love to parents");
        
        // In real flow, breeding ticket created via BreedingSkill
        uint256 ticketId = 1; // Simulated
        console.log("Simulated breeding ticket creation");
        
        // Vote for mixed traits
        vm.startPrank(voter);
        
        AminalBreedingVote.GeneType[] memory geneTypes = new AminalBreedingVote.GeneType[](4);
        bool[] memory votes = new bool[](4);
        
        // Vote for dragon back and tail, bunny ears and face
        geneTypes[0] = AminalBreedingVote.GeneType.BACK;
        geneTypes[1] = AminalBreedingVote.GeneType.TAIL;
        geneTypes[2] = AminalBreedingVote.GeneType.EARS;
        geneTypes[3] = AminalBreedingVote.GeneType.FACE;
        
        votes[0] = true;  // Dragon back
        votes[1] = true;  // Dragon tail
        votes[2] = false; // Bunny ears
        votes[3] = false; // Bunny face
        
        // In real flow: breedingVote.vote(ticketId, traits, votes);
        console.log("Would vote on breeding ticket");
        
        vm.stopPrank();
        
        console.log("Cast votes");
        
        // Execute breeding
        vm.warp(block.timestamp + 2 hours);
        
        // In real flow: address child = breedingVote.executeBreeding(ticketId);
        console.log("Would execute breeding after voting period");
        
        console.log("\nChild would be created with traits based on voting results");
    }
}