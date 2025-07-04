// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {GeneNFT} from "src/GeneNFT.sol";

/**
 * @title GeneNFTWithPosition
 * @dev Extension of GeneNFT that includes positioning data for composition
 * @notice Each gene stores its position, size, and z-index for proper layering
 */
contract GeneNFTWithPosition is GeneNFT {
    
    /// @dev Positioning data for each gene
    struct Position {
        int256 x;        // X coordinate (can be negative)
        int256 y;        // Y coordinate (can be negative)
        uint256 width;   // Width of the trait
        uint256 height;  // Height of the trait
        uint256 zIndex;  // Layer order (lower = behind, higher = front)
    }
    
    /// @dev Mapping from token ID to position data
    mapping(uint256 => Position) public positions;
    
    constructor(
        address owner,
        string memory name,
        string memory symbol,
        string memory baseURI
    ) GeneNFT(owner, name, symbol, baseURI) {}
    
    /**
     * @notice Mint a GeneNFT with positioning data
     * @dev The SVG should be a complete self-contained SVG with its own viewBox
     * @param to The address that will receive the NFT
     * @param traitType The trait type this NFT represents
     * @param traitValue The specific trait value
     * @param svg Complete SVG with viewBox (e.g., '<svg viewBox="0 0 100 100">...</svg>')
     * @param description Description of the trait
     * @param x X coordinate for composition
     * @param y Y coordinate for composition
     * @param width Width for composition
     * @param height Height for composition
     * @param zIndex Layer order
     * @return tokenId The ID of the newly minted token
     */
    function mintWithPosition(
        address to,
        string memory traitType,
        string memory traitValue,
        string memory svg,
        string memory description,
        int256 x,
        int256 y,
        uint256 width,
        uint256 height,
        uint256 zIndex
    ) external returns (uint256) {
        uint256 tokenId = this.mint(to, traitType, traitValue, svg, description);
        
        positions[tokenId] = Position({
            x: x,
            y: y,
            width: width,
            height: height,
            zIndex: zIndex
        });
        
        return tokenId;
    }
    
    /**
     * @dev Get position data for a token
     */
    function getPosition(uint256 tokenId) external view returns (
        int256 x,
        int256 y,
        uint256 width,
        uint256 height,
        uint256 zIndex
    ) {
        Position memory pos = positions[tokenId];
        return (pos.x, pos.y, pos.width, pos.height, pos.zIndex);
    }
}