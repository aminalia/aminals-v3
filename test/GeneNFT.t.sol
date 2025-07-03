// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "lib/forge-std/src/Test.sol";
import {GeneNFT} from "src/GeneNFT.sol";

contract GeneNFTTest is Test {
    GeneNFT public geneNFT;
    address public owner;
    address public user1;
    address public user2;
    string public constant BASE_URI = "https://api.aminals.com/genes/";
    string public constant NAME = "Dragon Wings Gene";
    string public constant SYMBOL = "DWG";
    string public constant TRAIT_TYPE = "BACK";
    string public constant TRAIT_VALUE = "Dragon Wings";

    event GeneNFTCreated(uint256 indexed tokenId, address indexed owner, string tokenURI);
    event BaseURIUpdated(string newBaseURI);

    function setUp() external {
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        
        vm.prank(owner);
        geneNFT = new GeneNFT(owner, NAME, SYMBOL, BASE_URI, TRAIT_TYPE, TRAIT_VALUE);
    }

    function test_Constructor() external {
        assertEq(geneNFT.name(), NAME);
        assertEq(geneNFT.symbol(), SYMBOL);
        assertEq(geneNFT.owner(), owner);
        assertEq(geneNFT.totalSupply(), 0);
        assertEq(geneNFT.currentTokenId(), 0);
        assertEq(geneNFT.traitType(), TRAIT_TYPE);
        assertEq(geneNFT.traitValue(), TRAIT_VALUE);
    }

    function test_RevertWhen_ConstructorWithZeroAddress() external {
        vm.expectRevert();
        new GeneNFT(address(0), NAME, SYMBOL, BASE_URI, TRAIT_TYPE, TRAIT_VALUE);
    }

    function test_RevertWhen_ConstructorWithEmptyTraitType() external {
        vm.expectRevert(GeneNFT.InvalidParameters.selector);
        new GeneNFT(owner, NAME, SYMBOL, BASE_URI, "", TRAIT_VALUE);
    }

    function test_RevertWhen_ConstructorWithEmptyTraitValue() external {
        vm.expectRevert(GeneNFT.InvalidParameters.selector);
        new GeneNFT(owner, NAME, SYMBOL, BASE_URI, TRAIT_TYPE, "");
    }

    function test_Mint() external {
        string memory tokenURI = "dragonwings1.json";
        
        vm.prank(owner);
        vm.expectEmit(true, true, false, true);
        emit GeneNFTCreated(1, user1, tokenURI);
        
        uint256 tokenId = geneNFT.mint(user1, tokenURI);
        
        assertEq(tokenId, 1);
        assertEq(geneNFT.ownerOf(tokenId), user1);
        assertEq(geneNFT.tokenURI(tokenId), string(abi.encodePacked(BASE_URI, tokenURI)));
        assertEq(geneNFT.totalSupply(), 1);
        assertEq(geneNFT.currentTokenId(), 1);
    }

    function test_MintMultiple() external {
        vm.startPrank(owner);
        
        uint256 tokenId1 = geneNFT.mint(user1, "dragonwings1.json");
        uint256 tokenId2 = geneNFT.mint(user2, "dragonwings2.json");
        uint256 tokenId3 = geneNFT.mint(user1, "dragonwings3.json");
        
        vm.stopPrank();
        
        assertEq(tokenId1, 1);
        assertEq(tokenId2, 2);
        assertEq(tokenId3, 3);
        
        assertEq(geneNFT.ownerOf(1), user1);
        assertEq(geneNFT.ownerOf(2), user2);
        assertEq(geneNFT.ownerOf(3), user1);
        
        assertEq(geneNFT.totalSupply(), 3);
        assertEq(geneNFT.balanceOf(user1), 2);
        assertEq(geneNFT.balanceOf(user2), 1);
    }

    function test_RevertWhen_MintToZeroAddress() external {
        vm.prank(owner);
        vm.expectRevert(GeneNFT.InvalidParameters.selector);
        geneNFT.mint(address(0), "dragonwings1.json");
    }

    function test_RevertWhen_MintCalledByNonOwner() external {
        vm.prank(user1);
        vm.expectRevert();
        geneNFT.mint(user2, "dragonwings1.json");
    }

    function test_BatchMint() external {
        address[] memory recipients = new address[](3);
        recipients[0] = user1;
        recipients[1] = user2;
        recipients[2] = user1;
        
        string[] memory uris = new string[](3);
        uris[0] = "dragonwings1.json";
        uris[1] = "dragonwings2.json";
        uris[2] = "dragonwings3.json";
        
        vm.prank(owner);
        uint256[] memory tokenIds = geneNFT.batchMint(recipients, uris);
        
        assertEq(tokenIds.length, 3);
        assertEq(tokenIds[0], 1);
        assertEq(tokenIds[1], 2);
        assertEq(tokenIds[2], 3);
        
        assertEq(geneNFT.ownerOf(1), user1);
        assertEq(geneNFT.ownerOf(2), user2);
        assertEq(geneNFT.ownerOf(3), user1);
        
        assertEq(geneNFT.totalSupply(), 3);
        assertEq(geneNFT.balanceOf(user1), 2);
        assertEq(geneNFT.balanceOf(user2), 1);
    }

    function test_RevertWhen_BatchMintWithMismatchedArrays() external {
        address[] memory recipients = new address[](2);
        recipients[0] = user1;
        recipients[1] = user2;
        
        string[] memory uris = new string[](3);
        uris[0] = "dragonwings1.json";
        uris[1] = "dragonwings2.json";
        uris[2] = "dragonwings3.json";
        
        vm.prank(owner);
        vm.expectRevert(GeneNFT.InvalidParameters.selector);
        geneNFT.batchMint(recipients, uris);
    }

    function test_RevertWhen_BatchMintWithEmptyArrays() external {
        address[] memory recipients = new address[](0);
        string[] memory uris = new string[](0);
        
        vm.prank(owner);
        vm.expectRevert(GeneNFT.InvalidParameters.selector);
        geneNFT.batchMint(recipients, uris);
    }

    function test_RevertWhen_BatchMintWithZeroAddress() external {
        address[] memory recipients = new address[](2);
        recipients[0] = user1;
        recipients[1] = address(0);
        
        string[] memory uris = new string[](2);
        uris[0] = "dragonwings1.json";
        uris[1] = "dragonwings2.json";
        
        vm.prank(owner);
        vm.expectRevert(GeneNFT.InvalidParameters.selector);
        geneNFT.batchMint(recipients, uris);
    }

    function test_SetBaseURI() external {
        string memory newBaseURI = "https://newapi.aminals.com/genes/";
        
        vm.prank(owner);
        vm.expectEmit(false, false, false, true);
        emit BaseURIUpdated(newBaseURI);
        
        geneNFT.setBaseURI(newBaseURI);
        
        // Mint a token to test the new base URI
        vm.prank(owner);
        uint256 tokenId = geneNFT.mint(user1, "dragonwings1.json");
        
        assertEq(geneNFT.tokenURI(tokenId), string(abi.encodePacked(newBaseURI, "dragonwings1.json")));
    }

    function test_RevertWhen_SetBaseURICalledByNonOwner() external {
        vm.prank(user1);
        vm.expectRevert();
        geneNFT.setBaseURI("https://newapi.aminals.com/genes/");
    }

    function test_GetTraitInfo() external {
        (string memory traitType, string memory traitValue) = geneNFT.getTraitInfo();
        assertEq(traitType, TRAIT_TYPE);
        assertEq(traitValue, TRAIT_VALUE);
    }

    function test_TokenTransfer() external {
        vm.prank(owner);
        uint256 tokenId = geneNFT.mint(user1, "dragonwings1.json");
        
        vm.prank(user1);
        geneNFT.transferFrom(user1, user2, tokenId);
        
        assertEq(geneNFT.ownerOf(tokenId), user2);
        assertEq(geneNFT.balanceOf(user1), 0);
        assertEq(geneNFT.balanceOf(user2), 1);
    }

    function test_TokenEnumeration() external {
        vm.startPrank(owner);
        geneNFT.mint(user1, "dragonwings1.json");
        geneNFT.mint(user2, "dragonwings2.json");
        geneNFT.mint(user1, "dragonwings3.json");
        vm.stopPrank();
        
        // Test tokenByIndex
        assertEq(geneNFT.tokenByIndex(0), 1);
        assertEq(geneNFT.tokenByIndex(1), 2);
        assertEq(geneNFT.tokenByIndex(2), 3);
        
        // Test tokenOfOwnerByIndex
        assertEq(geneNFT.tokenOfOwnerByIndex(user1, 0), 1);
        assertEq(geneNFT.tokenOfOwnerByIndex(user1, 1), 3);
        assertEq(geneNFT.tokenOfOwnerByIndex(user2, 0), 2);
    }

    function test_PublicVariableAccess() external {
        // Test direct access to public variables
        assertEq(geneNFT.currentTokenId(), 0);
        assertEq(geneNFT.baseTokenURI(), BASE_URI);
        assertEq(geneNFT.traitType(), TRAIT_TYPE);
        assertEq(geneNFT.traitValue(), TRAIT_VALUE);
        
        vm.prank(owner);
        geneNFT.mint(user1, "dragonwings1.json");
        
        // Verify public variables updated
        assertEq(geneNFT.currentTokenId(), 1);
    }

    function test_SupportsInterface() external {
        // ERC721 interface
        assertTrue(geneNFT.supportsInterface(0x80ac58cd));
        // ERC721Metadata interface
        assertTrue(geneNFT.supportsInterface(0x5b5e139f));
        // ERC721Enumerable interface
        assertTrue(geneNFT.supportsInterface(0x780e9d63));
        // ERC165 interface
        assertTrue(geneNFT.supportsInterface(0x01ffc9a7));
    }

    function testFuzz_Mint(address to, string memory tokenURI) external {
        vm.assume(to != address(0));
        vm.assume(bytes(tokenURI).length > 0);
        
        vm.prank(owner);
        uint256 tokenId = geneNFT.mint(to, tokenURI);
        
        assertEq(geneNFT.ownerOf(tokenId), to);
        assertEq(geneNFT.totalSupply(), 1);
        assertEq(geneNFT.currentTokenId(), 1);
    }

    function testFuzz_SetBaseURI(string memory newBaseURI) external {
        vm.prank(owner);
        geneNFT.setBaseURI(newBaseURI);
        
        vm.prank(owner);
        uint256 tokenId = geneNFT.mint(user1, "test.json");
        
        assertEq(geneNFT.tokenURI(tokenId), string(abi.encodePacked(newBaseURI, "test.json")));
    }
}