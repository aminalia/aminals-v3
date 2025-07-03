// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "lib/forge-std/src/Test.sol";
import {AminalFactory} from "src/AminalFactory.sol";
import {Aminal} from "src/Aminal.sol";

contract AminalFactoryTest is Test {
    AminalFactory public factory;
    address public owner;
    address public user1;
    address public user2;
    string public constant BASE_URI = "https://api.aminals.com/metadata/";

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
        
        vm.prank(owner);
        factory = new AminalFactory(owner, BASE_URI);
    }

    function createSampleTraits(string memory variant) internal pure returns (Aminal.Traits memory) {
        return Aminal.Traits({
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
        assertEq(factory.totalAminals(), 0);
        assertFalse(factory.paused());
        assertEq(factory.baseTokenURI(), BASE_URI);
    }

    function test_RevertWhen_ConstructorWithZeroAddress() external {
        vm.expectRevert();
        new AminalFactory(address(0), BASE_URI);
    }

    function test_CreateAminal() external {
        string memory name = "Fire Dragon";
        string memory symbol = "FDRAGON";
        string memory description = "A fierce dragon with fire breath";
        string memory tokenURI = "firedragon.json";
        Aminal.Traits memory traits = createSampleTraits("Fire");
        
        vm.prank(owner);
        address aminalContract = factory.createAminal(user1, name, symbol, description, tokenURI, traits);
        
        assertTrue(aminalContract != address(0));
        assertEq(factory.totalAminals(), 1);
        assertTrue(factory.checkAminalExists(name, symbol, description, tokenURI));
        
        address[] memory createdContracts = factory.getCreatedByAddress(owner);
        assertEq(createdContracts.length, 1);
        assertEq(createdContracts[0], aminalContract);
        
        // Verify the Aminal contract was properly minted
        Aminal aminal = Aminal(aminalContract);
        assertEq(aminal.name(), name);
        assertEq(aminal.symbol(), symbol);
        assertEq(aminal.ownerOf(1), user1);
        assertTrue(aminal.isMinted());
        assertEq(aminal.totalSupply(), 1);
    }

    function test_RevertWhen_CreateAminalWithZeroAddress() external {
        vm.prank(owner);
        vm.expectRevert(AminalFactory.InvalidParameters.selector);
        factory.createAminal(address(0), "Dragon", "DRAGON", "A dragon", "dragon.json", createSampleTraits("Dragon"));
    }

    function test_RevertWhen_CreateAminalWithEmptyName() external {
        vm.prank(owner);
        vm.expectRevert(AminalFactory.InvalidParameters.selector);
        factory.createAminal(user1, "", "DRAGON", "A dragon", "dragon.json", createSampleTraits("Dragon"));
    }

    function test_RevertWhen_CreateAminalWithEmptySymbol() external {
        vm.prank(owner);
        vm.expectRevert(AminalFactory.InvalidParameters.selector);
        factory.createAminal(user1, "Dragon", "", "A dragon", "dragon.json", createSampleTraits("Dragon"));
    }

    function test_RevertWhen_CreateAminalWithEmptyTokenURI() external {
        vm.prank(owner);
        vm.expectRevert(AminalFactory.InvalidParameters.selector);
        factory.createAminal(user1, "Dragon", "DRAGON", "A dragon", "", createSampleTraits("Dragon"));
    }

    function test_RevertWhen_CreateAminalCalledByNonOwner() external {
        vm.prank(user1);
        vm.expectRevert();
        factory.createAminal(user2, "Dragon", "DRAGON", "A dragon", "dragon.json", createSampleTraits("Dragon"));
    }

    function test_RevertWhen_CreateDuplicateAminal() external {
        string memory name = "Fire Dragon";
        string memory symbol = "FDRAGON";
        string memory description = "A fierce dragon";
        string memory tokenURI = "firedragon.json";
        
        vm.startPrank(owner);
        factory.createAminal(user1, name, symbol, description, tokenURI, createSampleTraits("Fire"));
        
        bytes32 identifier = keccak256(abi.encodePacked(name, symbol, description, tokenURI));
        vm.expectRevert(abi.encodeWithSelector(AminalFactory.AminalAlreadyExists.selector, identifier));
        factory.createAminal(user2, name, symbol, description, tokenURI, createSampleTraits("Fire"));
        vm.stopPrank();
    }

    function test_BatchCreateAminals() external {
        address[] memory recipients = new address[](3);
        recipients[0] = user1;
        recipients[1] = user2;
        recipients[2] = user1;
        
        string[] memory names = new string[](3);
        names[0] = "Fire Dragon";
        names[1] = "Ice Phoenix";
        names[2] = "Earth Golem";
        
        string[] memory symbols = new string[](3);
        symbols[0] = "FDRAGON";
        symbols[1] = "IPHOENIX";
        symbols[2] = "EGOLEM";
        
        string[] memory descriptions = new string[](3);
        descriptions[0] = "A fierce dragon";
        descriptions[1] = "A cold phoenix";
        descriptions[2] = "A sturdy golem";
        
        string[] memory tokenURIs = new string[](3);
        tokenURIs[0] = "firedragon.json";
        tokenURIs[1] = "icephoenix.json";
        tokenURIs[2] = "earthgolem.json";
        
        Aminal.Traits[] memory traitsArray = new Aminal.Traits[](3);
        traitsArray[0] = createSampleTraits("Fire");
        traitsArray[1] = createSampleTraits("Ice");
        traitsArray[2] = createSampleTraits("Earth");
        
        vm.prank(owner);
        address[] memory aminalContracts = factory.batchCreateAminals(recipients, names, symbols, descriptions, tokenURIs, traitsArray);
        
        assertEq(aminalContracts.length, 3);
        assertEq(factory.totalAminals(), 3);
        
        for (uint256 i = 0; i < aminalContracts.length; i++) {
            Aminal aminal = Aminal(aminalContracts[i]);
            assertEq(aminal.ownerOf(1), recipients[i]);
            assertEq(aminal.name(), names[i]);
            assertEq(aminal.symbol(), symbols[i]);
            assertTrue(aminal.isMinted());
            assertTrue(factory.checkAminalExists(names[i], symbols[i], descriptions[i], tokenURIs[i]));
        }
        
        // Check getAminalsByRange
        address[] memory allAminals = factory.getAminalsByRange(1, 3);
        assertEq(allAminals.length, 3);
        for (uint256 i = 0; i < 3; i++) {
            assertEq(allAminals[i], aminalContracts[i]);
        }
    }

    function test_RevertWhen_BatchCreateWithMismatchedArrays() external {
        address[] memory recipients = new address[](2);
        recipients[0] = user1;
        recipients[1] = user2;
        
        string[] memory names = new string[](3);
        names[0] = "Dragon";
        names[1] = "Phoenix";
        names[2] = "Golem";
        
        string[] memory symbols = new string[](2);
        symbols[0] = "DRAGON";
        symbols[1] = "PHOENIX";
        
        string[] memory descriptions = new string[](2);
        descriptions[0] = "A dragon";
        descriptions[1] = "A phoenix";
        
        string[] memory tokenURIs = new string[](2);
        tokenURIs[0] = "dragon.json";
        tokenURIs[1] = "phoenix.json";
        
        Aminal.Traits[] memory traitsArray = new Aminal.Traits[](2);
        traitsArray[0] = createSampleTraits("Dragon");
        traitsArray[1] = createSampleTraits("Phoenix");
        
        vm.prank(owner);
        vm.expectRevert(AminalFactory.InvalidParameters.selector);
        factory.batchCreateAminals(recipients, names, symbols, descriptions, tokenURIs, traitsArray);
    }

    function test_RevertWhen_BatchCreateWithEmptyArrays() external {
        address[] memory recipients = new address[](0);
        string[] memory names = new string[](0);
        string[] memory symbols = new string[](0);
        string[] memory descriptions = new string[](0);
        string[] memory tokenURIs = new string[](0);
        
        Aminal.Traits[] memory traitsArray = new Aminal.Traits[](0);
        
        vm.prank(owner);
        vm.expectRevert(AminalFactory.InvalidParameters.selector);
        factory.batchCreateAminals(recipients, names, symbols, descriptions, tokenURIs, traitsArray);
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
        factory.createAminal(user1, "Dragon", "DRAGON", "A dragon", "dragon.json", createSampleTraits("Dragon"));
    }

    function test_RevertWhen_BatchCreateWhilePaused() external {
        vm.prank(owner);
        factory.setPaused(true);
        
        address[] memory recipients = new address[](1);
        recipients[0] = user1;
        string[] memory names = new string[](1);
        names[0] = "Dragon";
        string[] memory symbols = new string[](1);
        symbols[0] = "DRAGON";
        string[] memory descriptions = new string[](1);
        descriptions[0] = "A dragon";
        string[] memory tokenURIs = new string[](1);
        tokenURIs[0] = "dragon.json";
        
        Aminal.Traits[] memory traitsArray = new Aminal.Traits[](1);
        traitsArray[0] = createSampleTraits("Dragon");
        
        vm.prank(owner);
        vm.expectRevert(AminalFactory.FactoryIsPaused.selector);
        factory.batchCreateAminals(recipients, names, symbols, descriptions, tokenURIs, traitsArray);
    }

    function test_SetBaseURI() external {
        string memory newBaseURI = "https://newapi.aminals.com/metadata/";
        
        vm.prank(owner);
        factory.setBaseURI(newBaseURI);
        
        assertEq(factory.baseTokenURI(), newBaseURI);
        
        vm.prank(owner);
        address aminalContract = factory.createAminal(user1, "Dragon", "DRAGON", "A dragon", "dragon.json", createSampleTraits("Dragon"));
        
        Aminal aminal = Aminal(aminalContract);
        assertEq(aminal.tokenURI(1), string(abi.encodePacked(newBaseURI, "dragon.json")));
    }

    function test_RevertWhen_SetBaseURICalledByNonOwner() external {
        vm.prank(user1);
        vm.expectRevert();
        factory.setBaseURI("https://newapi.aminals.com/metadata/");
    }

    function test_MultipleCreators() external {
        // Create first Aminal
        vm.prank(owner);
        address aminalContract1 = factory.createAminal(user1, "Dragon", "DRAGON", "A dragon", "dragon.json", createSampleTraits("Dragon"));
        
        // Transfer ownership to user1
        vm.prank(owner);
        factory.transferOwnership(user1);
        
        // Create second Aminal with new owner
        vm.prank(user1);
        address aminalContract2 = factory.createAminal(user2, "Phoenix", "PHOENIX", "A phoenix", "phoenix.json", createSampleTraits("Phoenix"));
        
        address[] memory createdByOwner = factory.getCreatedByAddress(owner);
        address[] memory createdByUser1 = factory.getCreatedByAddress(user1);
        
        assertEq(createdByOwner.length, 1);
        assertEq(createdByOwner[0], aminalContract1);
        assertEq(createdByUser1.length, 1);
        assertEq(createdByUser1[0], aminalContract2);
        assertEq(factory.totalAminals(), 2);
    }

    function test_GetAminalsByRange() external {
        vm.startPrank(owner);
        address aminal1 = factory.createAminal(user1, "Dragon", "DRAGON", "A dragon", "dragon.json", createSampleTraits("Dragon"));
        address aminal2 = factory.createAminal(user2, "Phoenix", "PHOENIX", "A phoenix", "phoenix.json", createSampleTraits("Phoenix"));
        vm.stopPrank();
        
        address[] memory aminals = factory.getAminalsByRange(1, 2);
        assertEq(aminals.length, 2);
        assertEq(aminals[0], aminal1);
        assertEq(aminals[1], aminal2);
        
        // Test getting individual Aminals via public mapping
        assertEq(factory.aminalById(1), aminal1);
        assertEq(factory.aminalById(2), aminal2);
        
        // Test single item range
        address[] memory singleAminal = factory.getAminalsByRange(1, 1);
        assertEq(singleAminal.length, 1);
        assertEq(singleAminal[0], aminal1);
    }

    function test_PublicVariableAccess() external {
        // Test direct access to public variables
        assertEq(factory.totalAminals(), 0);
        assertFalse(factory.paused());
        assertEq(factory.baseTokenURI(), BASE_URI);
        
        vm.startPrank(owner);
        address aminal1 = factory.createAminal(user1, "Dragon", "DRAGON", "A dragon", "dragon.json", createSampleTraits("Dragon"));
        vm.stopPrank();
        
        // Verify public variables updated
        assertEq(factory.totalAminals(), 1);
        assertEq(factory.aminalById(1), aminal1);
        
        // Test aminalExists mapping
        bytes32 identifier = keccak256(abi.encodePacked("Dragon", "DRAGON", "A dragon", "dragon.json"));
        assertTrue(factory.aminalExists(identifier));
        
        // Test createdByAddress mapping via array access
        address[] memory ownerCreated = factory.getCreatedByAddress(owner);
        assertEq(ownerCreated[0], aminal1);
    }

    function test_RevertWhen_GetAminalsByRangeInvalidParams() external {
        vm.startPrank(owner);
        factory.createAminal(user1, "Dragon", "DRAGON", "A dragon", "dragon.json", createSampleTraits("Dragon"));
        vm.stopPrank();
        
        // Test invalid start ID (0)
        vm.expectRevert(AminalFactory.InvalidParameters.selector);
        factory.getAminalsByRange(0, 1);
        
        // Test start > total
        vm.expectRevert(AminalFactory.InvalidParameters.selector);
        factory.getAminalsByRange(2, 2);
        
        // Test end < start
        vm.expectRevert(AminalFactory.InvalidParameters.selector);
        factory.getAminalsByRange(2, 1);
    }

    function testFuzz_CreateAminal(
        address to,
        string memory name,
        string memory symbol,
        string memory description,
        string memory tokenURI
    ) external {
        vm.assume(to != address(0));
        vm.assume(bytes(name).length > 0);
        vm.assume(bytes(symbol).length > 0);
        vm.assume(bytes(tokenURI).length > 0);
        
        vm.prank(owner);
        address aminalContract = factory.createAminal(to, name, symbol, description, tokenURI, createSampleTraits("Fuzz"));
        
        Aminal aminal = Aminal(aminalContract);
        assertEq(aminal.ownerOf(1), to);
        assertTrue(factory.checkAminalExists(name, symbol, description, tokenURI));
        assertEq(factory.totalAminals(), 1);
    }

    function testFuzz_DuplicateCreationReverts(
        address to1,
        address to2,
        string memory name,
        string memory symbol,
        string memory description,
        string memory tokenURI
    ) external {
        vm.assume(to1 != address(0) && to2 != address(0));
        vm.assume(bytes(name).length > 0);
        vm.assume(bytes(symbol).length > 0);
        vm.assume(bytes(tokenURI).length > 0);
        
        vm.startPrank(owner);
        factory.createAminal(to1, name, symbol, description, tokenURI, createSampleTraits("Fuzz1"));
        
        bytes32 identifier = keccak256(abi.encodePacked(name, symbol, description, tokenURI));
        vm.expectRevert(abi.encodeWithSelector(AminalFactory.AminalAlreadyExists.selector, identifier));
        factory.createAminal(to2, name, symbol, description, tokenURI, createSampleTraits("Fuzz2"));
        vm.stopPrank();
    }
}