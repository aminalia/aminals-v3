// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "lib/forge-std/src/Test.sol";
import {Aminal} from "src/Aminal.sol";

contract AminalTest is Test {
    Aminal public aminal;
    address public owner;
    address public user1;
    address public user2;
    string public constant BASE_URI = "https://api.aminals.com/metadata/";
    string public constant NAME = "Fire Dragon";
    string public constant SYMBOL = "FDRAGON";

    event AminalCreated(uint256 indexed tokenId, address indexed owner, string tokenURI);
    event BaseURIUpdated(string newBaseURI);

    function setUp() external {
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        
        // Create sample traits
        Aminal.Traits memory traits = Aminal.Traits({
            back: "Dragon Wings",
            arm: "Scaled Arms",
            tail: "Fire Tail",
            ears: "Pointed Ears",
            body: "Dragon Body",
            face: "Fierce Face",
            mouth: "Fire Breath",
            misc: "Golden Scales"
        });
        
        vm.prank(owner);
        aminal = new Aminal(owner, NAME, SYMBOL, BASE_URI, traits);
    }

    function test_Constructor() external {
        assertEq(aminal.name(), NAME);
        assertEq(aminal.symbol(), SYMBOL);
        assertEq(aminal.owner(), owner);
        assertEq(aminal.totalSupply(), 0);
        assertEq(aminal.TOKEN_ID(), 1);
        assertFalse(aminal.minted());
    }

    function test_RevertWhen_ConstructorWithZeroAddress() external {
        Aminal.Traits memory traits = Aminal.Traits({
            back: "Dragon Wings",
            arm: "Scaled Arms",
            tail: "Fire Tail",
            ears: "Pointed Ears",
            body: "Dragon Body",
            face: "Fierce Face",
            mouth: "Fire Breath",
            misc: "Golden Scales"
        });
        
        vm.expectRevert();
        new Aminal(address(0), NAME, SYMBOL, BASE_URI, traits);
    }

    function test_Mint() external {
        string memory tokenURI = "firedragon.json";
        
        vm.prank(owner);
        vm.expectEmit(true, true, false, true);
        emit AminalCreated(1, user1, tokenURI);
        
        uint256 tokenId = aminal.mint(user1, tokenURI);
        
        assertEq(tokenId, 1);
        assertEq(aminal.ownerOf(tokenId), user1);
        assertEq(aminal.tokenURI(tokenId), string(abi.encodePacked(BASE_URI, tokenURI)));
        assertEq(aminal.totalSupply(), 1);
        assertTrue(aminal.exists(tokenId));
        assertTrue(aminal.minted());
    }

    function test_RevertWhen_MintToZeroAddress() external {
        vm.prank(owner);
        vm.expectRevert(Aminal.InvalidParameters.selector);
        aminal.mint(address(0), "firedragon.json");
    }

    function test_RevertWhen_MintCalledByNonOwner() external {
        vm.prank(user1);
        vm.expectRevert();
        aminal.mint(user2, "firedragon.json");
    }

    function test_RevertWhen_MintTwice() external {
        vm.startPrank(owner);
        aminal.mint(user1, "firedragon.json");
        
        vm.expectRevert(Aminal.AlreadyMinted.selector);
        aminal.mint(user2, "firedragon2.json");
        vm.stopPrank();
    }

    function test_SetBaseURI() external {
        string memory newBaseURI = "https://newapi.aminals.com/metadata/";
        
        vm.prank(owner);
        vm.expectEmit(false, false, false, true);
        emit BaseURIUpdated(newBaseURI);
        
        aminal.setBaseURI(newBaseURI);
        
        // Mint a token to test the new base URI
        vm.prank(owner);
        uint256 tokenId = aminal.mint(user1, "firedragon.json");
        
        assertEq(aminal.tokenURI(tokenId), string(abi.encodePacked(newBaseURI, "firedragon.json")));
    }

    function test_RevertWhen_SetBaseURICalledByNonOwner() external {
        vm.prank(user1);
        vm.expectRevert();
        aminal.setBaseURI("https://newapi.aminals.com/metadata/");
    }

    function test_TokenTransfer() external {
        vm.prank(owner);
        uint256 tokenId = aminal.mint(user1, "firedragon.json");
        
        vm.prank(user1);
        aminal.transferFrom(user1, user2, tokenId);
        
        assertEq(aminal.ownerOf(tokenId), user2);
        assertEq(aminal.balanceOf(user1), 0);
        assertEq(aminal.balanceOf(user2), 1);
    }

    function test_Exists() external {
        assertFalse(aminal.exists(1));
        assertFalse(aminal.exists(2));
        
        vm.prank(owner);
        uint256 tokenId = aminal.mint(user1, "firedragon.json");
        
        assertTrue(aminal.exists(tokenId));
        assertFalse(aminal.exists(2));
    }

    function test_IsMinted() external {
        assertFalse(aminal.minted());
        
        vm.prank(owner);
        aminal.mint(user1, "firedragon.json");
        
        assertTrue(aminal.minted());
    }

    function test_TotalSupply() external {
        assertEq(aminal.totalSupply(), 0);
        
        vm.prank(owner);
        aminal.mint(user1, "firedragon.json");
        
        assertEq(aminal.totalSupply(), 1);
    }

    function test_PublicVariableAccess() external {
        // Test direct access to public variables
        assertFalse(aminal.minted());
        assertEq(aminal.baseTokenURI(), BASE_URI);
        assertEq(aminal.TOKEN_ID(), 1);
        
        vm.prank(owner);
        aminal.mint(user1, "firedragon.json");
        
        // Verify public variables updated
        assertTrue(aminal.minted());
    }

    function test_Traits() external {
        // Test getTraits function
        Aminal.Traits memory traits = aminal.getTraits();
        assertEq(traits.back, "Dragon Wings");
        assertEq(traits.arm, "Scaled Arms");
        assertEq(traits.tail, "Fire Tail");
        assertEq(traits.ears, "Pointed Ears");
        assertEq(traits.body, "Dragon Body");
        assertEq(traits.face, "Fierce Face");
        assertEq(traits.mouth, "Fire Breath");
        assertEq(traits.misc, "Golden Scales");
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
        
        assertEq(tokenId, 1);
        assertEq(aminal.ownerOf(tokenId), to);
        assertTrue(aminal.exists(tokenId));
        assertTrue(aminal.minted());
    }

    function testFuzz_SetBaseURI(string memory newBaseURI) external {
        vm.prank(owner);
        aminal.setBaseURI(newBaseURI);
        
        vm.prank(owner);
        uint256 tokenId = aminal.mint(user1, "test.json");
        
        assertEq(aminal.tokenURI(tokenId), string(abi.encodePacked(newBaseURI, "test.json")));
    }
}