// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {BreedingSkill} from "src/skills/BreedingSkill.sol";
import {AminalFactory} from "src/AminalFactory.sol";
import {Aminal} from "src/Aminal.sol";
import {ITraits} from "src/interfaces/ITraits.sol";

contract BreedingSkillTest is Test {
    BreedingSkill public breedingSkill;
    AminalFactory public factory;
    
    Aminal public parent1;
    Aminal public parent2;
    Aminal public parent3;
    
    address public owner;
    address public user1;
    address public user2;
    
    string constant BASE_URI = "https://api.aminals.com/metadata/";
    uint256 constant BREEDING_COST = 2500;
    
    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        address indexed target,
        string childDescription,
        string childTokenURI
    );
    
    event ProposalAccepted(
        uint256 indexed proposalId,
        address indexed acceptor,
        address indexed childContract
    );
    
    
    function setUp() public {
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        
        // Create parent data for Adam and Eve
        AminalFactory.ParentData memory firstParentData = AminalFactory.ParentData({
            name: "Adam",
            symbol: "ADAM",
            description: "The first Aminal",
            tokenURI: "ipfs://adam",
            traits: ITraits.Traits({
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
            traits: ITraits.Traits({
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
        
        // Deploy breeding skill
        breedingSkill = new BreedingSkill(address(factory));
        
        // Create test Aminals
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
        
        ITraits.Traits memory traits3 = ITraits.Traits({
            back: "Butterfly Wings",
            arm: "Delicate Arms",
            tail: "Ribbon Tail",
            ears: "Fairy Ears",
            body: "Ethereal Body",
            face: "Mystical Face",
            mouth: "Gentle Smile",
            misc: "Stardust"
        });
        
        vm.prank(owner);
        address parent1Address = factory.createAminalWithTraits(
            "FireDragon",
            "FIRE",
            "A fierce dragon",
            "dragon.json",
            traits1
        );
        parent1 = Aminal(payable(parent1Address));
        
        vm.prank(owner);
        address parent2Address = factory.createAminalWithTraits(
            "AngelBunny",
            "ANGEL",
            "A gentle bunny",
            "bunny.json",
            traits2
        );
        parent2 = Aminal(payable(parent2Address));
        
        vm.prank(owner);
        address parent3Address = factory.createAminalWithTraits(
            "FairyButterfly",
            "FAIRY",
            "A mystical butterfly",
            "butterfly.json",
            traits3
        );
        parent3 = Aminal(payable(parent3Address));
        
        // Give users ETH to feed Aminals
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
    }
    
    function test_CreateProposal() public {
        // User1 feeds parent1 to get love and energy
        vm.prank(user1);
        (bool success,) = address(parent1).call{value: 0.5 ether}("");
        assertTrue(success);
        
        uint256 initialEnergy = parent1.getEnergy();
        uint256 initialLove = parent1.loveFromUser(user1);
        
        assertGe(initialEnergy, BREEDING_COST);
        assertGe(initialLove, BREEDING_COST);
        
        // Create proposal from parent1 to parent2
        bytes memory proposalData = abi.encodeWithSelector(
            BreedingSkill.createProposal.selector,
            address(parent2),
            "A magical hybrid",
            "hybrid.json"
        );
        
        vm.expectEmit(true, true, true, false);
        emit ProposalCreated(1, address(parent1), address(parent2), "A magical hybrid", "hybrid.json");
        
        vm.prank(user1);
        parent1.useSkill(address(breedingSkill), proposalData);
        
        // Verify resources were consumed
        assertEq(parent1.getEnergy(), initialEnergy - BREEDING_COST);
        assertEq(parent1.loveFromUser(user1), initialLove - BREEDING_COST);
        
        // Verify proposal was created
        (
            address proposer,
            address target,
            string memory desc,
            string memory uri,
            uint256 timestamp,
            bool executed
        ) = breedingSkill.proposals(1);
        
        assertEq(proposer, address(parent1));
        assertEq(target, address(parent2));
        assertEq(desc, "A magical hybrid");
        assertEq(uri, "hybrid.json");
        assertEq(timestamp, block.timestamp);
        assertFalse(executed);
        
        // Check active proposal
        (bool hasActive, uint256 proposalId) = breedingSkill.hasActiveProposal(address(parent1), address(parent2));
        assertTrue(hasActive);
        assertEq(proposalId, 1);
    }
    
    function test_AcceptProposal() public {
        // Setup: User1 feeds parent1 and creates proposal
        vm.prank(user1);
        (bool success,) = address(parent1).call{value: 0.5 ether}("");
        assertTrue(success);
        
        bytes memory proposalData = abi.encodeWithSelector(
            BreedingSkill.createProposal.selector,
            address(parent2),
            "A magical hybrid",
            "hybrid.json"
        );
        
        vm.prank(user1);
        parent1.useSkill(address(breedingSkill), proposalData);
        
        // User2 feeds parent2 to get love and energy
        vm.prank(user2);
        (success,) = address(parent2).call{value: 0.5 ether}("");
        assertTrue(success);
        
        uint256 initialEnergy2 = parent2.getEnergy();
        uint256 initialLove2 = parent2.loveFromUser(user2);
        
        // Accept proposal from parent2
        bytes memory acceptData = abi.encodeWithSelector(
            BreedingSkill.acceptProposal.selector,
            uint256(1)
        );
        
        vm.expectEmit(true, true, false, false);
        emit ProposalAccepted(1, address(parent2), address(0)); // We don't know child address yet
        
        vm.prank(user2);
        parent2.useSkill(address(breedingSkill), acceptData);
        
        // Verify resources were consumed
        assertEq(parent2.getEnergy(), initialEnergy2 - BREEDING_COST);
        assertEq(parent2.loveFromUser(user2), initialLove2 - BREEDING_COST);
        
        // Verify proposal was executed
        (,,,,,bool executed) = breedingSkill.proposals(1);
        assertTrue(executed);
        
        // Verify child was created
        assertEq(factory.totalAminals(), 6); // 2 initial + 3 test + 1 child
        
        // Check no active proposal remains
        (bool hasActive,) = breedingSkill.hasActiveProposal(address(parent1), address(parent2));
        assertFalse(hasActive);
    }
    
    function test_MultipleUsersCanPropose() public {
        // User1 feeds parent1 with plenty for multiple proposals
        vm.prank(user1);
        (bool success,) = address(parent1).call{value: 1 ether}("");
        assertTrue(success);
        
        // User2 feeds parent1 with much less to ensure they don't have enough love
        vm.prank(user2);
        (success,) = address(parent1).call{value: 0.001 ether}("");  // Much smaller amount for less love
        assertTrue(success);
        
        // User1 has enough, user2 doesn't
        assertGe(parent1.loveFromUser(user1), BREEDING_COST);
        assertLt(parent1.loveFromUser(user2), BREEDING_COST);
        
        // User1 can create proposal
        bytes memory proposalData = abi.encodeWithSelector(
            BreedingSkill.createProposal.selector,
            address(parent2),
            "User1's proposal",
            "user1.json"
        );
        
        vm.prank(user1);
        parent1.useSkill(address(breedingSkill), proposalData);
        
        // User2 cannot create proposal (insufficient love, even though energy might be sufficient)
        vm.prank(user2);
        vm.expectRevert(Aminal.InsufficientLove.selector);
        parent1.useSkill(address(breedingSkill), proposalData);
    }
    
    
    function test_RevertWhen_ProposeToSelf() public {
        // User1 feeds parent1
        vm.prank(user1);
        (bool success,) = address(parent1).call{value: 0.5 ether}("");
        assertTrue(success);
        
        // Try to propose to self
        bytes memory proposalData = abi.encodeWithSelector(
            BreedingSkill.createProposal.selector,
            address(parent1), // Same as proposer
            "Self breeding",
            "self.json"
        );
        
        vm.prank(user1);
        vm.expectRevert(Aminal.SkillCallFailed.selector); // Skill reverts are wrapped
        parent1.useSkill(address(breedingSkill), proposalData);
    }
    
    function test_RevertWhen_ActiveProposalExists() public {
        // Setup: Create first proposal
        vm.prank(user1);
        (bool success,) = address(parent1).call{value: 1 ether}("");
        assertTrue(success);
        
        bytes memory proposalData = abi.encodeWithSelector(
            BreedingSkill.createProposal.selector,
            address(parent2),
            "First proposal",
            "first.json"
        );
        
        vm.prank(user1);
        parent1.useSkill(address(breedingSkill), proposalData);
        
        // Try to create another proposal to same target while first is still active
        proposalData = abi.encodeWithSelector(
            BreedingSkill.createProposal.selector,
            address(parent2),
            "Second proposal",
            "second.json"
        );
        
        vm.prank(user1);
        vm.expectRevert(Aminal.SkillCallFailed.selector); // ActiveProposalExists wrapped as SkillCallFailed
        parent1.useSkill(address(breedingSkill), proposalData);
    }
    
    function test_CanProposeToMultipleAminals() public {
        // User1 feeds parent1 with enough for multiple proposals
        vm.prank(user1);
        (bool success,) = address(parent1).call{value: 1 ether}("");
        assertTrue(success);
        
        // Create proposal to parent2
        bytes memory proposalData1 = abi.encodeWithSelector(
            BreedingSkill.createProposal.selector,
            address(parent2),
            "Proposal to parent2",
            "parent2.json"
        );
        
        vm.prank(user1);
        parent1.useSkill(address(breedingSkill), proposalData1);
        
        // Create proposal to parent3 (different target)
        bytes memory proposalData2 = abi.encodeWithSelector(
            BreedingSkill.createProposal.selector,
            address(parent3),
            "Proposal to parent3",
            "parent3.json"
        );
        
        vm.prank(user1);
        parent1.useSkill(address(breedingSkill), proposalData2);
        
        // Verify both proposals exist
        (bool hasActive1, uint256 id1) = breedingSkill.hasActiveProposal(address(parent1), address(parent2));
        (bool hasActive2, uint256 id2) = breedingSkill.hasActiveProposal(address(parent1), address(parent3));
        
        assertTrue(hasActive1);
        assertTrue(hasActive2);
        assertEq(id1, 1);
        assertEq(id2, 2);
    }
    
    function test_RevertWhen_ProposalExpired() public {
        // Setup: Create proposal
        vm.prank(user1);
        (bool success,) = address(parent1).call{value: 0.5 ether}("");
        assertTrue(success);
        
        bytes memory proposalData = abi.encodeWithSelector(
            BreedingSkill.createProposal.selector,
            address(parent2),
            "Expired proposal",
            "expired.json"
        );
        
        vm.prank(user1);
        parent1.useSkill(address(breedingSkill), proposalData);
        
        // Warp time past expiry (7 days + 1 second)
        vm.warp(block.timestamp + 7 days + 1);
        
        // User2 feeds parent2
        vm.prank(user2);
        (success,) = address(parent2).call{value: 0.5 ether}("");
        assertTrue(success);
        
        // Try to accept expired proposal
        bytes memory acceptData = abi.encodeWithSelector(
            BreedingSkill.acceptProposal.selector,
            uint256(1)
        );
        
        vm.prank(user2);
        vm.expectRevert(Aminal.SkillCallFailed.selector); // Skill reverts are wrapped
        parent2.useSkill(address(breedingSkill), acceptData);
    }
    
    function test_RevertWhen_WrongAminalAccepts() public {
        // Setup: Create proposal from parent1 to parent2
        vm.prank(user1);
        (bool success,) = address(parent1).call{value: 0.5 ether}("");
        assertTrue(success);
        
        bytes memory proposalData = abi.encodeWithSelector(
            BreedingSkill.createProposal.selector,
            address(parent2),
            "Proposal to parent2",
            "parent2.json"
        );
        
        vm.prank(user1);
        parent1.useSkill(address(breedingSkill), proposalData);
        
        // User1 also feeds parent3
        vm.prank(user1);
        (success,) = address(parent3).call{value: 0.5 ether}("");
        assertTrue(success);
        
        // Try to accept from wrong Aminal (parent3 instead of parent2)
        bytes memory acceptData = abi.encodeWithSelector(
            BreedingSkill.acceptProposal.selector,
            uint256(1)
        );
        
        vm.prank(user1);
        vm.expectRevert(Aminal.SkillCallFailed.selector); // Skill reverts are wrapped
        parent3.useSkill(address(breedingSkill), acceptData);
    }
    
    function test_CanProposeAfterExpiration() public {
        // Setup: Create first proposal
        vm.prank(user1);
        (bool success,) = address(parent1).call{value: 1 ether}("");
        assertTrue(success);
        
        bytes memory proposalData = abi.encodeWithSelector(
            BreedingSkill.createProposal.selector,
            address(parent2),
            "First proposal",
            "first.json"
        );
        
        vm.prank(user1);
        parent1.useSkill(address(breedingSkill), proposalData);
        
        // Warp past expiration
        vm.warp(block.timestamp + 7 days + 1);
        
        // Now can create new proposal to same target
        proposalData = abi.encodeWithSelector(
            BreedingSkill.createProposal.selector,
            address(parent2),
            "Second proposal after expiry",
            "second.json"
        );
        
        vm.prank(user1);
        parent1.useSkill(address(breedingSkill), proposalData);
        
        // Verify new proposal exists
        (bool hasActive, uint256 proposalId) = breedingSkill.hasActiveProposal(address(parent1), address(parent2));
        assertTrue(hasActive);
        assertEq(proposalId, 2); // Second proposal
    }
    
    function test_ChildTraitsAlternate() public {
        // Setup and create proposal
        vm.prank(user1);
        (bool success,) = address(parent1).call{value: 0.5 ether}("");
        assertTrue(success);
        
        bytes memory proposalData = abi.encodeWithSelector(
            BreedingSkill.createProposal.selector,
            address(parent2),
            "Test child",
            "child.json"
        );
        
        vm.prank(user1);
        parent1.useSkill(address(breedingSkill), proposalData);
        
        // Accept proposal
        vm.prank(user2);
        (success,) = address(parent2).call{value: 0.5 ether}("");
        assertTrue(success);
        
        bytes memory acceptData = abi.encodeWithSelector(
            BreedingSkill.acceptProposal.selector,
            uint256(1)
        );
        
        vm.prank(user2);
        parent2.useSkill(address(breedingSkill), acceptData);
        
        // Get the child
        address childAddress = factory.aminalById(6); // 2 initial + 3 test + 1 child
        Aminal child = Aminal(payable(childAddress));
        
        // Verify traits alternate
        ITraits.Traits memory childTraits = child.getTraits();
        ITraits.Traits memory traits1 = parent1.getTraits();
        ITraits.Traits memory traits2 = parent2.getTraits();
        
        assertEq(childTraits.back, traits1.back);   // From parent1
        assertEq(childTraits.arm, traits2.arm);     // From parent2
        assertEq(childTraits.tail, traits1.tail);   // From parent1
        assertEq(childTraits.ears, traits2.ears);   // From parent2
        assertEq(childTraits.body, traits1.body);   // From parent1
        assertEq(childTraits.face, traits2.face);   // From parent2
        assertEq(childTraits.mouth, traits1.mouth); // From parent1
        assertEq(childTraits.misc, traits2.misc);   // From parent2
        
        // Verify name
        assertEq(child.name(), "FireDragon-AngelBunny-Child");
        assertEq(child.symbol(), "FIREANGEL");
    }
}