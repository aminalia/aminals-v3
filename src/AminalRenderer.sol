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
        
        // Build the metadata with external URL
        string memory metadata = _generateAminalMetadata(
            aminal.name(),
            string.concat(
                "A self-sovereign Aminal with energy: ", 
                aminal.energy().toString(), 
                " and total love: ", 
                aminal.totalLove().toString()
            ),
            imageDataURI
        );
        
        return GeneRenderer.jsonToBase64DataURI(metadata);
    }
    
    /**
     * @dev Compose the Aminal's appearance from its Genes
     * @notice Z-ORDER RENDERING LAYERS (back to front):
     *         Layer 0: BACK - Background elements (wings, auras, backdrops)
     *         Layer 1: BODY - Base body shape (foundation for other parts)
     *         Layer 2: TAIL - Behind body parts (can extend beyond body)
     *         Layer 3: ARM - Limbs and appendages (overlay on body)
     *         Layer 4: EARS - Head accessories (positioned relative to body)
     *         Layer 5: FACE - Facial features (eyes, nose, expression)
     *         Layer 6: MOUTH - Overlays on face (speech, expressions)
     *         Layer 7: MISC - Foreground effects (sparkles, accessories, overlays)
     * 
     * @notice COORDINATE SYSTEM:
     *         - Origin (0,0) at top-left corner
     *         - X increases rightward, Y increases downward
     *         - ViewBox: 200x200 SVG units
     *         - Positions can be negative (render off-canvas)
     *         - No automatic clipping (genes can render outside viewBox)
     * 
     * @notice RENDERING PROCESS:
     *         1. Read stored positions from Aminal contract
     *         2. Fetch gene references for each slot
     *         3. Retrieve SVG data from Gene contracts
     *         4. Layer in z-order with stored positions
     *         5. Return composed SVG with fixed viewBox
     * 
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
        composition = string.concat(composition, _createGeneImage(
            backGene, 
            positions.back.x, 
            positions.back.y, 
            positions.back.width, 
            positions.back.height,
            aminal.GENE_BACK()
        ));
        
        // Layer 1: Body base
        if (bodyGene.geneContract != address(0)) {
            composition = string.concat(composition, _createGeneImage(
                bodyGene,
                positions.body.x,
                positions.body.y,
                positions.body.width,
                positions.body.height,
                aminal.GENE_BODY()
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
        composition = string.concat(composition, _createGeneImage(
            tailGene,
            positions.tail.x,
            positions.tail.y,
            positions.tail.width,
            positions.tail.height,
            aminal.GENE_TAIL()
        ));
        
        // Layer 3: Arms
        composition = string.concat(composition, _createGeneImage(
            armGene,
            positions.arm.x,
            positions.arm.y,
            positions.arm.width,
            positions.arm.height,
            aminal.GENE_ARM()
        ));
        
        // Layer 4: Ears (on head)
        composition = string.concat(composition, _createGeneImage(
            earsGene,
            positions.ears.x,
            positions.ears.y,
            positions.ears.width,
            positions.ears.height,
            aminal.GENE_EARS()
        ));
        
        // Layer 5: Face features
        composition = string.concat(composition, _createGeneImage(
            faceGene,
            positions.face.x,
            positions.face.y,
            positions.face.width,
            positions.face.height,
            aminal.GENE_FACE()
        ));
        
        // Layer 6: Mouth
        composition = string.concat(composition, _createGeneImage(
            mouthGene,
            positions.mouth.x,
            positions.mouth.y,
            positions.mouth.width,
            positions.mouth.height,
            aminal.GENE_MOUTH()
        ));
        
        // Layer 7: Misc effects (overlays)
        composition = string.concat(composition, _createGeneImage(
            miscGene,
            positions.misc.x,
            positions.misc.y,
            positions.misc.width,
            positions.misc.height,
            aminal.GENE_MISC()
        ));
        
        return GeneRenderer.svg("0 0 200 200", composition);
    }
    
    /**
     * @dev Create an image element from a gene reference with error handling
     * @notice Provides fallback rendering for missing or invalid genes
     * @param gene The gene reference to render
     * @param x X position
     * @param y Y position  
     * @param width Width of the gene
     * @param height Height of the gene
     * @param geneType The type of gene (for fallback rendering)
     * @return SVG image element or placeholder
     */
    function _createGeneImage(
        Aminal.GeneReference memory gene,
        int256 x,
        int256 y,
        uint256 width,
        uint256 height,
        uint8 geneType
    ) private view returns (string memory) {
        // Skip if no gene contract
        if (gene.geneContract == address(0)) {
            return _createPlaceholder(x, y, width, height, geneType);
        }
        
        try Gene(gene.geneContract).gene(gene.tokenId) returns (string memory svg) {
            // Validate SVG is not empty
            if (bytes(svg).length == 0) {
                return _createPlaceholder(x, y, width, height, geneType);
            }
            return GeneRenderer.svgImage(x, y, width, height, svg);
        } catch {
            // Return placeholder on any error
            return _createPlaceholder(x, y, width, height, geneType);
        }
    }
    
    /**
     * @dev Create a placeholder for missing genes
     * @notice Renders a semi-transparent shape based on gene type
     */
    function _createPlaceholder(
        int256 x,
        int256 y,
        uint256 width,
        uint256 height,
        uint8 geneType
    ) private pure returns (string memory) {
        // Skip body placeholder as we have a default body
        if (geneType == 4) return ""; // GENE_BODY
        
        string memory fill = "#808080"; // Default gray
        string memory opacity = "0.1"; // Very subtle
        
        // Create simple rect placeholder
        return string.concat(
            '<rect x="', LibString.toString(x),
            '" y="', LibString.toString(y),
            '" width="', width.toString(),
            '" height="', height.toString(),
            '" fill="', fill,
            '" opacity="', opacity,
            '" rx="10" />'
        );
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
        // Always use stored positions (width is always > 0 as per user requirement)
        positions.back = _getStoredPosition(aminal, aminal.GENE_BACK());
        positions.body = _getStoredPosition(aminal, aminal.GENE_BODY());
        positions.tail = _getStoredPosition(aminal, aminal.GENE_TAIL());
        positions.arm = _getStoredPosition(aminal, aminal.GENE_ARM());
        positions.ears = _getStoredPosition(aminal, aminal.GENE_EARS());
        positions.face = _getStoredPosition(aminal, aminal.GENE_FACE());
        positions.mouth = _getStoredPosition(aminal, aminal.GENE_MOUTH());
        positions.misc = _getStoredPosition(aminal, aminal.GENE_MISC());
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
    
    /**
     * @dev Get stored position for a specific gene type
     * @param aminal The Aminal to get position from
     * @param geneType The gene type to get position for
     * @return Position struct with stored coordinates
     */
    function _getStoredPosition(Aminal aminal, uint8 geneType) private view returns (Position memory) {
        (int16 x, int16 y, uint16 width, uint16 height) = aminal.genePositions(geneType);
        return Position({
            x: x,
            y: y,
            width: width,
            height: height
        });
    }
    
    /**
     * @dev Generate Aminal-specific metadata with external URL
     * @param name The Aminal's name
     * @param description The Aminal's description
     * @param imageDataURI The base64-encoded image data URI
     * @return The JSON metadata string
     */
    function _generateAminalMetadata(
        string memory name,
        string memory description,
        string memory imageDataURI
    ) private pure returns (string memory) {
        return string.concat(
            '{"name":"',
            name,
            '","description":"',
            description,
            '","image":"',
            imageDataURI,
            '","external_url":"https://aminals.example",',
            '"attributes":[{"trait_type":"Type","value":"Aminal"},{"trait_type":"Sovereignty","value":"Self-Sovereign"}]}'
        );
    }
}