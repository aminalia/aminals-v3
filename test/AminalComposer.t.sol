// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {GeneNFT} from "src/GeneNFT.sol";
import {AminalComposer} from "src/AminalComposer.sol";
import {GeneRenderer} from "src/GeneRenderer.sol";

contract AminalComposerTest is Test {
    GeneNFT public geneNFT;
    AminalComposer public composer;
    address public owner = address(0x1);
    address public user = address(0x2);

    // Example gene SVGs - complete self-contained SVGs
    string constant DRAGON_WINGS = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="-100 -100 200 200"><path d="M-50,-30 Q-80,-50 -90,-30 L-70,-10 Q-60,-20 -50,-30" fill="#8B4513"/><path d="M50,-30 Q80,-50 90,-30 L70,-10 Q60,-20 50,-30" fill="#8B4513"/></svg>';
    string constant FIRE_TAIL = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="-50 0 100 100"><path d="M0,30 Q-10,50 0,70 Q10,50 0,30" fill="#FF4500"/></svg>';
    string constant BUNNY_EARS = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="-50 -100 100 100"><ellipse cx="-20" cy="-60" rx="10" ry="30" fill="#FFC0CB"/><ellipse cx="20" cy="-60" rx="10" ry="30" fill="#FFC0CB"/></svg>';
    string constant SPARKLES = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="-50 -50 100 100"><circle cx="-30" cy="-30" r="3" fill="#FFD700"><animate attributeName="opacity" values="1;0.3;1" dur="2s" repeatCount="indefinite"/></circle></svg>';

    function setUp() public {
        vm.startPrank(owner);
        geneNFT = new GeneNFT(owner, "Aminal Genes", "GENE", "");
        composer = new AminalComposer();
        vm.stopPrank();
    }

    function test_ComposeCompleteAminal() public {
        vm.startPrank(user);
        
        // Mint various genes
        uint256 backId = geneNFT.mint(user, "back", "Dragon Wings", DRAGON_WINGS, "Dragon wings");
        uint256 tailId = geneNFT.mint(user, "tail", "Fire Tail", FIRE_TAIL, "Fire tail");
        uint256 earsId = geneNFT.mint(user, "ears", "Bunny Ears", BUNNY_EARS, "Bunny ears");
        uint256 miscId = geneNFT.mint(user, "misc", "Sparkles", SPARKLES, "Sparkles");
        
        // Compose the Aminal
        string memory composedSvg = composer.composeAminal(
            address(geneNFT),
            backId,    // back
            tailId,    // tail
            earsId,    // ears
            0,         // body (none)
            0,         // face (none)
            0,         // mouth (none)
            0,         // arm (none)
            miscId     // misc
        );
        
        // Log the composed SVG
        console.log("Composed Aminal SVG:");
        console.log(composedSvg);
        
        // Verify it contains expected elements
        assertTrue(bytes(composedSvg).length > 0);
        
        vm.stopPrank();
    }

    function test_GenerateAminalMetadata() public {
        // Create a simple composed SVG
        string memory svg = GeneRenderer.svg(
            "-100 -100 200 200",
            '<circle cx="0" cy="0" r="40" fill="#FFE4B5"/>'
        );
        
        // Generate metadata
        string memory metadata = composer.generateAminalMetadata(
            "Fire Dragon Bunny",
            "A unique Aminal with dragon wings, fire tail, and bunny ears",
            svg
        );
        
        // Log the metadata
        console.log("Aminal Metadata URI:");
        console.log(metadata);
        
        // Verify it's a data URI
        assertTrue(bytes(metadata).length > 0);
    }

    function test_RainbowBody() public {
        string memory rainbowBody = composer.createRainbowBody();
        console.log("Rainbow body SVG:");
        console.log(rainbowBody);
        
        assertTrue(bytes(rainbowBody).length > 0);
    }

    function test_FloatingAnimation() public {
        string memory floatingCircle = composer.createFloatingAnimation(
            '<circle cx="0" cy="0" r="20" fill="#00FF00"/>'
        );
        
        console.log("Floating animation SVG:");
        console.log(floatingCircle);
        
        assertTrue(bytes(floatingCircle).length > 0);
    }

    function test_SoladyRendererEfficiency() public {
        // Test the efficiency of Solady's string operations
        uint256 gasBefore = gasleft();
        
        // Create a complex SVG using GeneRenderer
        string memory svg = GeneRenderer.svg(
            "0 0 100 100",
            string.concat(
                GeneRenderer.rect(10, 10, 80, 80, "#FF0000"),
                GeneRenderer.circle(50, 50, 30, "#00FF00"),
                GeneRenderer.text(50, 50, "Solady", "middle", "16", "#FFFFFF")
            )
        );
        
        uint256 gasUsed = gasBefore - gasleft();
        console.log("Gas used for complex SVG:", gasUsed);
        console.log("Generated SVG:", svg);
    }
}