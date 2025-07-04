// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {AminalRenderer} from "src/AminalRenderer.sol";
import {Aminal} from "src/Aminal.sol";
import {GeneNFT} from "src/GeneNFT.sol";
import {ITraits} from "src/interfaces/ITraits.sol";

contract AminalRendererTest is Test {
    AminalRenderer public renderer;
    GeneNFT public geneNFT;
    address public owner = address(0x1);
    address public user = address(0x2);
    
    // Gene SVGs
    string constant DRAGON_WINGS = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="-100 -100 200 200"><path d="M-50,-30 Q-80,-50 -90,-30 L-70,-10 Q-60,-20 -50,-30" fill="#8B4513"/><path d="M50,-30 Q80,-50 90,-30 L70,-10 Q60,-20 50,-30" fill="#8B4513"/></svg>';
    string constant FIRE_TAIL = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="-50 0 100 100"><path d="M0,30 Q-10,50 0,70 Q10,50 0,30" fill="#FF4500"/></svg>';
    
    function setUp() public {
        renderer = new AminalRenderer();
        vm.startPrank(owner);
        geneNFT = new GeneNFT(owner, "Test Genes", "GENE", "");
        vm.stopPrank();
    }
    
    function test_RenderAminalWithGenes() public {
        vm.startPrank(user);
        
        // Mint some genes
        uint256 wingsId = geneNFT.mint(user, "back", "Dragon Wings", DRAGON_WINGS, "Majestic dragon wings");
        uint256 tailId = geneNFT.mint(user, "tail", "Fire Tail", FIRE_TAIL, "A blazing fire tail");
        
        // Create an Aminal
        ITraits.Traits memory traits = ITraits.Traits({
            back: "Dragon Wings",
            arm: "",
            tail: "Fire Tail",
            ears: "",
            body: "",
            face: "",
            mouth: "",
            misc: ""
        });
        
        Aminal aminal = new Aminal(
            "Test Dragon",
            "DRAGON",
            "",
            traits
        );
        
        // Initialize with genes
        Aminal.GeneReference[8] memory genes;
        genes[0] = Aminal.GeneReference(address(geneNFT), wingsId);
        genes[2] = Aminal.GeneReference(address(geneNFT), tailId);
        
        aminal.initialize("", genes);
        
        // Test rendering
        string memory uri = renderer.tokenURI(aminal, 1);
        console.log("Aminal Token URI:");
        console.log(uri);
        
        assertTrue(bytes(uri).length > 0);
        
        // Test compose function
        string memory svg = renderer.composeAminal(aminal);
        console.log("Composed SVG:");
        console.log(svg);
        
        assertTrue(bytes(svg).length > 0);
        
        vm.stopPrank();
    }
    
    function test_PreviewComposition() public {
        vm.startPrank(user);
        
        // Mint genes
        uint256 wingsId = geneNFT.mint(user, "back", "Dragon Wings", DRAGON_WINGS, "Majestic dragon wings");
        
        // Create gene reference array for preview
        Aminal.GeneReference[8] memory genes;
        genes[0] = Aminal.GeneReference(address(geneNFT), wingsId);
        
        // Preview without deploying an Aminal
        string memory preview = renderer.previewComposition(genes);
        console.log("Preview SVG:");
        console.log(preview);
        
        assertTrue(bytes(preview).length > 0);
        
        vm.stopPrank();
    }
}