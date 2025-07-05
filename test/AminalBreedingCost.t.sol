// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {Aminal} from "../src/Aminal.sol";
import {AminalFactory} from "../src/AminalFactory.sol";
import {AminalBreedingVote} from "../src/AminalBreedingVote.sol";
import {ITraits} from "../src/interfaces/ITraits.sol";

contract AminalBreedingCostTest is Test {
    AminalFactory factory;
    AminalBreedingVote breedingVote;
    Aminal parent1;
    Aminal parent2;
    
    address owner = makeAddr("owner");
    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");
    
    string constant BASE_URI = "https://api.aminals.com/";
    uint256 constant VOTING_DURATION = 7 days;
    
    function setUp() public {
        // Create parent data
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
        
        AminalFactory.ParentData memory parentData1 = AminalFactory.ParentData({
            name: "FireDragon",
            symbol: "FIRE",
            description: "A fierce dragon",
            tokenURI: "dragon.json",
            traits: traits1
        });
        
        AminalFactory.ParentData memory parentData2 = AminalFactory.ParentData({
            name: "AngelBunny",
            symbol: "ANGEL",
            description: "A gentle bunny",
            tokenURI: "bunny.json",
            traits: traits2
        });
        
        // Deploy contracts
        vm.prank(owner);
        factory = new AminalFactory(owner, BASE_URI, parentData1, parentData2);
        breedingVote = new AminalBreedingVote(address(factory));
        
        // Get parents
        parent1 = Aminal(payable(factory.firstParent()));
        parent2 = Aminal(payable(factory.secondParent()));
    }
    
    function test_BreedingCost() public {
        // Give user1 enough love in parent1
        vm.deal(user1, 10 ether);
        vm.prank(user1);
        (bool sent,) = address(parent1).call{value: 1 ether}("");
        require(sent);
        
        uint256 initialLove = parent1.loveFromUser(user1);
        uint256 initialEnergy = parent1.getEnergy();
        
        // Create breeding proposal
        vm.prank(user1);
        uint256 proposalId = breedingVote.createProposal(
            address(parent1),
            address(parent2),
            "Test hybrid",
            "hybrid.json",
            VOTING_DURATION
        );
        
        // Verify 5,000 love and energy were consumed
        assertEq(parent1.loveFromUser(user1), initialLove - 5000);
        assertEq(parent1.getEnergy(), initialEnergy - 5000);
        assertEq(proposalId, 0);
    }
    
    function test_BreedingCost_InsufficientLove() public {
        // user2 has no love in either parent
        vm.prank(user2);
        vm.expectRevert(AminalBreedingVote.InsufficientLoveAndEnergy.selector);
        breedingVote.createProposal(
            address(parent1),
            address(parent2),
            "Test hybrid",
            "hybrid.json",
            VOTING_DURATION
        );
    }
    
    function test_BreedingCost_UsesParent2() public {
        // Give user1 love only in parent2
        vm.deal(user1, 10 ether);
        vm.prank(user1);
        (bool sent,) = address(parent2).call{value: 1 ether}("");
        require(sent);
        
        uint256 initialLove = parent2.loveFromUser(user1);
        uint256 initialEnergy = parent2.getEnergy();
        
        // Create breeding proposal
        vm.prank(user1);
        uint256 proposalId = breedingVote.createProposal(
            address(parent1),
            address(parent2),
            "Test hybrid",
            "hybrid.json",
            VOTING_DURATION
        );
        
        // Verify 5,000 love and energy were consumed from parent2
        assertEq(parent2.loveFromUser(user1), initialLove - 5000);
        assertEq(parent2.getEnergy(), initialEnergy - 5000);
        assertEq(proposalId, 0);
    }
}