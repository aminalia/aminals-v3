// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Aminal} from "src/Aminal.sol";
import {Gene} from "src/Gene.sol";
import {GeneRenderer} from "src/GeneRenderer.sol";
import {IGenes} from "src/interfaces/IGenes.sol";
import {LibString} from "solady/utils/LibString.sol";
import {Base64} from "solady/utils/Base64.sol";

/**
 * @title AminalRenderer
 * @dev Handles rendering of Aminal NFT metadata and composed SVGs
 * @notice Separates rendering logic from the main Aminal contract
 * 
 * @notice DATA FLOW ARCHITECTURE:
 * 
 * 1. INITIALIZATION (happens in Aminal constructor):
 *    - Aminal deploys its own AminalRenderer instance
 *    - Stores renderer address as immutable variable
 * 
 * 2. RENDERING REQUEST (e.g., from OpenSea):
 *    - External caller → Aminal.tokenURI(1)
 *    - Aminal.tokenURI() → renderer.tokenURI(this, 1)
 *    - Renderer receives entire Aminal contract instance
 * 
 * 3. DATA ACCESS (renderer reading from Aminal):
 *    - Public state variables: name, energy, totalLove, traits
 *    - Gene references: backGene, armGene, tailGene, etc. (returns tuples)
 *    - Each gene reference points to: (Gene address, tokenId)
 * 
 * 4. SVG COMPOSITION:
 *    - Renderer → aminal.getTraits() to determine positioning
 *    - Renderer → Gene.gene(tokenId) for each trait's SVG
 *    - Positions and layers SVGs based on trait characteristics
 * 
 * 5. METADATA GENERATION:
 *    - Combines composed SVG with Aminal stats
 *    - Returns OpenSea-compatible JSON as base64 data URI
 * 
 * @dev This architecture allows:
 *      - Clean separation of concerns
 *      - Aminal focuses on NFT logic, energy/love mechanics
 *      - Renderer handles all visual complexity
 *      - Easy upgrades to rendering logic without touching core contract
 */
contract AminalRenderer {
    using LibString for uint256;
    using LibString for string;
    
    /// @dev Structure to store positioning data for a trait
    /// @notice This is a temporary structure used only during rendering calculations
    /// @notice No Position data is ever stored in contract storage - it's calculated on-demand
    struct Position {
        int256 x;        // X coordinate (can be negative for off-canvas positioning)
        int256 y;        // Y coordinate (can be negative for off-canvas positioning)
        uint256 width;   // Width of the trait image
        uint256 height;  // Height of the trait image
    }
    
    /// @dev Structure to store all trait positions
    /// @notice This is a temporary structure created in memory during each render
    /// @notice Positions are calculated based on the Aminal's traits, used for SVG composition, then discarded
    struct TraitPositions {
        Position back;   // Background elements (wings, auras, etc.)
        Position body;   // Main body shape
        Position tail;   // Tail positioning
        Position arm;    // Arms/limbs
        Position ears;   // Ear positioning (adjusted for body height)
        Position face;   // Facial features
        Position mouth;  // Mouth/expression
        Position misc;   // Overlay effects (sparkles, accessories)
    }

    /**
     * @dev Generate complete tokenURI for an Aminal
     * @notice DATA FLOW - How AminalRenderer accesses Aminal data:
     *         1. Receives the Aminal contract instance as a parameter
     *         2. Calls aminal.composeAminal() to get the composed SVG
     *            - This creates a circular call: Aminal.composeAminal() -> AminalRenderer.composeAminal() -> back to this renderer
     *         3. Accesses Aminal's public state variables:
     *            - aminal.name() for the NFT name
     *            - aminal.energy() and aminal.totalLove() for the description
     *         4. Uses GeneRenderer library to encode the SVG and create metadata JSON
     *         5. Returns OpenSea-compatible metadata as a base64 data URI
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
     * @dev Compose the Aminal's appearance from its Genes
     * @notice DATA FLOW - Complete rendering process:
     *         1. INPUT: Receives Aminal contract instance containing all state
     *         2. TRAIT ANALYSIS: Calls aminal.getTraits() to determine positioning
     *            - Analyzes body type (Tall, Short, Wide, Chubby) to adjust layout
     *            - Special handling for Long ears, Dragon tails, etc.
     *         3. GENE FETCHING: Accesses gene references via public getters
     *            - aminal.backGene() returns (address geneContract, uint256 tokenId)
     *            - Must destructure tuples since Solidity public getters don't return structs
     *         4. SVG RETRIEVAL: For each gene reference:
     *            - Calls Gene(geneContract).gene(tokenId) to get raw SVG
     *            - Wraps in image tags with calculated positions
     *         5. COMPOSITION: Layers genes in specific order (back->body->tail->arms->ears->face->mouth->misc)
     *         6. OUTPUT: Returns complete SVG with 200x200 viewBox
     * @dev The Aminal contract must have public getters for all required data:
     *      - Gene references (8 slots)
     *      - Traits struct
     *      - Name, energy, totalLove for metadata
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
        try Gene(gene.geneContract).gene(gene.tokenId) returns (string memory svg) {
            return GeneRenderer.svgImage(x, y, width, height, svg);
        } catch {
            return ""; // Return empty if gene can't be read
        }
    }
    
    /**
     * @dev Calculate trait positions based on this Aminal's characteristics
     * @notice Different body types affect how other traits are positioned
     * 
     * @notice POSITIONING DATA FLOW:
     * 1. INITIALIZATION: No positioning data is stored anywhere - it's calculated on-demand
     * 2. TRAIT SOURCE: Traits are stored in Aminal contract (set once in constructor, immutable)
     * 3. CALCULATION: When rendering is needed:
     *    - Fetch traits from Aminal via aminal.getTraits()
     *    - Analyze trait strings (e.g., "Tall", "Chubby", "Dragon")
     *    - Start with base positions (hardcoded defaults)
     *    - Apply modifications based on trait characteristics
     * 4. USAGE: Positions are used immediately for SVG composition, then discarded
     * 
     * @dev This approach means:
     *      - No storage cost for positions (gas efficient)
     *      - Positions can be updated by deploying new renderer
     *      - Each render calculates fresh positions
     *      - Positions are deterministic based on traits
     * 
     * @return positions The calculated positions for all traits
     */
    function _getTraitPositions(Aminal aminal) private view returns (TraitPositions memory positions) {
        // Get traits from the Aminal
        IGenes.Genes memory traits = aminal.getGenes();
        
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