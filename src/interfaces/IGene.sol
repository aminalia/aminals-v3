// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IGene
 * @notice Interface for Gene NFT contracts
 */
interface IGene {
    /**
     * @notice Get the raw SVG data for a gene
     * @param tokenId The token ID of the gene
     * @return The SVG string
     */
    function gene(uint256 tokenId) external view returns (string memory);
    
    /**
     * @notice Get the trait type this gene represents
     * @param tokenId The token ID of the gene
     * @return The trait type as a string (e.g., "back", "arm", etc.)
     */
    function traitType(uint256 tokenId) external view returns (string memory);
    
    /**
     * @notice Get the trait value/name for this gene
     * @param tokenId The token ID of the gene
     * @return The trait value (e.g., "Dragon Wings", "Fluffy Tail")
     */
    function traitValue(uint256 tokenId) external view returns (string memory);
}