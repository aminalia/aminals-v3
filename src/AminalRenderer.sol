// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Aminal} from "src/Aminal.sol";
import {GeneNFT} from "src/GeneNFT.sol";
import {GeneRenderer} from "src/GeneRenderer.sol";
import {ITraits} from "src/interfaces/ITraits.sol";
import {LibString} from "solady/utils/LibString.sol";
import {Base64} from "solady/utils/Base64.sol";

/**
 * @title AminalRenderer
 * @dev Handles rendering of Aminal NFT metadata and composed SVGs
 * @notice Separates rendering logic from the main Aminal contract
 */
contract AminalRenderer {
    using LibString for uint256;
    using LibString for string;
    
    /// @dev Structure to store positioning data for a trait
    struct Position {
        int256 x;
        int256 y;
        uint256 width;
        uint256 height;
    }
    
    /// @dev Structure to store all trait positions
    struct TraitPositions {
        Position back;
        Position body;
        Position tail;
        Position arm;
        Position ears;
        Position face;
        Position mouth;
        Position misc;
    }

    /**
     * @dev Generate complete tokenURI for an Aminal
     * @param aminal The Aminal contract to render
     * @param tokenId The token ID (always 1 for Aminals)
     * @return The complete data URI with metadata
     */
    function tokenURI(Aminal aminal, uint256 tokenId) external view returns (string memory) {
        require(tokenId == 1, "Invalid token ID");
        
        // Compose the Aminal SVG from its genes
        string memory composedSvg = aminal.composeAminal();
        string memory imageDataURI = GeneRenderer.svgToBase64DataURI(composedSvg);
        
        // Build the metadata
        string memory metadata = GeneRenderer.generateMetadata(
            aminal.name(),
            string.concat(
                "A self-sovereign Aminal with energy: ", 
                aminal.energy().toString(), 
                " and total love: ", 
                aminal.totalLove().toString()
            ),
            imageDataURI,
            "Aminal",
            "Self-Sovereign"
        );
        
        return GeneRenderer.jsonToBase64DataURI(metadata);
    }
    
    /**
     * @dev Compose the Aminal's appearance from its GeneNFTs
     * @param aminal The Aminal contract to compose
     * @return The composed SVG as a string
     */
    function composeAminal(Aminal aminal) public view returns (string memory) {
        // Get positioning based on this Aminal's traits
        TraitPositions memory positions = _getTraitPositions(aminal);
        
        string memory composition = "";
        
        // Get gene references from the Aminal (public getters return tuples)
        Aminal.GeneReference memory backGene;
        Aminal.GeneReference memory armGene;
        Aminal.GeneReference memory tailGene;
        Aminal.GeneReference memory earsGene;
        Aminal.GeneReference memory bodyGene;
        Aminal.GeneReference memory faceGene;
        Aminal.GeneReference memory mouthGene;
        Aminal.GeneReference memory miscGene;
        
        (backGene.geneContract, backGene.tokenId) = aminal.backGene();
        (armGene.geneContract, armGene.tokenId) = aminal.armGene();
        (tailGene.geneContract, tailGene.tokenId) = aminal.tailGene();
        (earsGene.geneContract, earsGene.tokenId) = aminal.earsGene();
        (bodyGene.geneContract, bodyGene.tokenId) = aminal.bodyGene();
        (faceGene.geneContract, faceGene.tokenId) = aminal.faceGene();
        (mouthGene.geneContract, mouthGene.tokenId) = aminal.mouthGene();
        (miscGene.geneContract, miscGene.tokenId) = aminal.miscGene();
        
        // Layer 0: Background effects (back trait)
        if (backGene.geneContract != address(0)) {
            composition = string.concat(composition, _createGeneImage(
                backGene, 
                positions.back.x, 
                positions.back.y, 
                positions.back.width, 
                positions.back.height
            ));
        }
        
        // Layer 1: Body base
        if (bodyGene.geneContract != address(0)) {
            composition = string.concat(composition, _createGeneImage(
                bodyGene,
                positions.body.x,
                positions.body.y,
                positions.body.width,
                positions.body.height
            ));
        } else {
            // Default body if no gene
            composition = string.concat(composition, GeneRenderer.svgImage(
                positions.body.x,
                positions.body.y,
                positions.body.width,
                positions.body.height,
                '<svg xmlns="http://www.w3.org/2000/svg" viewBox="-50 -50 100 100"><circle cx="0" cy="0" r="40" fill="#FFE4B5" stroke="#000" stroke-width="2"/></svg>'
            ));
        }
        
        // Layer 2: Tail (behind body parts)
        if (tailGene.geneContract != address(0)) {
            composition = string.concat(composition, _createGeneImage(
                tailGene,
                positions.tail.x,
                positions.tail.y,
                positions.tail.width,
                positions.tail.height
            ));
        }
        
        // Layer 3: Arms
        if (armGene.geneContract != address(0)) {
            composition = string.concat(composition, _createGeneImage(
                armGene,
                positions.arm.x,
                positions.arm.y,
                positions.arm.width,
                positions.arm.height
            ));
        }
        
        // Layer 4: Ears (on head)
        if (earsGene.geneContract != address(0)) {
            composition = string.concat(composition, _createGeneImage(
                earsGene,
                positions.ears.x,
                positions.ears.y,
                positions.ears.width,
                positions.ears.height
            ));
        }
        
        // Layer 5: Face features
        if (faceGene.geneContract != address(0)) {
            composition = string.concat(composition, _createGeneImage(
                faceGene,
                positions.face.x,
                positions.face.y,
                positions.face.width,
                positions.face.height
            ));
        }
        
        // Layer 6: Mouth
        if (mouthGene.geneContract != address(0)) {
            composition = string.concat(composition, _createGeneImage(
                mouthGene,
                positions.mouth.x,
                positions.mouth.y,
                positions.mouth.width,
                positions.mouth.height
            ));
        }
        
        // Layer 7: Misc effects (overlays)
        if (miscGene.geneContract != address(0)) {
            composition = string.concat(composition, _createGeneImage(
                miscGene,
                positions.misc.x,
                positions.misc.y,
                positions.misc.width,
                positions.misc.height
            ));
        }
        
        return GeneRenderer.svg("0 0 200 200", composition);
    }
    
    /**
     * @dev Create an image element from a gene reference
     */
    function _createGeneImage(
        Aminal.GeneReference memory gene,
        int256 x,
        int256 y,
        uint256 width,
        uint256 height
    ) private view returns (string memory) {
        try GeneNFT(gene.geneContract).gene(gene.tokenId) returns (string memory svg) {
            return GeneRenderer.svgImage(x, y, width, height, svg);
        } catch {
            return ""; // Return empty if gene can't be read
        }
    }
    
    /**
     * @dev Calculate trait positions based on this Aminal's characteristics
     * @notice Different body types affect how other traits are positioned
     * @return positions The calculated positions for all traits
     */
    function _getTraitPositions(Aminal aminal) private view returns (TraitPositions memory positions) {
        // Get traits from the Aminal
        ITraits.Traits memory traits = aminal.getTraits();
        
        // Determine body type characteristics
        bool isTall = _contains(traits.body, "Tall") || _contains(traits.body, "Slim");
        bool isShort = _contains(traits.body, "Short") || _contains(traits.body, "Chubby");
        bool isWide = _contains(traits.body, "Wide") || _contains(traits.body, "Chubby");
        
        // Base positions for standard body
        positions.back = Position({x: 0, y: 0, width: 200, height: 200});
        positions.body = Position({x: 50, y: 50, width: 100, height: 100});
        positions.tail = Position({x: 100, y: 100, width: 60, height: 80});
        positions.arm = Position({x: 20, y: 70, width: 160, height: 60});
        positions.ears = Position({x: 50, y: 0, width: 100, height: 60});
        positions.face = Position({x: 60, y: 60, width: 80, height: 80});
        positions.mouth = Position({x: 70, y: 90, width: 60, height: 40});
        positions.misc = Position({x: 0, y: 0, width: 200, height: 200});
        
        // Adjust for tall bodies
        if (isTall) {
            positions.body.y = 40;
            positions.body.height = 120;
            positions.ears.y = -10;  // Ears higher
            positions.face.y = 50;   // Face higher
            positions.mouth.y = 80;  // Mouth higher
            positions.arm.y = 65;    // Arms higher
            positions.tail.y = 110;  // Tail lower
        }
        
        // Adjust for short bodies
        if (isShort) {
            positions.body.y = 60;
            positions.body.height = 80;
            positions.ears.y = 10;   // Ears lower
            positions.face.y = 70;   // Face lower
            positions.mouth.y = 95;  // Mouth lower
            positions.arm.y = 75;    // Arms lower
            positions.tail.y = 95;   // Tail higher
        }
        
        // Adjust for wide bodies
        if (isWide) {
            positions.body.x = 40;
            positions.body.width = 120;
            positions.arm.x = 10;
            positions.arm.width = 180;
            positions.face.x = 55;
            positions.face.width = 90;
            positions.mouth.x = 65;
            positions.mouth.width = 70;
        }
        
        // Special adjustments based on specific traits
        if (_contains(traits.ears, "Long") || _contains(traits.ears, "Bunny")) {
            positions.ears.height = 80; // Longer ears
            positions.ears.y = positions.ears.y - 10; // Start higher
        }
        
        if (_contains(traits.tail, "Long") || _contains(traits.tail, "Dragon")) {
            positions.tail.height = 100; // Longer tail
            positions.tail.width = 80;
        }
        
        return positions;
    }
    
    /**
     * @dev Helper function to check if a string contains a substring
     * @param str The string to search in
     * @param substr The substring to search for
     * @return True if substr is found in str
     */
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