// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {Gene} from "src/Gene.sol";
import {GeneRenderer} from "src/GeneRenderer.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";

contract GeneTest is Test {
    using Strings for uint256;

    Gene public gene;
    address public owner = address(0x1);
    address public user1 = address(0x2);
    address public user2 = address(0x3);

    // Example SVG components for different trait types - complete self-contained SVGs
    string constant DRAGON_WINGS_SVG = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="-100 -100 200 200"><path d="M-50,-30 Q-80,-50 -90,-30 L-70,-10 Q-60,-20 -50,-30" fill="#8B4513" stroke="#000" stroke-width="2"/><path d="M50,-30 Q80,-50 90,-30 L70,-10 Q60,-20 50,-30" fill="#8B4513" stroke="#000" stroke-width="2"/></svg>';
    string constant FIRE_TAIL_SVG = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="-50 0 100 100"><path d="M0,30 Q-10,50 0,70 Q10,50 0,30" fill="#FF4500" stroke="#FF0000" stroke-width="2"/><path d="M0,40 Q-5,50 0,60 Q5,50 0,40" fill="#FFA500" stroke="#FF4500" stroke-width="1"/></svg>';
    string constant BUNNY_EARS_SVG = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="-50 -100 100 100"><ellipse cx="-20" cy="-60" rx="10" ry="30" fill="#FFC0CB" stroke="#000" stroke-width="2"/><ellipse cx="20" cy="-60" rx="10" ry="30" fill="#FFC0CB" stroke="#000" stroke-width="2"/></svg>';
    string constant SPARKLE_MISC_SVG = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="-50 -50 100 100"><circle cx="-30" cy="-30" r="3" fill="#FFD700"><animate attributeName="opacity" values="1;0.3;1" dur="2s" repeatCount="indefinite"/></circle><circle cx="30" cy="-30" r="3" fill="#FFD700"><animate attributeName="opacity" values="0.3;1;0.3" dur="2s" repeatCount="indefinite"/></circle></svg>';

    function setUp() public {
        vm.startPrank(owner);
        gene = new Gene(owner, "Aminal Genes", "GENE", "");
        vm.stopPrank();
    }

    function test_Deployment() public {
        assertEq(gene.name(), "Aminal Genes");
        assertEq(gene.symbol(), "GENE");
        assertEq(gene.owner(), owner);
        assertEq(gene.currentTokenId(), 0);
    }

    function test_MintGene() public {
        vm.startPrank(user1);
        
        uint256 tokenId = gene.mint(
            user1,
            "back",
            "Dragon Wings",
            DRAGON_WINGS_SVG,
            "Majestic dragon wings that grant the power of flight"
        );
        
        assertEq(tokenId, 1);
        assertEq(gene.ownerOf(tokenId), user1);
        assertEq(gene.currentTokenId(), 1);
        
        // Check gene data
        (string memory traitType, string memory traitValue, string memory svg, string memory description) = gene.getTokenTraits(tokenId);
        assertEq(traitType, "back");
        assertEq(traitValue, "Dragon Wings");
        assertEq(svg, DRAGON_WINGS_SVG);
        assertEq(description, "Majestic dragon wings that grant the power of flight");
        
        vm.stopPrank();
    }

    function test_GetRawGene() public {
        vm.startPrank(user1);
        
        uint256 tokenId = gene.mint(
            user1,
            "tail",
            "Fire Tail",
            FIRE_TAIL_SVG,
            "A tail made of pure fire that leaves a trail of embers"
        );
        
        // Test the raw gene getter (for composability)
        string memory rawSvg = gene.gene(tokenId);
        assertEq(rawSvg, FIRE_TAIL_SVG);
        
        vm.stopPrank();
    }

    function test_GenerateStandaloneSVG() public {
        vm.startPrank(user1);
        
        uint256 tokenId = gene.mint(
            user1,
            "ears",
            "Bunny Ears",
            BUNNY_EARS_SVG,
            "Soft, fluffy bunny ears that twitch with emotion"
        );
        
        string memory standaloneSvg = gene.generateStandaloneSVG(tokenId);
        
        // Check that it contains the wrapper elements
        assertTrue(bytes(standaloneSvg).length > 0);
        // Would contain: <svg>, background rect, title text, and the gene SVG
        
        vm.stopPrank();
    }

    function test_TokenURI() public {
        vm.startPrank(user1);
        
        uint256 tokenId = gene.mint(
            user1,
            "misc",
            "Sparkles",
            SPARKLE_MISC_SVG,
            "Magical sparkles that follow the Aminal wherever it goes"
        );
        
        string memory uri = gene.tokenURI(tokenId);
        
        // Check that it's a data URI
        assertTrue(bytes(uri).length > 0);
        // Should start with "data:application/json;base64,"
        
        // Log the URI for manual inspection
        console.log("Token URI:", uri);
        
        vm.stopPrank();
    }

    function test_MultipleGenes() public {
        vm.startPrank(user1);
        
        // Mint multiple genes
        uint256 token1 = gene.mint(user1, "back", "Dragon Wings", DRAGON_WINGS_SVG, "Dragon wings");
        uint256 token2 = gene.mint(user1, "tail", "Fire Tail", FIRE_TAIL_SVG, "Fire tail");
        uint256 token3 = gene.mint(user1, "ears", "Bunny Ears", BUNNY_EARS_SVG, "Bunny ears");
        
        assertEq(gene.balanceOf(user1), 3);
        assertEq(token1, 1);
        assertEq(token2, 2);
        assertEq(token3, 3);
        
        vm.stopPrank();
    }

    function test_GetTokensByTraitType() public {
        // Mint various genes
        vm.prank(user1);
        gene.mint(user1, "back", "Dragon Wings", DRAGON_WINGS_SVG, "desc1");
        
        vm.prank(user2);
        gene.mint(user2, "tail", "Fire Tail", FIRE_TAIL_SVG, "desc2");
        
        vm.prank(user1);
        gene.mint(user1, "back", "Angel Wings", "<path/>", "desc3");
        
        // Get all "back" trait tokens
        uint256[] memory backTokens = gene.getTokensByTraitType("back");
        assertEq(backTokens.length, 2);
        assertEq(backTokens[0], 1);
        assertEq(backTokens[1], 3);
        
        // Get all "tail" trait tokens
        uint256[] memory tailTokens = gene.getTokensByTraitType("tail");
        assertEq(tailTokens.length, 1);
        assertEq(tailTokens[0], 2);
    }

    function test_GetTokensByTraitValue() public {
        // Mint various genes
        vm.prank(user1);
        gene.mint(user1, "back", "Dragon Wings", DRAGON_WINGS_SVG, "desc1");
        
        vm.prank(user2);
        gene.mint(user2, "back", "Dragon Wings", DRAGON_WINGS_SVG, "desc2");
        
        vm.prank(user1);
        gene.mint(user1, "tail", "Fire Tail", FIRE_TAIL_SVG, "desc3");
        
        // Get all "Dragon Wings" tokens
        uint256[] memory dragonWingTokens = gene.getTokensByTraitValue("Dragon Wings");
        assertEq(dragonWingTokens.length, 2);
        assertEq(dragonWingTokens[0], 1);
        assertEq(dragonWingTokens[1], 2);
    }

    function test_RevertWhen_MintingToZeroAddress() public {
        vm.expectRevert(Gene.InvalidParameters.selector);
        gene.mint(address(0), "back", "Wings", "<svg/>", "desc");
    }

    function test_RevertWhen_EmptyTraitType() public {
        vm.expectRevert(Gene.InvalidParameters.selector);
        gene.mint(user1, "", "Wings", "<svg/>", "desc");
    }

    function test_RevertWhen_EmptyTraitValue() public {
        vm.expectRevert(Gene.InvalidParameters.selector);
        gene.mint(user1, "back", "", "<svg/>", "desc");
    }

    function test_RevertWhen_EmptySVG() public {
        vm.expectRevert(Gene.InvalidParameters.selector);
        gene.mint(user1, "back", "Wings", "", "desc");
    }

    function testFuzz_MintMultipleGenes(uint8 count) public {
        vm.assume(count > 0 && count <= 50); // Reasonable bounds
        
        vm.startPrank(user1);
        
        for (uint i = 0; i < count; i++) {
            string memory traitType = string(abi.encodePacked("trait", i.toString()));
            string memory traitValue = string(abi.encodePacked("value", i.toString()));
            
            uint256 tokenId = gene.mint(
                user1,
                traitType,
                traitValue,
                "<circle r='5'/>",
                "Test gene"
            );
            
            assertEq(tokenId, i + 1);
        }
        
        assertEq(gene.balanceOf(user1), count);
        assertEq(gene.totalSupply(), count);
        
        vm.stopPrank();
    }

    function test_ComposabilityExample() public {
        // This test demonstrates how genes can be composed into a larger Aminal SVG
        vm.startPrank(user1);
        
        // Mint various trait genes
        uint256 backId = gene.mint(user1, "back", "Dragon Wings", DRAGON_WINGS_SVG, "Dragon wings");
        uint256 tailId = gene.mint(user1, "tail", "Fire Tail", FIRE_TAIL_SVG, "Fire tail");
        uint256 earsId = gene.mint(user1, "ears", "Bunny Ears", BUNNY_EARS_SVG, "Bunny ears");
        uint256 miscId = gene.mint(user1, "misc", "Sparkles", SPARKLE_MISC_SVG, "Sparkles");
        
        // Get raw SVG components
        string memory backSvg = gene.gene(backId);
        string memory tailSvg = gene.gene(tailId);
        string memory earsSvg = gene.gene(earsId);
        string memory miscSvg = gene.gene(miscId);
        
        // Compose into a full Aminal SVG using image tags
        string memory composedSvg = GeneRenderer.svg(
            "0 0 200 200",
            string.concat(
                // Body
                GeneRenderer.svgImage(50, 50, 100, 100, '<svg xmlns="http://www.w3.org/2000/svg" viewBox="-50 -50 100 100"><circle cx="0" cy="0" r="40" fill="#FFE4B5" stroke="#000" stroke-width="2"/></svg>'),
                // Back
                GeneRenderer.svgImage(0, 0, 200, 200, backSvg),
                // Tail
                GeneRenderer.svgImage(100, 100, 50, 50, tailSvg),
                // Ears
                GeneRenderer.svgImage(50, 0, 100, 50, earsSvg),
                // Misc
                GeneRenderer.svgImage(0, 0, 200, 200, miscSvg)
            )
        );
        
        // Log the composed SVG
        console.log("Composed Aminal SVG:");
        console.log(composedSvg);
        
        vm.stopPrank();
    }
}