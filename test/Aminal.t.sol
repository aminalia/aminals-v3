// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "lib/openzeppelin-contracts/lib/forge-std/src/Test.sol";
import {Aminal} from "src/Aminal.sol";

contract AminalTest is Test {
    Aminal public aminal;
    address public owner;
    address public user1;
    address public user2;
    string public constant BASE_URI = "https://api.aminals.com/metadata/";

    event AminalCreated(uint256 indexed tokenId, address indexed owner, string tokenURI);
    event BaseURIUpdated(string newBaseURI);

    function setUp() external {
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        
        vm.prank(owner);
        aminal = new Aminal(owner, BASE_URI);
    }

    function test_Constructor() external {
        assertEq(aminal.name(), "Aminals");
        assertEq(aminal.symbol(), "AMINAL");
        assertEq(aminal.owner(), owner);
        assertEq(aminal.totalSupply(), 0);
    }

    function test_RevertWhen_ConstructorWithZeroAddress() external {
        vm.expectRevert();
        new Aminal(address(0), BASE_URI);
    }

    function test_Mint() external {
        string memory tokenURI = "aminal1.json";
        
        vm.prank(owner);
        vm.expectEmit(true, true, false, true);
        emit AminalCreated(0, user1, tokenURI);
        
        uint256 tokenId = aminal.mint(user1, tokenURI);
        
        assertEq(tokenId, 0);
        assertEq(aminal.ownerOf(tokenId), user1);
        assertEq(aminal.tokenURI(tokenId), string(abi.encodePacked(BASE_URI, tokenURI)));
        assertEq(aminal.totalSupply(), 1);
        assertTrue(aminal.exists(tokenId));
    }

    function test_RevertWhen_MintToZeroAddress() external {
        vm.prank(owner);
        vm.expectRevert(Aminal.InvalidParameters.selector);
        aminal.mint(address(0), "aminal1.json");
    }

    function test_RevertWhen_MintCalledByNonOwner() external {
        vm.prank(user1);
        vm.expectRevert();
        aminal.mint(user2, "aminal1.json");
    }

    function test_SetBaseURI() external {
        string memory newBaseURI = "https://newapi.aminals.com/metadata/";
        
        vm.prank(owner);
        vm.expectEmit(false, false, false, true);
        emit BaseURIUpdated(newBaseURI);
        
        aminal.setBaseURI(newBaseURI);
        
        // Mint a token to test the new base URI
        vm.prank(owner);
        uint256 tokenId = aminal.mint(user1, "aminal1.json");
        
        assertEq(aminal.tokenURI(tokenId), string(abi.encodePacked(newBaseURI, "aminal1.json")));
    }

    function test_RevertWhen_SetBaseURICalledByNonOwner() external {
        vm.prank(user1);
        vm.expectRevert();
        aminal.setBaseURI("https://newapi.aminals.com/metadata/");
    }

    function test_MultipleTokens() external {
        vm.startPrank(owner);
        
        uint256 tokenId1 = aminal.mint(user1, "aminal1.json");
        uint256 tokenId2 = aminal.mint(user2, "aminal2.json");
        uint256 tokenId3 = aminal.mint(user1, "aminal3.json");
        
        vm.stopPrank();
        
        assertEq(tokenId1, 0);
        assertEq(tokenId2, 1);
        assertEq(tokenId3, 2);
        assertEq(aminal.totalSupply(), 3);
        
        assertEq(aminal.ownerOf(tokenId1), user1);
        assertEq(aminal.ownerOf(tokenId2), user2);
        assertEq(aminal.ownerOf(tokenId3), user1);
        
        assertEq(aminal.balanceOf(user1), 2);
        assertEq(aminal.balanceOf(user2), 1);
    }

    function test_TokenTransfer() external {
        vm.prank(owner);
        uint256 tokenId = aminal.mint(user1, "aminal1.json");
        
        vm.prank(user1);
        aminal.transferFrom(user1, user2, tokenId);
        
        assertEq(aminal.ownerOf(tokenId), user2);
        assertEq(aminal.balanceOf(user1), 0);
        assertEq(aminal.balanceOf(user2), 1);
    }

    function test_Exists() external {
        assertFalse(aminal.exists(0));
        assertFalse(aminal.exists(999));
        
        vm.prank(owner);
        uint256 tokenId = aminal.mint(user1, "aminal1.json");
        
        assertTrue(aminal.exists(tokenId));
        assertFalse(aminal.exists(tokenId + 1));
    }

    function test_SupportsInterface() external {
        // ERC721 interface
        assertTrue(aminal.supportsInterface(0x80ac58cd));
        // ERC721Metadata interface
        assertTrue(aminal.supportsInterface(0x5b5e139f));
        // ERC165 interface
        assertTrue(aminal.supportsInterface(0x01ffc9a7));
    }

    function testFuzz_Mint(address to, string memory tokenURI) external {
        vm.assume(to != address(0));
        vm.assume(bytes(tokenURI).length > 0);
        
        vm.prank(owner);
        uint256 tokenId = aminal.mint(to, tokenURI);
        
        assertEq(aminal.ownerOf(tokenId), to);
        assertTrue(aminal.exists(tokenId));
    }

    function testFuzz_SetBaseURI(string memory newBaseURI) external {
        vm.prank(owner);
        aminal.setBaseURI(newBaseURI);
        
        vm.prank(owner);
        uint256 tokenId = aminal.mint(user1, "test.json");
        
        assertEq(aminal.tokenURI(tokenId), string(abi.encodePacked(newBaseURI, "test.json")));
    }
}