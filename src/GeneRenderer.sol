// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {LibString} from "solady/utils/LibString.sol";
import {Base64} from "solady/utils/Base64.sol";

/**
 * @title GeneRenderer
 * @dev Onchain SVG renderer for Gene traits using Solady utilities
 * @notice Provides efficient SVG generation and composition functions
 */
library GeneRenderer {
    using LibString for uint256;
    using LibString for string;

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
                // Use svgImage to properly center the gene SVG
                svgImage(150, 150, 200, 200, geneSvg)
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

}