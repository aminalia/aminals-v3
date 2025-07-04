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
}