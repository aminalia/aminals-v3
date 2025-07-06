// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "lib/forge-std/src/Test.sol";
import {AminalFactory} from "src/AminalFactory.sol";
import {Aminal} from "src/Aminal.sol";
import {IGenes} from "src/interfaces/IGenes.sol";

contract AminalFactoryTest is Test {
    AminalFactory public factory;
    address public owner;
    address public user1;
    address public user2;
    event AminalFactoryCreated(
        address indexed aminalContract,
        address indexed creator,
        address indexed owner,
        string name,
        string symbol,
        string description,
        string tokenURI
    );
    event FactoryPaused(bool paused);

    function setUp() external {
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        
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
        
        vm.prank(owner);
        factory = new AminalFactory(owner, firstParentData, secondParentData);
    }

    function createSampleTraits(string memory variant) internal pure returns (IGenes.Genes memory) {
        return IGenes.Genes({
            back: string(abi.encodePacked(variant, " Wings")),
            arm: string(abi.encodePacked(variant, " Arms")),
            tail: string(abi.encodePacked(variant, " Tail")),
            ears: string(abi.encodePacked(variant, " Ears")),
            body: string(abi.encodePacked(variant, " Body")),
            face: string(abi.encodePacked(variant, " Face")),
            mouth: string(abi.encodePacked(variant, " Mouth")),
            misc: string(abi.encodePacked(variant, " Misc"))
        });
    }

    function test_Constructor() external {
        assertEq(factory.owner(), owner);
        assertEq(factory.totalAminals(), 2); // Adam and Eve are created
        assertFalse(factory.paused());
    }

    function test_RevertWhen_ConstructorWithZeroAddress() external {
        AminalFactory.ParentData memory firstParentData = AminalFactory.ParentData({
            name: "Test",
            symbol: "TEST",
            description: "Test",
            tokenURI: "test",
            genes: createSampleTraits("Test")
        });
        
        AminalFactory.ParentData memory secondParentData = AminalFactory.ParentData({
            name: "Test2",
            symbol: "TEST2",
            description: "Test2",
            tokenURI: "test2",
            genes: createSampleTraits("Test2")
        });
        
        vm.expectRevert();
        new AminalFactory(address(0), firstParentData, secondParentData);
    }

    function test_CreateAminal() external {
        string memory name = "Fire Dragon";
        string memory symbol = "FDRAGON";
        string memory description = "A fierce dragon with fire breath";
        string memory tokenURI = "firedragon.json";
        IGenes.Genes memory traits = createSampleTraits("Fire");
        
        vm.prank(owner);
        address aminalContract = factory.createAminalWithGenes(name, symbol, description, tokenURI, traits);
        
        assertTrue(aminalContract != address(0));
        assertEq(factory.totalAminals(), 3); // 2 initial + 1 new
        assertTrue(factory.checkAminalExists(name, symbol, description, tokenURI));
        
        address[] memory createdContracts = factory.getCreatedByAddress(owner);
        assertEq(createdContracts.length, 3); // Adam, Eve, and the new Dragon
        assertEq(createdContracts[2], aminalContract); // Dragon is the 3rd
        
        // Verify the Aminal contract was properly initialized (self-owned)
        Aminal aminal = Aminal(payable(aminalContract));
        assertEq(aminal.name(), name);
        assertEq(aminal.symbol(), symbol);
        assertEq(aminal.ownerOf(1), aminalContract); // Aminal owns itself!
        assertTrue(aminal.isMinted());
        assertTrue(aminal.initialized());
        assertEq(aminal.totalSupply(), 1);
    }

    function test_CreateAminalWithZeroAddress() external {
        // Zero address is now acceptable since Aminals always own themselves
        vm.prank(user1);
        address aminalContract = factory.createAminalWithGenes("Dragon", "DRAGON", "A dragon", "dragon.json", createSampleTraits("Dragon"));
        
        Aminal aminal = Aminal(payable(aminalContract));
        assertEq(aminal.ownerOf(1), aminalContract); // Aminal owns itself
    }

    function test_RevertWhen_CreateAminalWithEmptyName() external {
        vm.prank(owner);
        vm.expectRevert(AminalFactory.InvalidParameters.selector);
        factory.createAminalWithGenes("", "DRAGON", "A dragon", "dragon.json", createSampleTraits("Dragon"));
    }

    function test_RevertWhen_CreateAminalWithEmptySymbol() external {
        vm.prank(owner);
        vm.expectRevert(AminalFactory.InvalidParameters.selector);
        factory.createAminalWithGenes("Dragon", "", "A dragon", "dragon.json", createSampleTraits("Dragon"));
    }

    function test_RevertWhen_CreateAminalWithEmptyTokenURI() external {
        vm.prank(owner);
        vm.expectRevert(AminalFactory.InvalidParameters.selector);
        factory.createAminalWithGenes("Dragon", "DRAGON", "A dragon", "", createSampleTraits("Dragon"));
    }

    function test_CreateAminalCalledByNonOwner() external {
        // Now anyone can create Aminals, not just the owner
        vm.prank(user1);
        address aminalContract = factory.createAminalWithGenes("Dragon", "DRAGON", "A dragon", "dragon.json", createSampleTraits("Dragon"));
        
        assertTrue(aminalContract != address(0));
        assertEq(factory.totalAminals(), 3); // 2 initial + 1 new
    }

    function test_RevertWhen_CreateDuplicateAminal() external {
        string memory name = "Fire Dragon";
        string memory symbol = "FDRAGON";
        string memory description = "A fierce dragon";
        string memory tokenURI = "firedragon.json";
        
        vm.startPrank(owner);
        factory.createAminalWithGenes(name, symbol, description, tokenURI, createSampleTraits("Fire"));
        
        bytes32 identifier = keccak256(abi.encodePacked(name, symbol, description, tokenURI));
        vm.expectRevert(abi.encodeWithSelector(AminalFactory.AminalAlreadyExists.selector, identifier));
        factory.createAminalWithGenes(name, symbol, description, tokenURI, createSampleTraits("Fire"));
        vm.stopPrank();
    }
    function test_SetPaused() external {
        assertFalse(factory.paused());
        
        vm.prank(owner);
        vm.expectEmit(false, false, false, true);
        emit FactoryPaused(true);
        factory.setPaused(true);
        
        assertTrue(factory.paused());
        
        vm.prank(owner);
        vm.expectEmit(false, false, false, true);
        emit FactoryPaused(false);
        factory.setPaused(false);
        
        assertFalse(factory.paused());
    }

    function test_RevertWhen_SetPausedCalledByNonOwner() external {
        vm.prank(user1);
        vm.expectRevert();
        factory.setPaused(true);
    }

    function test_RevertWhen_CreateAminalWhilePaused() external {
        vm.prank(owner);
        factory.setPaused(true);
        
        vm.prank(owner);
        vm.expectRevert(AminalFactory.FactoryIsPaused.selector);
        factory.createAminalWithGenes("Dragon", "DRAGON", "A dragon", "dragon.json", createSampleTraits("Dragon"));
    }


    function test_MultipleCreators() external {
        // Create first Aminal
        vm.prank(owner);
        address aminalContract1 = factory.createAminalWithGenes("Dragon", "DRAGON", "A dragon", "dragon.json", createSampleTraits("Dragon"));
        
        // Transfer ownership to user1
        vm.prank(owner);
        factory.transferOwnership(user1);
        
        // Create second Aminal with new owner
        vm.prank(user1);
        address aminalContract2 = factory.createAminalWithGenes("Phoenix", "PHOENIX", "A phoenix", "phoenix.json", createSampleTraits("Phoenix"));
        
        address[] memory createdByOwner = factory.getCreatedByAddress(owner);
        address[] memory createdByUser1 = factory.getCreatedByAddress(user1);
        
        assertEq(createdByOwner.length, 3); // Adam, Eve, and Dragon
        assertEq(createdByOwner[2], aminalContract1); // Dragon is the 3rd
        assertEq(createdByUser1.length, 1);
        assertEq(createdByUser1[0], aminalContract2);
        assertEq(factory.totalAminals(), 4); // 2 initial + 2 new
    }

    function test_GetAminalsByRange() external {
        vm.startPrank(owner);
        address aminal1 = factory.createAminalWithGenes("Dragon", "DRAGON", "A dragon", "dragon.json", createSampleTraits("Dragon"));
        address aminal2 = factory.createAminalWithGenes("Phoenix", "PHOENIX", "A phoenix", "phoenix.json", createSampleTraits("Phoenix"));
        vm.stopPrank();
        
        address[] memory aminals = factory.getAminalsByRange(3, 4); // Skip Adam and Eve
        assertEq(aminals.length, 2);
        assertEq(aminals[0], aminal1);
        assertEq(aminals[1], aminal2);
        
        // Test getting individual Aminals via public mapping
        assertEq(factory.aminalById(3), aminal1); // 1,2 are Adam and Eve
        assertEq(factory.aminalById(4), aminal2);
        
        // Test single item range
        address[] memory singleAminal = factory.getAminalsByRange(3, 3);
        assertEq(singleAminal.length, 1);
        assertEq(singleAminal[0], aminal1);
    }

    function test_PublicVariableAccess() external {
        // Test direct access to public variables
        assertEq(factory.totalAminals(), 2); // Adam and Eve
        assertFalse(factory.paused());
        
        vm.startPrank(owner);
        address aminal1 = factory.createAminalWithGenes("Dragon", "DRAGON", "A dragon", "dragon.json", createSampleTraits("Dragon"));
        vm.stopPrank();
        
        // Verify public variables updated
        assertEq(factory.totalAminals(), 3); // 2 initial + 1 new
        assertEq(factory.aminalById(3), aminal1); // 1,2 are Adam and Eve
        
        // Test aminalExists mapping
        bytes32 identifier = keccak256(abi.encodePacked("Dragon", "DRAGON", "A dragon", "dragon.json"));
        assertTrue(factory.aminalExists(identifier));
        
        // Test createdByAddress mapping via array access
        address[] memory ownerCreated = factory.getCreatedByAddress(owner);
        assertEq(ownerCreated.length, 3); // Adam, Eve, and Dragon
        assertEq(ownerCreated[2], aminal1); // Dragon is the 3rd one created by owner
    }

    function test_RevertWhen_GetAminalsByRangeInvalidParams() external {
        vm.startPrank(owner);
        factory.createAminalWithGenes("Dragon", "DRAGON", "A dragon", "dragon.json", createSampleTraits("Dragon"));
        vm.stopPrank();
        
        // Test invalid start ID (0)
        vm.expectRevert(AminalFactory.InvalidParameters.selector);
        factory.getAminalsByRange(0, 1);
        
        // Test start > total
        vm.expectRevert(AminalFactory.InvalidParameters.selector);
        factory.getAminalsByRange(4, 4); // Only 3 total (2 initial + 1 created)
        
        // Test end < start
        vm.expectRevert(AminalFactory.InvalidParameters.selector);
        factory.getAminalsByRange(2, 1);
    }

    function testFuzz_CreateAminal(
        string memory name,
        string memory symbol,
        string memory description,
        string memory tokenURI
    ) external {
        vm.assume(bytes(name).length > 0);
        vm.assume(bytes(symbol).length > 0);
        vm.assume(bytes(tokenURI).length > 0);
        
        vm.prank(owner);
        address aminalContract = factory.createAminalWithGenes(name, symbol, description, tokenURI, createSampleTraits("Fuzz"));
        
        Aminal aminal = Aminal(payable(aminalContract));
        assertEq(aminal.ownerOf(1), aminalContract); // Self-owned
        assertTrue(factory.checkAminalExists(name, symbol, description, tokenURI));
        assertEq(factory.totalAminals(), 3); // 2 initial + 1 new
    }

    function testFuzz_DuplicateCreationReverts(
        string memory name,
        string memory symbol,
        string memory description,
        string memory tokenURI
    ) external {
        vm.assume(bytes(name).length > 0);
        vm.assume(bytes(symbol).length > 0);
        vm.assume(bytes(tokenURI).length > 0);
        
        vm.startPrank(owner);
        factory.createAminalWithGenes(name, symbol, description, tokenURI, createSampleTraits("Fuzz1"));
        
        bytes32 identifier = keccak256(abi.encodePacked(name, symbol, description, tokenURI));
        vm.expectRevert(abi.encodeWithSelector(AminalFactory.AminalAlreadyExists.selector, identifier));
        factory.createAminalWithGenes(name, symbol, description, tokenURI, createSampleTraits("Fuzz2"));
        vm.stopPrank();
    }
}