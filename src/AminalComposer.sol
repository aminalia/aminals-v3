// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {GeneNFT} from "src/GeneNFT.sol";
import {GeneRenderer} from "src/GeneRenderer.sol";
import {LibString} from "solady/utils/LibString.sol";

/**
 * @title AminalComposer
 * @dev Example contract showing how to compose multiple GeneNFTs into a complete Aminal SVG
 * @notice This demonstrates the composability of the gene system
 */
contract AminalComposer {
    using LibString for uint256;
    using LibString for string;

    /**
     * @dev Compose an Aminal from multiple gene token IDs
     * @param geneContract The GeneNFT contract address
     * @param backTokenId Token ID for back trait (0 if none)
     * @param tailTokenId Token ID for tail trait (0 if none)
     * @param earsTokenId Token ID for ears trait (0 if none)
     * @param bodyTokenId Token ID for body trait (0 if none)
     * @param faceTokenId Token ID for face trait (0 if none)
     * @param mouthTokenId Token ID for mouth trait (0 if none)
     * @param armTokenId Token ID for arm trait (0 if none)
     * @param miscTokenId Token ID for misc trait (0 if none)
     * @return The composed Aminal SVG
     */
    function composeAminal(
        address geneContract,
        uint256 backTokenId,
        uint256 tailTokenId,
        uint256 earsTokenId,
        uint256 bodyTokenId,
        uint256 faceTokenId,
        uint256 mouthTokenId,
        uint256 armTokenId,
        uint256 miscTokenId
    ) external view returns (string memory) {
        GeneNFT genes = GeneNFT(geneContract);
        
        // Base body shape as a complete SVG
        string memory bodyBase = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="-50 -50 100 100"><circle cx="0" cy="0" r="40" fill="#FFE4B5" stroke="#000" stroke-width="2"/></svg>';
        
        // Get each gene SVG if token ID is provided
        string memory backSvg = backTokenId > 0 ? genes.gene(backTokenId) : "";
        string memory tailSvg = tailTokenId > 0 ? genes.gene(tailTokenId) : "";
        string memory earsSvg = earsTokenId > 0 ? genes.gene(earsTokenId) : "";
        string memory bodySvg = bodyTokenId > 0 ? genes.gene(bodyTokenId) : "";
        string memory faceSvg = faceTokenId > 0 ? genes.gene(faceTokenId) : "";
        string memory mouthSvg = mouthTokenId > 0 ? genes.gene(mouthTokenId) : "";
        string memory armSvg = armTokenId > 0 ? genes.gene(armTokenId) : "";
        string memory miscSvg = miscTokenId > 0 ? genes.gene(miscTokenId) : "";
        
        // Compose using GeneRenderer
        return GeneRenderer.composeAminal(
            bodyBase,
            backSvg,
            tailSvg,
            earsSvg,
            faceSvg,
            mouthSvg,
            armSvg,
            miscSvg
        );
    }

    /**
     * @dev Generate a complete Aminal metadata with composed SVG
     * @param name The name of the Aminal
     * @param description The description of the Aminal
     * @param composedSvg The composed SVG from composeAminal
     * @return The complete metadata as a data URI
     */
    function generateAminalMetadata(
        string memory name,
        string memory description,
        string memory composedSvg
    ) external pure returns (string memory) {
        string memory imageDataURI = GeneRenderer.svgToBase64DataURI(composedSvg);
        
        // Build metadata with all trait attributes
        string memory json = string.concat(
            '{"name":"',
            name,
            '","description":"',
            description,
            '","image":"',
            imageDataURI,
            '"}'
        );
        
        return GeneRenderer.jsonToBase64DataURI(json);
    }

    /**
     * @dev Create a rainbow gradient Aminal body
     */
    function createRainbowBody() external pure returns (string memory) {
        return string.concat(
            GeneRenderer.linearGradient("rainbow", "#FF0000", "#00FF00"),
            '<circle cx="0" cy="0" r="40" fill="url(#rainbow)" stroke="#000" stroke-width="2"/>'
        );
    }

    /**
     * @dev Create an animated floating effect
     */
    function createFloatingAnimation(string memory content) external pure returns (string memory) {
        return string.concat(
            '<g>',
            content,
            GeneRenderer.animate("transform", "translate(0,0);translate(0,-10);translate(0,0)", "3s", "indefinite"),
            '</g>'
        );
    }
}