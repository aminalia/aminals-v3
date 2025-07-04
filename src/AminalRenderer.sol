// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Aminal} from "src/Aminal.sol";
import {GeneNFT} from "src/GeneNFT.sol";
import {GeneRenderer} from "src/GeneRenderer.sol";
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

    /**
     * @dev Generate complete tokenURI for an Aminal
     * @param aminal The Aminal contract to render
     * @param tokenId The token ID (always 1 for Aminals)
     * @return The complete data URI with metadata
     */
    function tokenURI(Aminal aminal, uint256 tokenId) external view returns (string memory) {
        require(tokenId == 1, "Invalid token ID");
        
        // Compose the Aminal SVG from its genes
        string memory composedSvg = composeAminal(aminal);
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
        // Use the Aminal's built-in composition function
        return aminal.composeAminal();
    }


    /**
     * @dev Generate a preview of an Aminal composition without deploying
     * @param genes Array of gene references in order: back, arm, tail, ears, body, face, mouth, misc
     * @return The composed SVG as a string
     */
    function previewComposition(Aminal.GeneReference[8] memory genes) external view returns (string memory) {
        string memory composition = "";
        
        // Add body base layer
        if (genes[4].geneContract != address(0)) {
            composition = string.concat(
                composition,
                _createGeneImage(genes[4].geneContract, genes[4].tokenId, 50, 50, 100, 100)
            );
        } else {
            // Default body if no gene
            composition = GeneRenderer.svgImage(
                50, 50, 100, 100,
                '<svg xmlns="http://www.w3.org/2000/svg" viewBox="-50 -50 100 100"><circle cx="0" cy="0" r="40" fill="#FFE4B5" stroke="#000" stroke-width="2"/></svg>'
            );
        }
        
        // Layer traits: back[0], arm[1], tail[2], ears[3], body[4], face[5], mouth[6], misc[7]
        if (genes[0].geneContract != address(0)) {
            composition = string.concat(composition, _createGeneImage(genes[0].geneContract, genes[0].tokenId, 0, 0, 200, 200));
        }
        if (genes[2].geneContract != address(0)) {
            composition = string.concat(composition, _createGeneImage(genes[2].geneContract, genes[2].tokenId, 100, 100, 60, 80));
        }
        if (genes[3].geneContract != address(0)) {
            composition = string.concat(composition, _createGeneImage(genes[3].geneContract, genes[3].tokenId, 50, 0, 100, 60));
        }
        if (genes[5].geneContract != address(0)) {
            composition = string.concat(composition, _createGeneImage(genes[5].geneContract, genes[5].tokenId, 60, 60, 80, 80));
        }
        if (genes[6].geneContract != address(0)) {
            composition = string.concat(composition, _createGeneImage(genes[6].geneContract, genes[6].tokenId, 70, 90, 60, 40));
        }
        if (genes[1].geneContract != address(0)) {
            composition = string.concat(composition, _createGeneImage(genes[1].geneContract, genes[1].tokenId, 20, 70, 160, 60));
        }
        if (genes[7].geneContract != address(0)) {
            composition = string.concat(composition, _createGeneImage(genes[7].geneContract, genes[7].tokenId, 0, 0, 200, 200));
        }
        
        return GeneRenderer.svg("0 0 200 200", composition);
    }
    
    /**
     * @dev Create an image element from a gene reference
     */
    function _createGeneImage(
        address geneContract,
        uint256 tokenId,
        int256 x,
        int256 y,
        uint256 width,
        uint256 height
    ) private view returns (string memory) {
        try GeneNFT(geneContract).gene(tokenId) returns (string memory svg) {
            return GeneRenderer.svgImage(x, y, width, height, svg);
        } catch {
            return ""; // Return empty if gene can't be read
        }
    }
}