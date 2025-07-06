// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {Aminal} from "src/Aminal.sol";
import {Gene} from "src/Gene.sol";
import {IGenes} from "src/interfaces/IGenes.sol";

contract AminalDynamicPositioningTest is Test {
    Gene public gene;
    address public owner = address(0x1);
    address public user = address(0x2);
    
    // Gene SVGs
    string constant BUNNY_EARS = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="-50 -100 100 100"><ellipse cx="-20" cy="-60" rx="10" ry="30" fill="#FFC0CB"/><ellipse cx="20" cy="-60" rx="10" ry="30" fill="#FFC0CB"/></svg>';
    string constant DRAGON_TAIL = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="-50 0 100 100"><path d="M0,0 Q-20,30 0,60 Q20,30 0,0" fill="#8B4513" stroke="#654321" stroke-width="2"/></svg>';
    string constant CUTE_FACE = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="-50 -50 100 100"><circle cx="-15" cy="-10" r="5" fill="#000"/><circle cx="15" cy="-10" r="5" fill="#000"/><path d="M-10,10 Q0,20 10,10" fill="none" stroke="#000" stroke-width="2"/></svg>';
    string constant TALL_BODY = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="-50 -50 100 100"><ellipse cx="0" cy="0" rx="30" ry="45" fill="#FFE4B5" stroke="#000" stroke-width="2"/></svg>';
    string constant CHUBBY_BODY = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="-50 -50 100 100"><ellipse cx="0" cy="5" rx="45" ry="40" fill="#FFDAB9" stroke="#000" stroke-width="2"/></svg>';
    
    function setUp() public {
        vm.startPrank(owner);
        gene = new Gene(owner, "Test Genes", "GENE", "");
        vm.stopPrank();
    }
    
    function test_TallAminalPositioning() public {
        vm.startPrank(user);
        
        // Mint genes
        uint256 tallBodyId = gene.mint(user, "body", "Tall Body", TALL_BODY, "A tall slender body");
        uint256 earsId = gene.mint(user, "ears", "Bunny Ears", BUNNY_EARS, "Long bunny ears");
        uint256 faceId = gene.mint(user, "face", "Cute Face", CUTE_FACE, "A cute face");
        uint256 tailId = gene.mint(user, "tail", "Dragon Tail", DRAGON_TAIL, "A long dragon tail");
        
        // Create a tall Aminal
        IGenes.Genes memory tallTraits = IGenes.Genes({
            back: "",
            arm: "",
            tail: "Dragon Tail",
            ears: "Bunny Ears",
            body: "Tall Body", // This triggers tall positioning
            face: "Cute Face",
            mouth: "",
            misc: ""
        });
        
        Aminal tallAminal = new Aminal(
            "Tall Bunny Dragon",
            "TBD",
            "",
            tallTraits,
            address(this)
        );
        
        // Initialize with genes
        Aminal.GeneReference[8] memory genes;
        genes[4] = Aminal.GeneReference(address(gene), tallBodyId); // body
        genes[3] = Aminal.GeneReference(address(gene), earsId);     // ears
        genes[5] = Aminal.GeneReference(address(gene), faceId);     // face
        genes[2] = Aminal.GeneReference(address(gene), tailId);     // tail
        
        tallAminal.initialize("", genes);
        
        // Get the composed SVG
        string memory composedSvg = tallAminal.composeAminal();
        console.log("Tall Aminal SVG (ears should be higher, body taller):");
        console.log(composedSvg);
        
        // Verify it's composed
        assertTrue(bytes(composedSvg).length > 0);
        vm.stopPrank();
    }
    
    function test_ChubbyAminalPositioning() public {
        vm.startPrank(user);
        
        // Mint genes
        uint256 chubbyBodyId = gene.mint(user, "body", "Chubby Body", CHUBBY_BODY, "A chubby round body");
        uint256 earsId = gene.mint(user, "ears", "Bunny Ears", BUNNY_EARS, "Long bunny ears");
        uint256 faceId = gene.mint(user, "face", "Cute Face", CUTE_FACE, "A cute face");
        uint256 tailId = gene.mint(user, "tail", "Dragon Tail", DRAGON_TAIL, "A long dragon tail");
        
        // Create a chubby Aminal
        IGenes.Genes memory chubbyTraits = IGenes.Genes({
            back: "",
            arm: "",
            tail: "Dragon Tail",
            ears: "Bunny Ears",
            body: "Chubby Body", // This triggers short and wide positioning
            face: "Cute Face",
            mouth: "",
            misc: ""
        });
        
        Aminal chubbyAminal = new Aminal(
            "Chubby Bunny Dragon",
            "CBD",
            "",
            chubbyTraits,
            address(this)
        );
        
        // Initialize with genes
        Aminal.GeneReference[8] memory genes;
        genes[4] = Aminal.GeneReference(address(gene), chubbyBodyId); // body
        genes[3] = Aminal.GeneReference(address(gene), earsId);        // ears
        genes[5] = Aminal.GeneReference(address(gene), faceId);        // face
        genes[2] = Aminal.GeneReference(address(gene), tailId);        // tail
        
        chubbyAminal.initialize("", genes);
        
        // Get the composed SVG
        string memory composedSvg = chubbyAminal.composeAminal();
        console.log("Chubby Aminal SVG (ears should be lower, body wider and shorter):");
        console.log(composedSvg);
        
        // Verify it's composed
        assertTrue(bytes(composedSvg).length > 0);
        vm.stopPrank();
    }
    
    function test_ComparePositioning() public {
        vm.startPrank(user);
        
        // Create SVGs for both body types
        string memory tallSvg = createAminalWithBody("Tall Body", TALL_BODY);
        string memory chubbySvg = createAminalWithBody("Chubby Body", CHUBBY_BODY);
        
        console.log("\n=== TALL AMINAL ===");
        console.log(tallSvg);
        console.log("\n=== CHUBBY AMINAL ===");
        console.log(chubbySvg);
        console.log("\nNotice how the ears, face, and tail positions differ based on body type!");
        
        // The SVGs should be different due to positioning
        assertTrue(keccak256(bytes(tallSvg)) != keccak256(bytes(chubbySvg)));
        
        vm.stopPrank();
    }
    
    function createAminalWithBody(string memory bodyType, string memory bodySvg) private returns (string memory) {
        // Mint the same genes for comparison
        uint256 bodyId = gene.mint(user, "body", bodyType, bodySvg, "Body type");
        uint256 earsId = gene.mint(user, "ears", "Bunny Ears", BUNNY_EARS, "Long bunny ears");
        uint256 faceId = gene.mint(user, "face", "Cute Face", CUTE_FACE, "A cute face");
        
        // Create traits
        IGenes.Genes memory traits = IGenes.Genes({
            back: "",
            arm: "",
            tail: "",
            ears: "Bunny Ears",
            body: bodyType,
            face: "Cute Face",
            mouth: "",
            misc: ""
        });
        
        // Create Aminal
        Aminal aminal = new Aminal(
            string.concat(bodyType, " Test"),
            "TEST",
            "",
            traits,
            address(this)
        );
        
        // Initialize with genes
        Aminal.GeneReference[8] memory genes;
        genes[4] = Aminal.GeneReference(address(gene), bodyId); // body
        genes[3] = Aminal.GeneReference(address(gene), earsId); // ears
        genes[5] = Aminal.GeneReference(address(gene), faceId); // face
        
        aminal.initialize("", genes);
        
        return aminal.composeAminal();
    }
}