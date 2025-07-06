// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {Aminal} from "../src/Aminal.sol";
import {Gene} from "../src/Gene.sol";
import {AminalRenderer} from "../src/AminalRenderer.sol";
import {IGenes} from "../src/interfaces/IGenes.sol";
import {AminalTestBase} from "./base/AminalTestBase.sol";
import {TestHelpers} from "./helpers/TestHelpers.sol";

contract AminalPositioningTest is AminalTestBase {
    Gene public gene;
    
    // Implement IERC721Receiver to receive NFTs
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }
    
    function setUp() public override {
        super.setUp();
        
        // Deploy gene contract
        gene = new Gene(address(this), "Test Genes", "GENE", "https://example.com/");
    }
    
    function test_InitializeWithPositions() public {
        // Create genes
        uint256 bodyId = gene.mint(
            address(this),
            "body",
            "Normal Body",
            '<rect x="0" y="0" width="100" height="100" fill="blue"/>',
            "A normal body"
        );
        
        uint256 earsId = gene.mint(
            address(this),
            "ears",
            "Bunny Ears",
            '<ellipse cx="25" cy="25" rx="20" ry="40" fill="pink"/>',
            "Bunny ears"
        );
        
        // Create Aminal
        IGenes.Genes memory traits = TestHelpers.dragonTraits();
        Aminal testAminal = new Aminal("Positioned Dragon", "PDRG", traits, address(this));
        
        // Prepare gene references
        Aminal.GeneReference[8] memory geneRefs;
        geneRefs[4] = Aminal.GeneReference(address(gene), bodyId); // body
        geneRefs[3] = Aminal.GeneReference(address(gene), earsId); // ears
        
        // Prepare custom positions
        Aminal.GenePosition[8] memory positions;
        positions[0] = Aminal.GenePosition({x: -10, y: -10, width: 220, height: 220}); // back
        positions[1] = Aminal.GenePosition({x: 15, y: 75, width: 170, height: 50});    // arm
        positions[2] = Aminal.GenePosition({x: 110, y: 95, width: 70, height: 85});    // tail
        positions[3] = Aminal.GenePosition({x: 45, y: -15, width: 110, height: 70});   // ears
        positions[4] = Aminal.GenePosition({x: 40, y: 45, width: 120, height: 110});   // body
        positions[5] = Aminal.GenePosition({x: 55, y: 55, width: 90, height: 90});     // face
        positions[6] = Aminal.GenePosition({x: 65, y: 85, width: 70, height: 45});     // mouth
        positions[7] = Aminal.GenePosition({x: 0, y: 0, width: 200, height: 200});     // misc
        
        // Initialize with positions
        testAminal.initializeWithPositions("", geneRefs, positions);
        
        // Verify positions were set correctly
        (int16 x, int16 y, uint16 width, uint16 height) = testAminal.genePositions(testAminal.GENE_BODY());
        assertEq(x, 40);
        assertEq(y, 45);
        assertEq(width, 120);
        assertEq(height, 110);
        
        (x, y, width, height) = testAminal.genePositions(testAminal.GENE_EARS());
        assertEq(x, 45);
        assertEq(y, -15);
        assertEq(width, 110);
        assertEq(height, 70);
    }
    
    function test_RendererUsesStoredPositions() public {
        // Create genes
        uint256 bodyId = gene.mint(
            address(this),
            "body",
            "Wide Body",
            '<rect x="0" y="0" width="100" height="100" fill="green"/>',
            "A wide body"
        );
        
        // Create Aminal with traits that would normally trigger positioning adjustments
        IGenes.Genes memory traits = IGenes.Genes({
            back: "",
            arm: "",
            tail: "",
            ears: "",
            body: "Wide Chubby Body", // Would normally trigger wide positioning
            face: "",
            mouth: "",
            misc: ""
        });
        
        Aminal testAminal = new Aminal("Custom Pos", "CPOS", traits, address(this));
        
        // Prepare gene references
        Aminal.GeneReference[8] memory geneRefs;
        geneRefs[4] = Aminal.GeneReference(address(gene), bodyId);
        
        // Set custom positions that override trait-based positioning
        Aminal.GenePosition[8] memory positions;
        positions[4] = Aminal.GenePosition({x: 25, y: 30, width: 150, height: 140}); // Custom body position
        
        // Initialize with custom positions
        testAminal.initializeWithPositions("", geneRefs, positions);
        
        // Get composed SVG
        string memory svg = testAminal.renderer().composeAminal(testAminal);
        
        // Verify our custom position is used (25, 30, 150, 140)
        // instead of the default wide body position (40, 50, 120, 100)
        assertTrue(_contains(svg, 'x="25"'));
        assertTrue(_contains(svg, 'y="30"'));
        assertTrue(_contains(svg, 'width="150"'));
        assertTrue(_contains(svg, 'height="140"'));
    }
    
    function test_FallbackToTraitBasedPositioning() public {
        // Create Aminal without setting positions
        IGenes.Genes memory traits = IGenes.Genes({
            back: "",
            arm: "",
            tail: "",
            ears: "",
            body: "Tall Slim Body",
            face: "",
            mouth: "",
            misc: ""
        });
        
        Aminal testAminal = new Aminal("Trait Based", "TBASE", traits, address(this));
        
        // Initialize without positions
        Aminal.GeneReference[8] memory emptyGeneRefs;
        testAminal.initialize("", emptyGeneRefs);
        
        // Verify no positions are set (width = 0)
        (,,uint16 width,) = testAminal.genePositions(testAminal.GENE_BODY());
        assertEq(width, 0);
        
        // The renderer should use trait-based positioning for tall bodies
        // This would be tested more thoroughly with actual rendering
    }
    
    function testFuzz_GenePositions(
        int16 x,
        int16 y,
        uint16 width,
        uint16 height
    ) public {
        vm.assume(width > 0 && width <= 1000);
        vm.assume(height > 0 && height <= 1000);
        vm.assume(x >= -500 && x <= 500);
        vm.assume(y >= -500 && y <= 500);
        
        // Create Aminal
        Aminal testAminal = _createAminal("Fuzz Test", "FUZZ", TestHelpers.dragonTraits());
        
        // Create position array with fuzzed values
        Aminal.GenePosition[8] memory positions;
        positions[4] = Aminal.GenePosition({x: x, y: y, width: width, height: height});
        
        // Initialize with positions
        Aminal.GeneReference[8] memory emptyGeneRefs;
        testAminal.initializeWithPositions("", emptyGeneRefs, positions);
        
        // Verify position was stored correctly
        (int16 storedX, int16 storedY, uint16 storedWidth, uint16 storedHeight) = 
            testAminal.genePositions(testAminal.GENE_BODY());
            
        assertEq(storedX, x);
        assertEq(storedY, y);
        assertEq(storedWidth, width);
        assertEq(storedHeight, height);
    }
    
    function _contains(string memory str, string memory substr) private pure returns (bool) {
        bytes memory strBytes = bytes(str);
        bytes memory substrBytes = bytes(substr);
        
        if (substrBytes.length > strBytes.length) return false;
        
        for (uint i = 0; i <= strBytes.length - substrBytes.length; i++) {
            bool found = true;
            for (uint j = 0; j < substrBytes.length; j++) {
                if (strBytes[i + j] != substrBytes[j]) {
                    found = false;
                    break;
                }
            }
            if (found) return true;
        }
        return false;
    }
}