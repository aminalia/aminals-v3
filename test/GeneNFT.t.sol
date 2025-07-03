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
    string public constant NAME = "Aminals Genes";
    string public constant SYMBOL = "GENES";

    event GeneNFTCreated(
        uint256 indexed tokenId, address indexed owner, string traitType, string traitValue, string tokenURI
    );
    event BaseURIUpdated(string newBaseURI);

    function setUp() external {
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        vm.prank(owner);
        geneNFT = new GeneNFT(owner, NAME, SYMBOL, BASE_URI);
    }

    function test_Constructor() external {
        assertEq(geneNFT.name(), NAME);
        assertEq(geneNFT.symbol(), SYMBOL);
        assertEq(geneNFT.owner(), owner);
        assertEq(geneNFT.totalSupply(), 0);
        assertEq(geneNFT.currentTokenId(), 0);
    }

    function test_RevertWhen_ConstructorWithZeroAddress() external {
        vm.expectRevert();
        new GeneNFT(address(0), NAME, SYMBOL, BASE_URI);
    }

    function test_Mint() external {
        string memory traitType = "BACK";
        string memory traitValue = "Dragon Wings";
        string memory tokenURI = "dragonwings1.json";

        vm.prank(owner);
        vm.expectEmit(true, true, false, true);
        emit GeneNFTCreated(1, user1, traitType, traitValue, tokenURI);

        uint256 tokenId = geneNFT.mint(user1, traitType, traitValue, tokenURI);

        assertEq(tokenId, 1);
        assertEq(geneNFT.ownerOf(tokenId), user1);
        assertEq(geneNFT.tokenURI(tokenId), string(abi.encodePacked(BASE_URI, tokenURI)));
        assertEq(geneNFT.totalSupply(), 1);
        assertEq(geneNFT.currentTokenId(), 1);
        assertEq(geneNFT.tokenTraitType(tokenId), traitType);
        assertEq(geneNFT.tokenTraitValue(tokenId), traitValue);
    }

    function test_MintMultiple() external {
        vm.startPrank(owner);

        uint256 tokenId1 = geneNFT.mint(user1, "BACK", "Dragon Wings", "dragonwings1.json");
        uint256 tokenId2 = geneNFT.mint(user2, "ARM", "Scaled Arms", "scaledarms1.json");
        uint256 tokenId3 = geneNFT.mint(user1, "TAIL", "Fire Tail", "firetail1.json");

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

        // Verify trait mappings
        assertEq(geneNFT.tokenTraitType(1), "BACK");
        assertEq(geneNFT.tokenTraitValue(1), "Dragon Wings");
        assertEq(geneNFT.tokenTraitType(2), "ARM");
        assertEq(geneNFT.tokenTraitValue(2), "Scaled Arms");
        assertEq(geneNFT.tokenTraitType(3), "TAIL");
        assertEq(geneNFT.tokenTraitValue(3), "Fire Tail");
    }

    function test_RevertWhen_MintToZeroAddress() external {
        vm.prank(owner);
        vm.expectRevert(GeneNFT.InvalidParameters.selector);
        geneNFT.mint(address(0), "BACK", "Dragon Wings", "dragonwings1.json");
    }

    function test_RevertWhen_MintWithEmptyTraitType() external {
        vm.prank(owner);
        vm.expectRevert(GeneNFT.InvalidParameters.selector);
        geneNFT.mint(user1, "", "Dragon Wings", "dragonwings1.json");
    }

    function test_RevertWhen_MintWithEmptyTraitValue() external {
        vm.prank(owner);
        vm.expectRevert(GeneNFT.InvalidParameters.selector);
        geneNFT.mint(user1, "BACK", "", "dragonwings1.json");
    }

    function test_RevertWhen_MintCalledByNonOwner() external {
        vm.prank(user1);
        vm.expectRevert();
        geneNFT.mint(user2, "BACK", "Dragon Wings", "dragonwings1.json");
    }

    function test_BatchMint() external {
        address[] memory recipients = new address[](3);
        recipients[0] = user1;
        recipients[1] = user2;
        recipients[2] = user1;

        string[] memory traitTypes = new string[](3);
        traitTypes[0] = "BACK";
        traitTypes[1] = "ARM";
        traitTypes[2] = "TAIL";

        string[] memory traitValues = new string[](3);
        traitValues[0] = "Dragon Wings";
        traitValues[1] = "Scaled Arms";
        traitValues[2] = "Fire Tail";

        string[] memory uris = new string[](3);
        uris[0] = "dragonwings1.json";
        uris[1] = "scaledarms1.json";
        uris[2] = "firetail1.json";

        vm.prank(owner);
        uint256[] memory tokenIds = geneNFT.batchMint(recipients, traitTypes, traitValues, uris);

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

        // Verify trait mappings
        assertEq(geneNFT.tokenTraitType(1), "BACK");
        assertEq(geneNFT.tokenTraitValue(1), "Dragon Wings");
        assertEq(geneNFT.tokenTraitType(2), "ARM");
        assertEq(geneNFT.tokenTraitValue(2), "Scaled Arms");
        assertEq(geneNFT.tokenTraitType(3), "TAIL");
        assertEq(geneNFT.tokenTraitValue(3), "Fire Tail");
    }

    function test_RevertWhen_BatchMintWithMismatchedArrays() external {
        address[] memory recipients = new address[](2);
        recipients[0] = user1;
        recipients[1] = user2;

        string[] memory traitTypes = new string[](3);
        traitTypes[0] = "BACK";
        traitTypes[1] = "ARM";
        traitTypes[2] = "TAIL";

        string[] memory traitValues = new string[](2);
        traitValues[0] = "Dragon Wings";
        traitValues[1] = "Scaled Arms";

        string[] memory uris = new string[](2);
        uris[0] = "dragonwings1.json";
        uris[1] = "scaledarms1.json";

        vm.prank(owner);
        vm.expectRevert(GeneNFT.InvalidParameters.selector);
        geneNFT.batchMint(recipients, traitTypes, traitValues, uris);
    }

    function test_RevertWhen_BatchMintWithEmptyArrays() external {
        address[] memory recipients = new address[](0);
        string[] memory traitTypes = new string[](0);
        string[] memory traitValues = new string[](0);
        string[] memory uris = new string[](0);

        vm.prank(owner);
        vm.expectRevert(GeneNFT.InvalidParameters.selector);
        geneNFT.batchMint(recipients, traitTypes, traitValues, uris);
    }

    function test_RevertWhen_BatchMintWithZeroAddress() external {
        address[] memory recipients = new address[](2);
        recipients[0] = user1;
        recipients[1] = address(0);

        string[] memory traitTypes = new string[](2);
        traitTypes[0] = "BACK";
        traitTypes[1] = "ARM";

        string[] memory traitValues = new string[](2);
        traitValues[0] = "Dragon Wings";
        traitValues[1] = "Scaled Arms";

        string[] memory uris = new string[](2);
        uris[0] = "dragonwings1.json";
        uris[1] = "scaledarms1.json";

        vm.prank(owner);
        vm.expectRevert(GeneNFT.InvalidParameters.selector);
        geneNFT.batchMint(recipients, traitTypes, traitValues, uris);
    }

    function test_GetTokenTraits() external {
        vm.prank(owner);
        uint256 tokenId = geneNFT.mint(user1, "BACK", "Dragon Wings", "dragonwings1.json");

        (string memory traitType, string memory traitValue) = geneNFT.getTokenTraits(tokenId);
        assertEq(traitType, "BACK");
        assertEq(traitValue, "Dragon Wings");
    }

    function test_RevertWhen_GetTraitsForNonexistentToken() external {
        vm.expectRevert(GeneNFT.InvalidParameters.selector);
        geneNFT.getTokenTraits(999);
    }

    function test_GetTokensByTraitType() external {
        vm.startPrank(owner);
        geneNFT.mint(user1, "BACK", "Dragon Wings", "dragonwings1.json");
        geneNFT.mint(user2, "ARM", "Scaled Arms", "scaledarms1.json");
        geneNFT.mint(user1, "BACK", "Angel Wings", "angelwings1.json");
        geneNFT.mint(user2, "TAIL", "Fire Tail", "firetail1.json");
        vm.stopPrank();

        uint256[] memory backTokens = geneNFT.getTokensByTraitType("BACK");
        assertEq(backTokens.length, 2);
        assertEq(backTokens[0], 1);
        assertEq(backTokens[1], 3);

        uint256[] memory armTokens = geneNFT.getTokensByTraitType("ARM");
        assertEq(armTokens.length, 1);
        assertEq(armTokens[0], 2);

        uint256[] memory tailTokens = geneNFT.getTokensByTraitType("TAIL");
        assertEq(tailTokens.length, 1);
        assertEq(tailTokens[0], 4);

        uint256[] memory noTokens = geneNFT.getTokensByTraitType("NONEXISTENT");
        assertEq(noTokens.length, 0);
    }

    function test_GetTokensByTraitValue() external {
        vm.startPrank(owner);
        geneNFT.mint(user1, "BACK", "Dragon Wings", "dragonwings1.json");
        geneNFT.mint(user2, "ARM", "Scaled Arms", "scaledarms1.json");
        geneNFT.mint(user1, "TAIL", "Dragon Wings", "dragonwings2.json"); // Same value different type
        geneNFT.mint(user2, "BACK", "Angel Wings", "angelwings1.json");
        vm.stopPrank();

        uint256[] memory dragonWingsTokens = geneNFT.getTokensByTraitValue("Dragon Wings");
        assertEq(dragonWingsTokens.length, 2);
        assertEq(dragonWingsTokens[0], 1);
        assertEq(dragonWingsTokens[1], 3);

        uint256[] memory scaledArmsTokens = geneNFT.getTokensByTraitValue("Scaled Arms");
        assertEq(scaledArmsTokens.length, 1);
        assertEq(scaledArmsTokens[0], 2);

        uint256[] memory angelWingsTokens = geneNFT.getTokensByTraitValue("Angel Wings");
        assertEq(angelWingsTokens.length, 1);
        assertEq(angelWingsTokens[0], 4);

        uint256[] memory noTokens = geneNFT.getTokensByTraitValue("Nonexistent");
        assertEq(noTokens.length, 0);
    }

    function test_SetBaseURI() external {
        string memory newBaseURI = "https://newapi.aminals.com/genes/";

        vm.prank(owner);
        vm.expectEmit(false, false, false, true);
        emit BaseURIUpdated(newBaseURI);

        geneNFT.setBaseURI(newBaseURI);

        // Mint a token to test the new base URI
        vm.prank(owner);
        uint256 tokenId = geneNFT.mint(user1, "BACK", "Dragon Wings", "dragonwings1.json");

        assertEq(geneNFT.tokenURI(tokenId), string(abi.encodePacked(newBaseURI, "dragonwings1.json")));
    }

    function test_RevertWhen_SetBaseURICalledByNonOwner() external {
        vm.prank(user1);
        vm.expectRevert();
        geneNFT.setBaseURI("https://newapi.aminals.com/genes/");
    }

    function test_TokenTransfer() external {
        vm.prank(owner);
        uint256 tokenId = geneNFT.mint(user1, "BACK", "Dragon Wings", "dragonwings1.json");

        vm.prank(user1);
        geneNFT.transferFrom(user1, user2, tokenId);

        assertEq(geneNFT.ownerOf(tokenId), user2);
        assertEq(geneNFT.balanceOf(user1), 0);
        assertEq(geneNFT.balanceOf(user2), 1);

        // Verify trait mappings remain unchanged after transfer
        assertEq(geneNFT.tokenTraitType(tokenId), "BACK");
        assertEq(geneNFT.tokenTraitValue(tokenId), "Dragon Wings");
    }

    function test_TokenEnumeration() external {
        vm.startPrank(owner);
        geneNFT.mint(user1, "BACK", "Dragon Wings", "dragonwings1.json");
        geneNFT.mint(user2, "ARM", "Scaled Arms", "scaledarms1.json");
        geneNFT.mint(user1, "TAIL", "Fire Tail", "firetail1.json");
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

        vm.prank(owner);
        uint256 tokenId = geneNFT.mint(user1, "BACK", "Dragon Wings", "dragonwings1.json");

        // Verify public variables updated
        assertEq(geneNFT.currentTokenId(), 1);
        assertEq(geneNFT.tokenTraitType(tokenId), "BACK");
        assertEq(geneNFT.tokenTraitValue(tokenId), "Dragon Wings");
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

    function testFuzz_Mint(address to, string memory traitType, string memory traitValue, string memory tokenURI)
        external
    {
        vm.assume(to != address(0));
        vm.assume(bytes(traitType).length > 0);
        vm.assume(bytes(traitValue).length > 0);
        vm.assume(bytes(tokenURI).length > 0);

        vm.prank(owner);
        uint256 tokenId = geneNFT.mint(to, traitType, traitValue, tokenURI);

        assertEq(geneNFT.ownerOf(tokenId), to);
        assertEq(geneNFT.totalSupply(), 1);
        assertEq(geneNFT.currentTokenId(), 1);
        assertEq(geneNFT.tokenTraitType(tokenId), traitType);
        assertEq(geneNFT.tokenTraitValue(tokenId), traitValue);
    }

    function testFuzz_SetBaseURI(string memory newBaseURI) external {
        vm.prank(owner);
        geneNFT.setBaseURI(newBaseURI);

        vm.prank(owner);
        uint256 tokenId = geneNFT.mint(user1, "BACK", "Dragon Wings", "test.json");

        assertEq(geneNFT.tokenURI(tokenId), string(abi.encodePacked(newBaseURI, "test.json")));
    }
}
