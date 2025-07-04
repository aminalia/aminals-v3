// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {LibString} from "solady/utils/LibString.sol";
import {Base64} from "solady/utils/Base64.sol";

/**
 * @title GeneRenderer
 * @dev Onchain SVG renderer for GeneNFT traits using Solady utilities
 * @notice Provides efficient SVG generation and composition functions
 */
library GeneRenderer {
    using LibString for uint256;
    using LibString for string;

    /**
     * @dev Generate tokenURI for a GeneNFT
     * @param name The gene name
     * @param traitType The trait type (back, arm, tail, etc.)
     * @param svg The SVG content
     * @param attributes Additional attributes for metadata
     * @return The complete data URI with metadata
     */
    function geneTokenURI(
        string memory name,
        string memory traitType,
        string memory svg,
        string memory attributes
    ) internal pure returns (string memory) {
        string memory imageDataURI = svgToBase64DataURI(svg);
        
        string memory metadata = string.concat(
            '{"name":"',
            name,
            '","description":"A GeneNFT trait of type: ',
            traitType,
            '","image":"',
            imageDataURI,
            '","attributes":[{"trait_type":"Type","value":"',
            traitType,
            '"}'
        );
        
        if (bytes(attributes).length > 0) {
            metadata = string.concat(metadata, ',', attributes);
        }
        
        metadata = string.concat(metadata, ']}');
        
        return jsonToBase64DataURI(metadata);
    }

    /**
     * @dev Generate an SVG rectangle element
     */
    function rect(
        uint256 x,
        uint256 y,
        uint256 width,
        uint256 height,
        string memory fill
    ) internal pure returns (string memory) {
        return string.concat(
            '<rect x="',
            x.toString(),
            '" y="',
            y.toString(),
            '" width="',
            width.toString(),
            '" height="',
            height.toString(),
            '" fill="',
            fill,
            '"/>'
        );
    }

    /**
     * @dev Generate an SVG circle element
     */
    function circle(
        uint256 cx,
        uint256 cy,
        uint256 r,
        string memory fill
    ) internal pure returns (string memory) {
        return string.concat(
            '<circle cx="',
            cx.toString(),
            '" cy="',
            cy.toString(),
            '" r="',
            r.toString(),
            '" fill="',
            fill,
            '"/>'
        );
    }

    /**
     * @dev Generate an SVG text element
     */
    function text(
        uint256 x,
        uint256 y,
        string memory content,
        string memory textAnchor,
        string memory fontSize,
        string memory fill
    ) internal pure returns (string memory) {
        return string.concat(
            '<text x="',
            x.toString(),
            '" y="',
            y.toString(),
            '" text-anchor="',
            textAnchor,
            '" font-family="Arial" font-size="',
            fontSize,
            '" fill="',
            fill,
            '">',
            content,
            '</text>'
        );
    }

    /**
     * @dev Generate an SVG group element with transform
     */
    function group(string memory transform, string memory content) internal pure returns (string memory) {
        return string.concat(
            '<g transform="',
            transform,
            '">',
            content,
            '</g>'
        );
    }

    /**
     * @dev Generate a complete SVG document
     */
    function svg(
        string memory viewBox,
        string memory content
    ) internal pure returns (string memory) {
        return string.concat(
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="',
            viewBox,
            '">',
            content,
            '</svg>'
        );
    }

    /**
     * @dev Generate a standalone gene SVG with background
     */
    function generateStandaloneGeneSVG(
        string memory traitType,
        string memory traitValue,
        string memory geneSvg
    ) internal pure returns (string memory) {
        return svg(
            "0 0 500 500",
            string.concat(
                rect(0, 0, 500, 500, "#f0f0f0"),
                text(250, 50, string.concat(traitType, ": ", traitValue), "middle", "20", "#333"),
                group("translate(250, 250)", geneSvg)
            )
        );
    }

    /**
     * @dev Encode SVG as base64 data URI
     */
    function svgToBase64DataURI(string memory svgContent) internal pure returns (string memory) {
        return string.concat(
            "data:image/svg+xml;base64,",
            Base64.encode(bytes(svgContent))
        );
    }

    /**
     * @dev Generate OpenSea-compatible JSON metadata
     */
    function generateMetadata(
        string memory name,
        string memory description,
        string memory imageDataURI,
        string memory traitType,
        string memory traitValue
    ) internal pure returns (string memory) {
        return string.concat(
            '{"name":"',
            name,
            '","description":"',
            description,
            '","image":"',
            imageDataURI,
            '","attributes":[{"trait_type":"Type","value":"',
            traitType,
            '"},{"trait_type":"Value","value":"',
            traitValue,
            '"}]}'
        );
    }

    /**
     * @dev Encode JSON as base64 data URI
     */
    function jsonToBase64DataURI(string memory json) internal pure returns (string memory) {
        return string.concat(
            "data:application/json;base64,",
            Base64.encode(bytes(json))
        );
    }

    /**
     * @dev Create an SVG image element with base64-encoded SVG content
     */
    function svgImage(
        int256 x,
        int256 y,
        uint256 width,
        uint256 height,
        string memory svgContent
    ) internal pure returns (string memory) {
        // Ensure the SVG content is a complete SVG with its own viewBox
        string memory dataUri = svgToBase64DataURI(svgContent);
        
        return string.concat(
            '<image x="',
            x < 0 ? string.concat("-", uint256(-x).toString()) : uint256(x).toString(),
            '" y="',
            y < 0 ? string.concat("-", uint256(-y).toString()) : uint256(y).toString(),
            '" width="',
            width.toString(),
            '" height="',
            height.toString(),
            '" href="',
            dataUri,
            '"/>'
        );
    }

    /**
     * @dev Compose multiple gene SVGs into a single Aminal using image tags
     */
    function composeAminal(
        string memory bodyBaseSvg,
        string memory backSvg,
        string memory tailSvg,
        string memory earsSvg,
        string memory faceSvg,
        string memory mouthSvg,
        string memory armSvg,
        string memory miscSvg
    ) internal pure returns (string memory) {
        string memory composition = "";
        
        // Base body (centered)
        if (bytes(bodyBaseSvg).length > 0) {
            composition = string.concat(composition, svgImage(0, 0, 200, 200, bodyBaseSvg));
        }
        
        // Back features (behind body)
        if (bytes(backSvg).length > 0) {
            composition = string.concat(composition, svgImage(-50, -50, 300, 300, backSvg));
        }
        
        // Tail (offset to back)
        if (bytes(tailSvg).length > 0) {
            composition = string.concat(composition, svgImage(50, 100, 100, 100, tailSvg));
        }
        
        // Ears (on top)
        if (bytes(earsSvg).length > 0) {
            composition = string.concat(composition, svgImage(0, -100, 200, 150, earsSvg));
        }
        
        // Face features (centered on face area)
        if (bytes(faceSvg).length > 0) {
            composition = string.concat(composition, svgImage(50, 25, 100, 100, faceSvg));
        }
        
        // Mouth (lower face)
        if (bytes(mouthSvg).length > 0) {
            composition = string.concat(composition, svgImage(50, 75, 100, 50, mouthSvg));
        }
        
        // Arms (sides)
        if (bytes(armSvg).length > 0) {
            composition = string.concat(composition, svgImage(-25, 50, 250, 100, armSvg));
        }
        
        // Misc effects (overlay)
        if (bytes(miscSvg).length > 0) {
            composition = string.concat(composition, svgImage(-50, -50, 300, 300, miscSvg));
        }
        
        return svg("0 0 200 200", composition);
    }

    /**
     * @dev Create a gradient definition
     */
    function linearGradient(
        string memory id,
        string memory color1,
        string memory color2
    ) internal pure returns (string memory) {
        return string.concat(
            '<defs><linearGradient id="',
            id,
            '"><stop offset="0%" stop-color="',
            color1,
            '"/><stop offset="100%" stop-color="',
            color2,
            '"/></linearGradient></defs>'
        );
    }

    /**
     * @dev Create an animated element
     */
    function animate(
        string memory attributeName,
        string memory values,
        string memory dur,
        string memory repeatCount
    ) internal pure returns (string memory) {
        return string.concat(
            '<animate attributeName="',
            attributeName,
            '" values="',
            values,
            '" dur="',
            dur,
            '" repeatCount="',
            repeatCount,
            '"/>'
        );
    }
}