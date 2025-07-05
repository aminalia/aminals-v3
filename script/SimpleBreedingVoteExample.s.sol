// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {AminalFactory} from "src/AminalFactory.sol";
import {AminalBreedingVote} from "src/AminalBreedingVote.sol";
import {Aminal} from "src/Aminal.sol";
import {ITraits} from "src/interfaces/ITraits.sol";

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
        
        AminalFactory factory = new AminalFactory(deployer, "https://api.aminals.com/");
        AminalBreedingVote breedingVote = new AminalBreedingVote(address(factory));
        
        vm.stopPrank();
        
        console.log("Deployed contracts");
        
        // Create parents
        ITraits.Traits memory traits1 = ITraits.Traits({
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
        
        ITraits.Traits memory traits2 = ITraits.Traits({
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
        
        // Create proposal
        uint256 proposalId = breedingVote.createProposal(
            parent1,
            parent2,
            "Hybrid",
            "hybrid.json",
            1 hours
        );
        
        console.log("Created proposal");
        
        // Vote for mixed traits
        vm.startPrank(voter);
        
        AminalBreedingVote.TraitType[] memory traits = new AminalBreedingVote.TraitType[](4);
        bool[] memory votes = new bool[](4);
        
        // Vote for dragon back and tail, bunny ears and face
        traits[0] = AminalBreedingVote.TraitType.BACK;
        traits[1] = AminalBreedingVote.TraitType.TAIL;
        traits[2] = AminalBreedingVote.TraitType.EARS;
        traits[3] = AminalBreedingVote.TraitType.FACE;
        
        votes[0] = true;  // Dragon back
        votes[1] = true;  // Dragon tail
        votes[2] = false; // Bunny ears
        votes[3] = false; // Bunny face
        
        breedingVote.vote(proposalId, traits, votes);
        
        vm.stopPrank();
        
        console.log("Cast votes");
        
        // Execute breeding
        vm.warp(block.timestamp + 2 hours);
        
        address child = breedingVote.executeBreeding(proposalId);
        
        console.log("Child created at:", child);
        
        // Show result
        Aminal childAminal = Aminal(payable(child));
        ITraits.Traits memory childTraits = childAminal.getTraits();
        
        console.log("\nChild traits:");
        console.log("- Back:", childTraits.back);
        console.log("- Ears:", childTraits.ears);
        console.log("- Tail:", childTraits.tail);
        console.log("- Face:", childTraits.face);
    }
}