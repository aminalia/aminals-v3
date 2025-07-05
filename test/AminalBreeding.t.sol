// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {AminalFactory} from "src/AminalFactory.sol";
import {Aminal} from "src/Aminal.sol";
import {ITraits} from "src/interfaces/ITraits.sol";

contract AminalBreedingTest is Test {
    AminalFactory public factory;
    address public owner;
    address public user1;
    address public user2;
    
    Aminal public parent1;
    Aminal public parent2;
    
    string constant BASE_URI = "https://api.aminals.com/metadata/";
    
    event AminalsBred(
        address indexed parent1,
        address indexed parent2,
        address indexed child,
        uint256 childId
    );
    
    function setUp() public {
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        
        vm.prank(owner);
        factory = new AminalFactory(owner, BASE_URI);
        
        // Create two parent Aminals
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
        
        vm.prank(user1);
        address parent1Address = factory.createAminal(
            "FireDragon",
            "FIRE",
            "A fierce dragon",
            "dragon.json",
            traits1
        );
        parent1 = Aminal(payable(parent1Address));
        
        vm.prank(user2);
        address parent2Address = factory.createAminal(
            "AngelBunny",
            "ANGEL",
            "A gentle bunny",
            "bunny.json",
            traits2
        );
        parent2 = Aminal(payable(parent2Address));
    }
    
    function test_SuccessfulBreeding() public {
        // Parent1 initiates breeding with Parent2
        vm.prank(address(parent1));
        
        vm.expectEmit(true, true, false, true);
        emit AminalsBred(address(parent1), address(parent2), address(0), 3);
        
        address childAddress = factory.breed(
            address(parent2),
            "A magical hybrid creature",
            "hybrid.json"
        );
        
        // Verify child was created
        assertTrue(childAddress != address(0));
        assertTrue(factory.isValidAminal(childAddress));
        assertEq(factory.totalAminals(), 3);
        
        // Verify child traits alternate between parents
        Aminal child = Aminal(payable(childAddress));
        ITraits.Traits memory childTraits = child.getTraits();
        ITraits.Traits memory parent1Traits = parent1.getTraits();
        ITraits.Traits memory parent2Traits = parent2.getTraits();
        
        // Check alternating pattern
        assertEq(childTraits.back, parent1Traits.back);   // From parent1
        assertEq(childTraits.arm, parent2Traits.arm);     // From parent2
        assertEq(childTraits.tail, parent1Traits.tail);   // From parent1
        assertEq(childTraits.ears, parent2Traits.ears);   // From parent2
        assertEq(childTraits.body, parent1Traits.body);   // From parent1
        assertEq(childTraits.face, parent2Traits.face);   // From parent2
        assertEq(childTraits.mouth, parent1Traits.mouth); // From parent1
        assertEq(childTraits.misc, parent2Traits.misc);   // From parent2
        
        // Check child name and symbol
        assertEq(child.name(), "FireDragon-AngelBunny-Child");
        assertEq(child.symbol(), "FIREANGEL");
        
        // Child should own itself
        assertEq(child.ownerOf(1), childAddress);
    }
    
    function test_BreedingInReverseOrder() public {
        // Parent2 initiates breeding with Parent1 (reverse order)
        vm.prank(address(parent2));
        address childAddress = factory.breed(
            address(parent1),
            "A mystical creature",
            "mystical.json"
        );
        
        // Verify traits still follow the pattern based on who initiated
        Aminal child = Aminal(payable(childAddress));
        ITraits.Traits memory childTraits = child.getTraits();
        ITraits.Traits memory initiatorTraits = parent2.getTraits();
        ITraits.Traits memory partnerTraits = parent1.getTraits();
        
        // When parent2 initiates, parent2 is "parent1" in the function
        assertEq(childTraits.back, initiatorTraits.back);   // From initiator (parent2)
        assertEq(childTraits.arm, partnerTraits.arm);       // From partner (parent1)
        assertEq(childTraits.tail, initiatorTraits.tail);   // From initiator
        assertEq(childTraits.ears, partnerTraits.ears);     // From partner
        
        // Check name reflects order
        assertEq(child.name(), "AngelBunny-FireDragon-Child");
        assertEq(child.symbol(), "ANGELFIRE");
    }
    
    function test_RevertWhen_NonAminalTriesToBreed() public {
        vm.prank(user1); // Regular user, not an Aminal
        vm.expectRevert(AminalFactory.OnlyAminalsCanBreed.selector);
        factory.breed(address(parent2), "Impossible child", "impossible.json");
    }
    
    function test_RevertWhen_BreedingWithNonAminal() public {
        vm.prank(address(parent1));
        vm.expectRevert(AminalFactory.InvalidBreedingPartner.selector);
        factory.breed(user1, "Invalid breeding", "invalid.json");
    }
    
    function test_RevertWhen_BreedingWithSelf() public {
        vm.prank(address(parent1));
        vm.expectRevert(AminalFactory.CannotBreedWithSelf.selector);
        factory.breed(address(parent1), "Self breeding", "self.json");
    }
    
    function test_RevertWhen_BreedingWhilePaused() public {
        vm.prank(owner);
        factory.setPaused(true);
        
        vm.prank(address(parent1));
        vm.expectRevert(AminalFactory.FactoryIsPaused.selector);
        factory.breed(address(parent2), "Paused breeding", "paused.json");
    }
    
    function test_ChildCanAlsoBreed() public {
        // First breeding
        vm.prank(address(parent1));
        address childAddress = factory.breed(
            address(parent2),
            "First generation child",
            "gen1.json"
        );
        
        // Create a third Aminal to breed with the child
        ITraits.Traits memory traits3 = ITraits.Traits({
            back: "Butterfly Wings",
            arm: "Tiny Arms",
            tail: "Rainbow Tail",
            ears: "Fuzzy Ears",
            body: "Striped Body",
            face: "Happy Face",
            mouth: "Big Grin",
            misc: "Rainbow Aura"
        });
        
        vm.prank(user1);
        address parent3Address = factory.createAminal(
            "RainbowCat",
            "RAINBOW",
            "A colorful cat",
            "cat.json",
            traits3
        );
        
        // Child breeds with parent3
        vm.prank(childAddress);
        address grandchildAddress = factory.breed(
            parent3Address,
            "Second generation hybrid",
            "gen2.json"
        );
        
        // Verify grandchild was created
        assertTrue(factory.isValidAminal(grandchildAddress));
        
        Aminal grandchild = Aminal(payable(grandchildAddress));
        assertEq(grandchild.name(), "FireDragon-AngelBunny-Child-RainbowCat-Child");
    }
    
    function test_MultipleBreedingsFromSameParents() public {
        // First child
        vm.prank(address(parent1));
        address child1 = factory.breed(
            address(parent2),
            "First child",
            "child1.json"
        );
        
        // Second child with different metadata
        vm.prank(address(parent1));
        address child2 = factory.breed(
            address(parent2),
            "Second child",
            "child2.json"
        );
        
        // Children should be different contracts
        assertTrue(child1 != child2);
        
        // But have same traits since parents are the same
        ITraits.Traits memory child1Traits = Aminal(payable(child1)).getTraits();
        ITraits.Traits memory child2Traits = Aminal(payable(child2)).getTraits();
        
        assertEq(child1Traits.back, child2Traits.back);
        assertEq(child1Traits.arm, child2Traits.arm);
        assertEq(child1Traits.tail, child2Traits.tail);
        assertEq(child1Traits.ears, child2Traits.ears);
        assertEq(child1Traits.body, child2Traits.body);
        assertEq(child1Traits.face, child2Traits.face);
        assertEq(child1Traits.mouth, child2Traits.mouth);
        assertEq(child1Traits.misc, child2Traits.misc);
    }
    
    function testFuzz_BreedingWithDifferentMetadata(
        string memory description,
        string memory tokenURI
    ) public {
        vm.assume(bytes(description).length > 0);
        vm.assume(bytes(tokenURI).length > 0);
        
        vm.prank(address(parent1));
        address childAddress = factory.breed(
            address(parent2),
            description,
            tokenURI
        );
        
        assertTrue(factory.isValidAminal(childAddress));
    }
}