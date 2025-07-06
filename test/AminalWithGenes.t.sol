// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {Aminal} from "src/Aminal.sol";
import {Gene} from "src/Gene.sol";
import {IGenes} from "src/interfaces/IGenes.sol";

contract AminalWithGenesTest is Test {
    Gene public gene;
    address public owner = address(0x1);
    address public user = address(0x2);
    
    // Gene SVGs
    string constant DRAGON_WINGS = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="-100 -100 200 200"><path d="M-50,-30 Q-80,-50 -90,-30 L-70,-10 Q-60,-20 -50,-30" fill="#8B4513"/><path d="M50,-30 Q80,-50 90,-30 L70,-10 Q60,-20 50,-30" fill="#8B4513"/></svg>';
    string constant FIRE_TAIL = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="-50 0 100 100"><path d="M0,30 Q-10,50 0,70 Q10,50 0,30" fill="#FF4500"/></svg>';
    string constant BUNNY_EARS = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="-50 -100 100 100"><ellipse cx="-20" cy="-60" rx="10" ry="30" fill="#FFC0CB"/><ellipse cx="20" cy="-60" rx="10" ry="30" fill="#FFC0CB"/></svg>';
    string constant SPARKLES = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="-50 -50 100 100"><circle cx="-30" cy="-30" r="3" fill="#FFD700"><animate attributeName="opacity" values="1;0.3;1" dur="2s" repeatCount="indefinite"/></circle></svg>';
    
    function setUp() public {
        vm.startPrank(owner);
        gene = new Gene(owner, "Test Genes", "GENE", "");
        vm.stopPrank();
    }
    
    function test_CreateAminalWithGenes() public {
        vm.startPrank(user);
        
        // First, mint some genes
        uint256 wingsId = gene.mint(user, "back", "Dragon Wings", DRAGON_WINGS, "Majestic dragon wings");
        uint256 tailId = gene.mint(user, "tail", "Fire Tail", FIRE_TAIL, "A blazing fire tail");
        uint256 earsId = gene.mint(user, "ears", "Bunny Ears", BUNNY_EARS, "Soft bunny ears");
        uint256 miscId = gene.mint(user, "misc", "Sparkles", SPARKLES, "Magical sparkles");
        
        // Create trait data for the Aminal
        IGenes.Genes memory traits = IGenes.Genes({
            back: "Dragon Wings",
            arm: "",
            tail: "Fire Tail",
            ears: "Bunny Ears",
            body: "",
            face: "",
            mouth: "",
            misc: "Sparkles"
        });
        
        // Deploy the Aminal
        Aminal aminal = new Aminal(
            "Fire Dragon Bunny",
            "FDB",
            traits,
            address(this)
        );
        
        // Create gene references
        Aminal.GeneReference[8] memory genes;
        genes[0] = Aminal.GeneReference(address(gene), wingsId);  // back
        genes[1] = Aminal.GeneReference(address(0), 0);              // arm
        genes[2] = Aminal.GeneReference(address(gene), tailId);   // tail
        genes[3] = Aminal.GeneReference(address(gene), earsId);   // ears
        genes[4] = Aminal.GeneReference(address(0), 0);              // body
        genes[5] = Aminal.GeneReference(address(0), 0);              // face
        genes[6] = Aminal.GeneReference(address(0), 0);              // mouth
        genes[7] = Aminal.GeneReference(address(gene), miscId);   // misc
        
        // Initialize the Aminal with its genes
        aminal.initialize("", genes);
        
        // Check that the Aminal is minted to itself
        assertEq(aminal.ownerOf(1), address(aminal));
        
        // Get the composed SVG
        string memory composedSvg = aminal.composeAminal();
        console.log("Composed Aminal SVG:");
        console.log(composedSvg);
        
        // Get the tokenURI
        string memory uri = aminal.tokenURI(1);
        console.log("Token URI:");
        console.log(uri);
        
        vm.stopPrank();
    }
    
    function test_AminalWithNoGenes() public {
        // Create an Aminal with no genes (will use default body)
        IGenes.Genes memory traits = IGenes.Genes({
            back: "",
            arm: "",
            tail: "",
            ears: "",
            body: "",
            face: "",
            mouth: "",
            misc: ""
        });
        
        Aminal aminal = new Aminal(
            "Plain Aminal",
            "PLAIN",
            traits,
            address(this)
        );
        
        // Initialize with empty gene references
        Aminal.GeneReference[8] memory emptyGenes;
        aminal.initialize("", emptyGenes);
        
        // Get the composed SVG (should show default body)
        string memory composedSvg = aminal.composeAminal();
        console.log("Plain Aminal SVG:");
        console.log(composedSvg);
        
        assertTrue(bytes(composedSvg).length > 0);
    }
    
    function test_AminalWithMissingGenes() public {
        vm.startPrank(user);
        
        // Only mint some genes, not all
        uint256 wingsId = gene.mint(user, "back", "Dragon Wings", DRAGON_WINGS, "Majestic dragon wings");
        uint256 earsId = gene.mint(user, "ears", "Bunny Ears", BUNNY_EARS, "Soft bunny ears");
        
        // Create trait data
        IGenes.Genes memory traits = IGenes.Genes({
            back: "Dragon Wings",
            arm: "",
            tail: "",
            ears: "Bunny Ears",
            body: "",
            face: "",
            mouth: "",
            misc: ""
        });
        
        // Deploy the Aminal
        Aminal aminal = new Aminal(
            "Partial Aminal",
            "PART",
            traits,
            address(this)
        );
        
        // Create gene references with only some genes
        Aminal.GeneReference[8] memory genes;
        genes[0] = Aminal.GeneReference(address(gene), wingsId);  // back
        genes[1] = Aminal.GeneReference(address(0), 0);              // arm
        genes[2] = Aminal.GeneReference(address(0), 0);              // tail
        genes[3] = Aminal.GeneReference(address(gene), earsId);   // ears
        genes[4] = Aminal.GeneReference(address(0), 0);              // body
        genes[5] = Aminal.GeneReference(address(0), 0);              // face
        genes[6] = Aminal.GeneReference(address(0), 0);              // mouth
        genes[7] = Aminal.GeneReference(address(0), 0);              // misc
        
        // Initialize
        aminal.initialize("", genes);
        
        // Should compose with default body and specified genes
        string memory composedSvg = aminal.composeAminal();
        console.log("Partial Aminal SVG:");
        console.log(composedSvg);
        
        assertTrue(bytes(composedSvg).length > 0);
        
        vm.stopPrank();
    }
}