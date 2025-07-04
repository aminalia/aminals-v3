// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {GeneNFTWithPosition} from "src/GeneNFTWithPosition.sol";
import {GeneRenderer} from "src/GeneRenderer.sol";
import {LibString} from "solady/utils/LibString.sol";

/**
 * @title AminalComposerAdvanced
 * @dev Advanced Aminal composer that uses positioning data and z-index layering
 * @notice Demonstrates the full power of the image tag composition approach
 */
contract AminalComposerAdvanced {
    using LibString for uint256;
    using LibString for string;

    struct TraitIds {
        uint256 bodyId;
        uint256 backId;
        uint256 tailId;
        uint256 earsId;
        uint256 faceId;
        uint256 mouthId;
        uint256 armId;
        uint256 miscId;
    }

    /**
     * @dev Compose an Aminal with automatic positioning and layering
     * @param geneContract The GeneNFTWithPosition contract
     * @param traits Struct containing all trait token IDs
     * @return The fully composed Aminal SVG
     */
    function composeAminalWithPositions(
        address geneContract,
        TraitIds memory traits
    ) external view returns (string memory) {
        GeneNFTWithPosition genes = GeneNFTWithPosition(geneContract);
        
        // Collect all traits with their z-indices
        uint256[] memory tokenIds = new uint256[](8);
        uint256[] memory zIndices = new uint256[](8);
        uint256 count = 0;
        
        // Add traits if they exist
        if (traits.bodyId > 0) {
            tokenIds[count] = traits.bodyId;
            (,,,,zIndices[count]) = genes.getPosition(traits.bodyId);
            count++;
        }
        if (traits.backId > 0) {
            tokenIds[count] = traits.backId;
            (,,,,zIndices[count]) = genes.getPosition(traits.backId);
            count++;
        }
        if (traits.tailId > 0) {
            tokenIds[count] = traits.tailId;
            (,,,,zIndices[count]) = genes.getPosition(traits.tailId);
            count++;
        }
        if (traits.earsId > 0) {
            tokenIds[count] = traits.earsId;
            (,,,,zIndices[count]) = genes.getPosition(traits.earsId);
            count++;
        }
        if (traits.faceId > 0) {
            tokenIds[count] = traits.faceId;
            (,,,,zIndices[count]) = genes.getPosition(traits.faceId);
            count++;
        }
        if (traits.mouthId > 0) {
            tokenIds[count] = traits.mouthId;
            (,,,,zIndices[count]) = genes.getPosition(traits.mouthId);
            count++;
        }
        if (traits.armId > 0) {
            tokenIds[count] = traits.armId;
            (,,,,zIndices[count]) = genes.getPosition(traits.armId);
            count++;
        }
        if (traits.miscId > 0) {
            tokenIds[count] = traits.miscId;
            (,,,,zIndices[count]) = genes.getPosition(traits.miscId);
            count++;
        }
        
        // Sort by z-index (simple bubble sort for small arrays)
        for (uint i = 0; i < count - 1; i++) {
            for (uint j = 0; j < count - i - 1; j++) {
                if (zIndices[j] > zIndices[j + 1]) {
                    // Swap
                    uint256 tempId = tokenIds[j];
                    uint256 tempZ = zIndices[j];
                    tokenIds[j] = tokenIds[j + 1];
                    zIndices[j] = zIndices[j + 1];
                    tokenIds[j + 1] = tempId;
                    zIndices[j + 1] = tempZ;
                }
            }
        }
        
        // Compose in z-index order
        string memory composition = "";
        for (uint i = 0; i < count; i++) {
            composition = string.concat(
                composition,
                _createImageElement(genes, tokenIds[i])
            );
        }
        
        return GeneRenderer.svg("0 0 400 400", composition);
    }

    /**
     * @dev Create an image element from a gene token
     */
    function _createImageElement(
        GeneNFTWithPosition genes,
        uint256 tokenId
    ) private view returns (string memory) {
        (int256 x, int256 y, uint256 width, uint256 height,) = genes.getPosition(tokenId);
        string memory svg = genes.gene(tokenId);
        return GeneRenderer.svgImage(x, y, width, height, svg);
    }

    /**
     * @dev Create a debug view showing positioning info
     */
    function createDebugView(
        address geneContract,
        uint256 tokenId
    ) external view returns (string memory) {
        GeneNFTWithPosition genes = GeneNFTWithPosition(geneContract);
        (int256 x, int256 y, uint256 width, uint256 height, uint256 zIndex) = genes.getPosition(tokenId);
        
        // Create a debug overlay showing position info
        string memory debugInfo = string.concat(
            "x:", x < 0 ? "-" : "", uint256(x < 0 ? -x : x).toString(),
            " y:", y < 0 ? "-" : "", uint256(y < 0 ? -y : y).toString(),
            " w:", width.toString(),
            " h:", height.toString(),
            " z:", zIndex.toString()
        );
        
        return GeneRenderer.svg(
            "0 0 400 400",
            string.concat(
                // Show the trait
                _createImageElement(genes, tokenId),
                // Add debug overlay
                GeneRenderer.rect(0, 380, 400, 20, "#000000"),
                GeneRenderer.text(200, 395, debugInfo, "middle", "12", "#FFFFFF")
            )
        );
    }

    /**
     * @dev Example: Create a specific Aminal composition
     */
    function createFireDragonBunny(
        address geneContract,
        uint256 dragonWingsId,
        uint256 fireTailId,
        uint256 bunnyEarsId,
        uint256 bodyId
    ) external view returns (string memory) {
        TraitIds memory traits = TraitIds({
            bodyId: bodyId,
            backId: dragonWingsId,
            tailId: fireTailId,
            earsId: bunnyEarsId,
            faceId: 0,
            mouthId: 0,
            armId: 0,
            miscId: 0
        });
        
        return this.composeAminalWithPositions(geneContract, traits);
    }
}