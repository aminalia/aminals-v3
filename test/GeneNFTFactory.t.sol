// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "lib/forge-std/src/Test.sol";
import {GeneNFTFactory} from "src/GeneNFTFactory.sol";
import {GeneNFT} from "src/GeneNFT.sol";

contract GeneNFTFactoryTest is Test {
    GeneNFTFactory public factory;
    address public owner;
    address public user1;
    address public user2;
    string public constant BASE_URI = "https://api.aminals.com/genes/";

    event GeneNFTCollectionCreated(
        address indexed collectionContract,
        address indexed creator,
        uint256 collectionId,
        string name,
        string symbol,
        string traitType,
        string traitValue
    );
    event FactoryPaused(bool paused);

    function setUp() external {
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        
        vm.prank(owner);
        factory = new GeneNFTFactory(owner, BASE_URI);
    }

    function test_Constructor() external {
        assertEq(factory.owner(), owner);
        assertEq(factory.totalCollections(), 0);
        assertFalse(factory.paused());
        assertEq(factory.baseTokenURI(), BASE_URI);
    }

    function test_RevertWhen_ConstructorWithZeroAddress() external {
        vm.expectRevert();
        new GeneNFTFactory(address(0), BASE_URI);
    }

    function test_CreateCollection() external {
        string memory name = "Dragon Wings Gene";
        string memory symbol = "DWG";
        string memory traitType = "BACK";
        string memory traitValue = "Dragon Wings";
        
        vm.prank(owner);
        address collectionContract = factory.createCollection(name, symbol, traitType, traitValue);
        
        assertTrue(collectionContract != address(0));
        assertEq(factory.totalCollections(), 1);
        assertTrue(factory.checkCollectionExists(traitType, traitValue));
        
        address[] memory createdContracts = factory.getCreatedByAddress(owner);
        assertEq(createdContracts.length, 1);
        assertEq(createdContracts[0], collectionContract);
        
        address[] memory backCollections = factory.getCollectionsByTraitType(traitType);
        assertEq(backCollections.length, 1);
        assertEq(backCollections[0], collectionContract);
        
        // Verify the GeneNFT contract was properly created
        GeneNFT collection = GeneNFT(collectionContract);
        assertEq(collection.name(), name);
        assertEq(collection.symbol(), symbol);
        assertEq(collection.traitType(), traitType);
        assertEq(collection.traitValue(), traitValue);
    }

    function test_RevertWhen_CreateCollectionWithEmptyName() external {
        vm.prank(owner);
        vm.expectRevert(GeneNFTFactory.InvalidParameters.selector);
        factory.createCollection("", "DWG", "BACK", "Dragon Wings");
    }

    function test_RevertWhen_CreateCollectionWithEmptySymbol() external {
        vm.prank(owner);
        vm.expectRevert(GeneNFTFactory.InvalidParameters.selector);
        factory.createCollection("Dragon Wings", "", "BACK", "Dragon Wings");
    }

    function test_RevertWhen_CreateCollectionWithEmptyTraitType() external {
        vm.prank(owner);
        vm.expectRevert(GeneNFTFactory.InvalidParameters.selector);
        factory.createCollection("Dragon Wings", "DWG", "", "Dragon Wings");
    }

    function test_RevertWhen_CreateCollectionWithEmptyTraitValue() external {
        vm.prank(owner);
        vm.expectRevert(GeneNFTFactory.InvalidParameters.selector);
        factory.createCollection("Dragon Wings", "DWG", "BACK", "");
    }

    function test_RevertWhen_CreateCollectionCalledByNonOwner() external {
        vm.prank(user1);
        vm.expectRevert();
        factory.createCollection("Dragon Wings", "DWG", "BACK", "Dragon Wings");
    }

    function test_RevertWhen_CreateDuplicateCollection() external {
        string memory name = "Dragon Wings Gene";
        string memory symbol = "DWG";
        string memory traitType = "BACK";
        string memory traitValue = "Dragon Wings";
        
        vm.startPrank(owner);
        factory.createCollection(name, symbol, traitType, traitValue);
        
        bytes32 identifier = keccak256(abi.encodePacked(traitType, traitValue));
        vm.expectRevert(abi.encodeWithSelector(GeneNFTFactory.CollectionAlreadyExists.selector, identifier));
        factory.createCollection("Different Name", "DNT", traitType, traitValue);
        vm.stopPrank();
    }

    function test_MintFromCollection() external {
        vm.prank(owner);
        address collectionContract = factory.createCollection("Dragon Wings", "DWG", "BACK", "Dragon Wings");
        
        string memory tokenURI = "dragonwings1.json";
        
        vm.prank(owner);
        uint256 tokenId = factory.mintFromCollection(collectionContract, user1, tokenURI);
        
        assertEq(tokenId, 1);
        
        GeneNFT collection = GeneNFT(collectionContract);
        assertEq(collection.ownerOf(tokenId), user1);
        assertEq(collection.totalSupply(), 1);
    }

    function test_RevertWhen_MintFromCollectionWithZeroAddress() external {
        vm.prank(owner);
        vm.expectRevert(GeneNFTFactory.InvalidParameters.selector);
        factory.mintFromCollection(address(0), user1, "test.json");
    }

    function test_RevertWhen_MintFromCollectionWithZeroRecipient() external {
        vm.prank(owner);
        address collectionContract = factory.createCollection("Dragon Wings", "DWG", "BACK", "Dragon Wings");
        
        vm.prank(owner);
        vm.expectRevert(GeneNFTFactory.InvalidParameters.selector);
        factory.mintFromCollection(collectionContract, address(0), "test.json");
    }

    function test_BatchMintFromCollection() external {
        vm.prank(owner);
        address collectionContract = factory.createCollection("Dragon Wings", "DWG", "BACK", "Dragon Wings");
        
        address[] memory recipients = new address[](3);
        recipients[0] = user1;
        recipients[1] = user2;
        recipients[2] = user1;
        
        string[] memory uris = new string[](3);
        uris[0] = "dragonwings1.json";
        uris[1] = "dragonwings2.json";
        uris[2] = "dragonwings3.json";
        
        vm.prank(owner);
        uint256[] memory tokenIds = factory.batchMintFromCollection(collectionContract, recipients, uris);
        
        assertEq(tokenIds.length, 3);
        assertEq(tokenIds[0], 1);
        assertEq(tokenIds[1], 2);
        assertEq(tokenIds[2], 3);
        
        GeneNFT collection = GeneNFT(collectionContract);
        assertEq(collection.ownerOf(1), user1);
        assertEq(collection.ownerOf(2), user2);
        assertEq(collection.ownerOf(3), user1);
        assertEq(collection.totalSupply(), 3);
    }

    function test_RevertWhen_BatchMintFromCollectionWithZeroAddress() external {
        address[] memory recipients = new address[](1);
        recipients[0] = user1;
        
        string[] memory uris = new string[](1);
        uris[0] = "test.json";
        
        vm.prank(owner);
        vm.expectRevert(GeneNFTFactory.InvalidParameters.selector);
        factory.batchMintFromCollection(address(0), recipients, uris);
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

    function test_RevertWhen_CreateCollectionWhilePaused() external {
        vm.prank(owner);
        factory.setPaused(true);
        
        vm.prank(owner);
        vm.expectRevert(GeneNFTFactory.FactoryIsPaused.selector);
        factory.createCollection("Dragon Wings", "DWG", "BACK", "Dragon Wings");
    }

    function test_RevertWhen_MintWhilePaused() external {
        vm.prank(owner);
        address collectionContract = factory.createCollection("Dragon Wings", "DWG", "BACK", "Dragon Wings");
        
        vm.prank(owner);
        factory.setPaused(true);
        
        vm.prank(owner);
        vm.expectRevert(GeneNFTFactory.FactoryIsPaused.selector);
        factory.mintFromCollection(collectionContract, user1, "test.json");
    }

    function test_SetBaseURI() external {
        string memory newBaseURI = "https://newapi.aminals.com/genes/";
        
        vm.prank(owner);
        factory.setBaseURI(newBaseURI);
        
        assertEq(factory.baseTokenURI(), newBaseURI);
        
        vm.prank(owner);
        address collectionContract = factory.createCollection("Dragon Wings", "DWG", "BACK", "Dragon Wings");
        
        vm.prank(owner);
        uint256 tokenId = factory.mintFromCollection(collectionContract, user1, "dragonwings1.json");
        
        GeneNFT collection = GeneNFT(collectionContract);
        assertEq(collection.tokenURI(tokenId), string(abi.encodePacked(newBaseURI, "dragonwings1.json")));
    }

    function test_RevertWhen_SetBaseURICalledByNonOwner() external {
        vm.prank(user1);
        vm.expectRevert();
        factory.setBaseURI("https://newapi.aminals.com/genes/");
    }

    function test_MultipleCollectionsForSameTraitType() external {
        vm.startPrank(owner);
        
        // Create multiple collections for the same trait type
        address collection1 = factory.createCollection("Dragon Wings", "DWG", "BACK", "Dragon Wings");
        address collection2 = factory.createCollection("Angel Wings", "AWG", "BACK", "Angel Wings");
        address collection3 = factory.createCollection("Bat Wings", "BWG", "BACK", "Bat Wings");
        
        vm.stopPrank();
        
        address[] memory backCollections = factory.getCollectionsByTraitType("BACK");
        assertEq(backCollections.length, 3);
        assertEq(backCollections[0], collection1);
        assertEq(backCollections[1], collection2);
        assertEq(backCollections[2], collection3);
    }

    function test_GetCollectionsByRange() external {
        vm.startPrank(owner);
        address collection1 = factory.createCollection("Dragon Wings", "DWG", "BACK", "Dragon Wings");
        address collection2 = factory.createCollection("Fire Tail", "FTG", "TAIL", "Fire Tail");
        address collection3 = factory.createCollection("Ice Tail", "ITG", "TAIL", "Ice Tail");
        vm.stopPrank();
        
        address[] memory collections = factory.getCollectionsByRange(1, 3);
        assertEq(collections.length, 3);
        assertEq(collections[0], collection1);
        assertEq(collections[1], collection2);
        assertEq(collections[2], collection3);
        
        // Test getting individual collections via public mapping
        assertEq(factory.collectionById(1), collection1);
        assertEq(factory.collectionById(2), collection2);
        assertEq(factory.collectionById(3), collection3);
        
        // Test single item range
        address[] memory singleCollection = factory.getCollectionsByRange(2, 2);
        assertEq(singleCollection.length, 1);
        assertEq(singleCollection[0], collection2);
    }

    function test_RevertWhen_GetCollectionsByRangeInvalidParams() external {
        vm.startPrank(owner);
        factory.createCollection("Dragon Wings", "DWG", "BACK", "Dragon Wings");
        vm.stopPrank();
        
        // Test invalid start ID (0)
        vm.expectRevert(GeneNFTFactory.InvalidParameters.selector);
        factory.getCollectionsByRange(0, 1);
        
        // Test start > total
        vm.expectRevert(GeneNFTFactory.InvalidParameters.selector);
        factory.getCollectionsByRange(2, 2);
        
        // Test end < start
        vm.expectRevert(GeneNFTFactory.InvalidParameters.selector);
        factory.getCollectionsByRange(2, 1);
    }

    function test_PublicVariableAccess() external {
        // Test direct access to public variables
        assertEq(factory.totalCollections(), 0);
        assertFalse(factory.paused());
        assertEq(factory.baseTokenURI(), BASE_URI);
        
        vm.startPrank(owner);
        address collection1 = factory.createCollection("Dragon Wings", "DWG", "BACK", "Dragon Wings");
        vm.stopPrank();
        
        // Verify public variables updated
        assertEq(factory.totalCollections(), 1);
        assertEq(factory.collectionById(1), collection1);
        
        // Test collectionExists mapping
        bytes32 identifier = keccak256(abi.encodePacked("BACK", "Dragon Wings"));
        assertTrue(factory.collectionExists(identifier));
        
        // Test createdByAddress mapping via array access
        address[] memory ownerCreated = factory.getCreatedByAddress(owner);
        assertEq(ownerCreated[0], collection1);
    }

    function testFuzz_CreateCollection(
        string memory name,
        string memory symbol,
        string memory traitType,
        string memory traitValue
    ) external {
        vm.assume(bytes(name).length > 0);
        vm.assume(bytes(symbol).length > 0);
        vm.assume(bytes(traitType).length > 0);
        vm.assume(bytes(traitValue).length > 0);
        
        vm.prank(owner);
        address collectionContract = factory.createCollection(name, symbol, traitType, traitValue);
        
        GeneNFT collection = GeneNFT(collectionContract);
        assertEq(collection.name(), name);
        assertEq(collection.symbol(), symbol);
        assertEq(collection.traitType(), traitType);
        assertEq(collection.traitValue(), traitValue);
        assertTrue(factory.checkCollectionExists(traitType, traitValue));
        assertEq(factory.totalCollections(), 1);
    }

    function testFuzz_DuplicateCollectionReverts(
        string memory name1,
        string memory symbol1,
        string memory name2,
        string memory symbol2,
        string memory traitType,
        string memory traitValue
    ) external {
        vm.assume(bytes(name1).length > 0);
        vm.assume(bytes(symbol1).length > 0);
        vm.assume(bytes(name2).length > 0);
        vm.assume(bytes(symbol2).length > 0);
        vm.assume(bytes(traitType).length > 0);
        vm.assume(bytes(traitValue).length > 0);
        
        vm.startPrank(owner);
        factory.createCollection(name1, symbol1, traitType, traitValue);
        
        bytes32 identifier = keccak256(abi.encodePacked(traitType, traitValue));
        vm.expectRevert(abi.encodeWithSelector(GeneNFTFactory.CollectionAlreadyExists.selector, identifier));
        factory.createCollection(name2, symbol2, traitType, traitValue);
        vm.stopPrank();
    }
}