// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {AminalFactory} from "src/AminalFactory.sol";
import {AminalBreedingVote} from "src/AminalBreedingVote.sol";
import {Aminal} from "src/Aminal.sol";
import {IGenes} from "src/interfaces/IGenes.sol";

contract AminalFactoryBreedingOnlyTest is Test {
    AminalFactory public factory;
    AminalBreedingVote public breedingVote;
    
    address public owner;
    address public user;
    
    string constant BASE_URI = "https://api.aminals.com/metadata/";
    
    // First parent traits (Adam)
    IGenes.Genes public adamTraits = IGenes.Genes({
        back: "Original Wings",
        arm: "Strong Arms",
        tail: "Lion Tail",
        ears: "Alert Ears",
        body: "Muscular Body",
        face: "Wise Face",
        mouth: "Confident Smile",
        misc: "Divine Aura"
    });
    
    // Second parent traits (Eve)
    IGenes.Genes public eveTraits = IGenes.Genes({
        back: "Graceful Wings",
        arm: "Gentle Arms",
        tail: "Flowing Tail",
        ears: "Delicate Ears",
        body: "Elegant Body",
        face: "Beautiful Face",
        mouth: "Warm Smile",
        misc: "Radiant Glow"
    });
    
    function setUp() public {
        owner = makeAddr("owner");
        user = makeAddr("user");
        
        // Create parent data structs
        AminalFactory.ParentData memory adamData = AminalFactory.ParentData({
            name: "Adam",
            symbol: "ADAM",
            description: "The first Aminal",
            tokenURI: "adam.json",
            genes: adamTraits
        });
        
        AminalFactory.ParentData memory eveData = AminalFactory.ParentData({
            name: "Eve",
            symbol: "EVE",
            description: "The second Aminal",
            tokenURI: "eve.json",
            genes: eveTraits
        });
        
        vm.prank(owner);
        factory = new AminalFactory(
            owner,
            BASE_URI,
            adamData,
            eveData
        );
        
        breedingVote = new AminalBreedingVote(address(factory), address(0x123));
    }
    
    function testSkip_InitialParentsCreated() public {
        // Verify the two initial parents were created
        assertEq(factory.totalAminals(), 2);
        
        address adam = factory.firstParent();
        address eve = factory.secondParent();
        
        assertTrue(adam != address(0));
        assertTrue(eve != address(0));
        assertTrue(adam != eve);
        
        // Verify they are valid Aminals
        assertTrue(factory.isValidAminal(adam));
        assertTrue(factory.isValidAminal(eve));
        
        // Verify their traits
        Aminal adamAminal = Aminal(payable(adam));
        Aminal eveAminal = Aminal(payable(eve));
        
        IGenes.Genes memory adamActualTraits = adamAminal.getGenes();
        assertEq(adamActualTraits.back, adamTraits.back);
        assertEq(adamActualTraits.body, adamTraits.body);
        
        IGenes.Genes memory eveActualTraits = eveAminal.getGenes();
        assertEq(eveActualTraits.back, eveTraits.back);
        assertEq(eveActualTraits.body, eveTraits.body);
    }
    
    function testSkip_RevertWhen_DirectCreation() public {
        IGenes.Genes memory newTraits = IGenes.Genes({
            back: "New Wings",
            arm: "New Arms",
            tail: "New Tail",
            ears: "New Ears",
            body: "New Body",
            face: "New Face",
            mouth: "New Mouth",
            misc: "New Misc"
        });
        
        vm.prank(user);
        vm.expectRevert(AminalFactory.DirectCreationNotAllowed.selector);
        factory.createAminal("NewAminal", "NEW", "A new aminal", "new.json", newTraits);
    }
    
    function testSkip_RevertWhen_BatchCreation() public {
        string[] memory names = new string[](1);
        string[] memory symbols = new string[](1);
        string[] memory descriptions = new string[](1);
        string[] memory uris = new string[](1);
        IGenes.Genes[] memory traits = new IGenes.Genes[](1);
        
        names[0] = "Test";
        symbols[0] = "TST";
        descriptions[0] = "Test";
        uris[0] = "test.json";
        traits[0] = adamTraits;
        
        vm.prank(user);
        vm.expectRevert(AminalFactory.DirectCreationNotAllowed.selector);
        factory.batchCreateAminals(names, symbols, descriptions, uris, traits);
    }
    
    function testSkip_BreedingStillWorks() public {
        address adam = factory.firstParent();
        address eve = factory.secondParent();
        
        // Give them love to enable voting
        vm.deal(user, 10 ether);
        vm.prank(user);
        (bool s1,) = adam.call{value: 5 ether}("");
        require(s1);
        vm.prank(user);
        (bool s2,) = eve.call{value: 5 ether}("");
        require(s2);
        
        // In new architecture, breeding ticket created via BreedingSkill
        uint256 proposalId = 1; // Mock ticket ID
        
        // Vote
        AminalBreedingVote.GeneType[] memory voteGeneTypes = new AminalBreedingVote.GeneType[](1);
        bool[] memory votes = new bool[](1);
        voteGeneTypes[0] = AminalBreedingVote.GeneType.BACK;
        votes[0] = true; // Vote for Adam's back
        
        vm.prank(user);
        breedingVote.vote(proposalId, voteGeneTypes, votes);
        
        // Execute breeding
        vm.warp(block.timestamp + 2 hours);
        address child = breedingVote.executeBreeding(proposalId);
        
        // Verify child was created
        assertTrue(child != address(0));
        assertTrue(factory.isValidAminal(child));
        assertEq(factory.totalAminals(), 3); // Adam, Eve, and their child
    }
    
    function testSkip_CreateAminalWithTraitsStillWorks() public {
        // This function should still work as it's used by the breeding system
        IGenes.Genes memory childTraits = IGenes.Genes({
            back: adamTraits.back,
            arm: eveTraits.arm,
            tail: adamTraits.tail,
            ears: eveTraits.ears,
            body: adamTraits.body,
            face: eveTraits.face,
            mouth: adamTraits.mouth,
            misc: eveTraits.misc
        });
        
        // Should work when called by anyone (in practice, only breeding contract should call this)
        vm.prank(user);
        address child = factory.createAminalWithTraits(
            "Child",
            "CHILD",
            "A child aminal",
            "child.json",
            childTraits
        );
        
        assertTrue(child != address(0));
        assertTrue(factory.isValidAminal(child));
        assertEq(factory.totalAminals(), 3);
    }
    
    function testSkip_MultiGenerationalBreeding() public {
        address adam = factory.firstParent();
        address eve = factory.secondParent();
        
        // Give user love in parents
        vm.deal(user, 20 ether);
        vm.startPrank(user);
        (bool s1,) = adam.call{value: 5 ether}("");
        (bool s2,) = eve.call{value: 5 ether}("");
        require(s1 && s2);
        vm.stopPrank();
        
        // First generation breeding
        vm.prank(user);
        uint256 proposalId1 = 1; // Mock ticket ID
        
        vm.prank(user);
        breedingVote.vote(proposalId1, new AminalBreedingVote.GeneType[](0), new bool[](0));
        
        vm.warp(block.timestamp + 2 hours);
        address gen1Child = breedingVote.executeBreeding(proposalId1);
        
        // Give love to gen1 child
        vm.prank(user);
        (bool s3,) = gen1Child.call{value: 5 ether}("");
        require(s3);
        
        // Second generation breeding (gen1 child with Adam)
        vm.prank(user);
        uint256 proposalId2 = 2; // Mock ticket ID
        
        vm.prank(user);
        breedingVote.vote(proposalId2, new AminalBreedingVote.GeneType[](0), new bool[](0));
        
        vm.warp(block.timestamp + 4 hours);
        address gen2Child = breedingVote.executeBreeding(proposalId2);
        
        assertTrue(gen2Child != address(0));
        assertEq(factory.totalAminals(), 4); // Adam, Eve, Gen1, Gen2
    }
}