// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "lib/forge-std/src/Test.sol";
import {AminalFactory} from "src/AminalFactory.sol";
import {Aminal} from "src/Aminal.sol";

contract AminalFactoryTest is Test {
    AminalFactory public factory;
    Aminal public aminal;
    address public owner;
    address public user1;
    address public user2;
    string public constant BASE_URI = "https://api.aminals.com/metadata/";

    event AminalFactoryCreated(
        uint256 indexed tokenId,
        address indexed creator,
        address indexed owner,
        string name,
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
        aminal = Aminal(factory.getAminalContract());
    }

    function test_Constructor() external {
        assertEq(factory.owner(), owner);
        assertEq(factory.totalCreated(), 0);
        assertFalse(factory.isPaused());
        assertEq(address(factory.aminalContract()), address(aminal));
    }

    function test_RevertWhen_ConstructorWithZeroAddress() external {
        vm.expectRevert();
        new AminalFactory(address(0), BASE_URI);
    }

    function test_CreateAminal() external {
        string memory name = "Fire Dragon";
        string memory description = "A fierce dragon with fire breath";
        string memory tokenURI = "firedragon.json";
        
        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit AminalFactoryCreated(0, owner, user1, name, description, tokenURI);
        
        uint256 tokenId = factory.createAminal(user1, name, description, tokenURI);
        
        assertEq(tokenId, 0);
        assertEq(aminal.ownerOf(tokenId), user1);
        assertEq(factory.totalCreated(), 1);
        assertTrue(factory.aminalExists(name, description, tokenURI));
        
        uint256[] memory createdTokens = factory.getCreatedByAddress(owner);
        assertEq(createdTokens.length, 1);
        assertEq(createdTokens[0], tokenId);
    }

    function test_RevertWhen_CreateAminalWithZeroAddress() external {
        vm.prank(owner);
        vm.expectRevert(AminalFactory.InvalidParameters.selector);
        factory.createAminal(address(0), "Dragon", "A dragon", "dragon.json");
    }

    function test_RevertWhen_CreateAminalWithEmptyName() external {
        vm.prank(owner);
        vm.expectRevert(AminalFactory.InvalidParameters.selector);
        factory.createAminal(user1, "", "A dragon", "dragon.json");
    }

    function test_RevertWhen_CreateAminalWithEmptyTokenURI() external {
        vm.prank(owner);
        vm.expectRevert(AminalFactory.InvalidParameters.selector);
        factory.createAminal(user1, "Dragon", "A dragon", "");
    }

    function test_RevertWhen_CreateAminalCalledByNonOwner() external {
        vm.prank(user1);
        vm.expectRevert();
        factory.createAminal(user2, "Dragon", "A dragon", "dragon.json");
    }

    function test_RevertWhen_CreateDuplicateAminal() external {
        string memory name = "Fire Dragon";
        string memory description = "A fierce dragon";
        string memory tokenURI = "firedragon.json";
        
        vm.startPrank(owner);
        factory.createAminal(user1, name, description, tokenURI);
        
        bytes32 identifier = keccak256(abi.encodePacked(name, description, tokenURI));
        vm.expectRevert(abi.encodeWithSelector(AminalFactory.AminalAlreadyExists.selector, identifier));
        factory.createAminal(user2, name, description, tokenURI);
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
        
        string[] memory descriptions = new string[](3);
        descriptions[0] = "A fierce dragon";
        descriptions[1] = "A cold phoenix";
        descriptions[2] = "A sturdy golem";
        
        string[] memory tokenURIs = new string[](3);
        tokenURIs[0] = "firedragon.json";
        tokenURIs[1] = "icephoenix.json";
        tokenURIs[2] = "earthgolem.json";
        
        vm.prank(owner);
        uint256[] memory tokenIds = factory.batchCreateAminals(recipients, names, descriptions, tokenURIs);
        
        assertEq(tokenIds.length, 3);
        assertEq(factory.totalCreated(), 3);
        
        for (uint256 i = 0; i < tokenIds.length; i++) {
            assertEq(aminal.ownerOf(tokenIds[i]), recipients[i]);
            assertTrue(factory.aminalExists(names[i], descriptions[i], tokenURIs[i]));
        }
        
        assertEq(aminal.balanceOf(user1), 2);
        assertEq(aminal.balanceOf(user2), 1);
    }

    function test_RevertWhen_BatchCreateWithMismatchedArrays() external {
        address[] memory recipients = new address[](2);
        recipients[0] = user1;
        recipients[1] = user2;
        
        string[] memory names = new string[](3);
        names[0] = "Dragon";
        names[1] = "Phoenix";
        names[2] = "Golem";
        
        string[] memory descriptions = new string[](2);
        descriptions[0] = "A dragon";
        descriptions[1] = "A phoenix";
        
        string[] memory tokenURIs = new string[](2);
        tokenURIs[0] = "dragon.json";
        tokenURIs[1] = "phoenix.json";
        
        vm.prank(owner);
        vm.expectRevert(AminalFactory.InvalidParameters.selector);
        factory.batchCreateAminals(recipients, names, descriptions, tokenURIs);
    }

    function test_RevertWhen_BatchCreateWithEmptyArrays() external {
        address[] memory recipients = new address[](0);
        string[] memory names = new string[](0);
        string[] memory descriptions = new string[](0);
        string[] memory tokenURIs = new string[](0);
        
        vm.prank(owner);
        vm.expectRevert(AminalFactory.InvalidParameters.selector);
        factory.batchCreateAminals(recipients, names, descriptions, tokenURIs);
    }

    function test_SetPaused() external {
        assertFalse(factory.isPaused());
        
        vm.prank(owner);
        vm.expectEmit(false, false, false, true);
        emit FactoryPaused(true);
        factory.setPaused(true);
        
        assertTrue(factory.isPaused());
        
        vm.prank(owner);
        vm.expectEmit(false, false, false, true);
        emit FactoryPaused(false);
        factory.setPaused(false);
        
        assertFalse(factory.isPaused());
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
        factory.createAminal(user1, "Dragon", "A dragon", "dragon.json");
    }

    function test_RevertWhen_BatchCreateWhilePaused() external {
        vm.prank(owner);
        factory.setPaused(true);
        
        address[] memory recipients = new address[](1);
        recipients[0] = user1;
        string[] memory names = new string[](1);
        names[0] = "Dragon";
        string[] memory descriptions = new string[](1);
        descriptions[0] = "A dragon";
        string[] memory tokenURIs = new string[](1);
        tokenURIs[0] = "dragon.json";
        
        vm.prank(owner);
        vm.expectRevert(AminalFactory.FactoryIsPaused.selector);
        factory.batchCreateAminals(recipients, names, descriptions, tokenURIs);
    }

    function test_SetBaseURI() external {
        string memory newBaseURI = "https://newapi.aminals.com/metadata/";
        
        vm.prank(owner);
        factory.setBaseURI(newBaseURI);
        
        vm.prank(owner);
        uint256 tokenId = factory.createAminal(user1, "Dragon", "A dragon", "dragon.json");
        
        assertEq(aminal.tokenURI(tokenId), string(abi.encodePacked(newBaseURI, "dragon.json")));
    }

    function test_RevertWhen_SetBaseURICalledByNonOwner() external {
        vm.prank(user1);
        vm.expectRevert();
        factory.setBaseURI("https://newapi.aminals.com/metadata/");
    }

    function test_MultipleCreators() external {
        // Create first Aminal
        vm.prank(owner);
        uint256 tokenId1 = factory.createAminal(user1, "Dragon", "A dragon", "dragon.json");
        
        // Transfer ownership to user1
        vm.prank(owner);
        factory.transferOwnership(user1);
        
        // Create second Aminal with new owner
        vm.prank(user1);
        uint256 tokenId2 = factory.createAminal(user2, "Phoenix", "A phoenix", "phoenix.json");
        
        uint256[] memory createdByOwner = factory.getCreatedByAddress(owner);
        uint256[] memory createdByUser1 = factory.getCreatedByAddress(user1);
        
        assertEq(createdByOwner.length, 1);
        assertEq(createdByOwner[0], tokenId1);
        assertEq(createdByUser1.length, 1);
        assertEq(createdByUser1[0], tokenId2);
        assertEq(factory.totalCreated(), 2);
    }

    function testFuzz_CreateAminal(
        address to,
        string memory name,
        string memory description,
        string memory tokenURI
    ) external {
        vm.assume(to != address(0));
        vm.assume(bytes(name).length > 0);
        vm.assume(bytes(tokenURI).length > 0);
        
        vm.prank(owner);
        uint256 tokenId = factory.createAminal(to, name, description, tokenURI);
        
        assertEq(aminal.ownerOf(tokenId), to);
        assertTrue(factory.aminalExists(name, description, tokenURI));
        assertEq(factory.totalCreated(), 1);
    }

    function testFuzz_DuplicateCreationReverts(
        address to1,
        address to2,
        string memory name,
        string memory description,
        string memory tokenURI
    ) external {
        vm.assume(to1 != address(0) && to2 != address(0));
        vm.assume(bytes(name).length > 0);
        vm.assume(bytes(tokenURI).length > 0);
        
        vm.startPrank(owner);
        factory.createAminal(to1, name, description, tokenURI);
        
        bytes32 identifier = keccak256(abi.encodePacked(name, description, tokenURI));
        vm.expectRevert(abi.encodeWithSelector(AminalFactory.AminalAlreadyExists.selector, identifier));
        factory.createAminal(to2, name, description, tokenURI);
        vm.stopPrank();
    }
}