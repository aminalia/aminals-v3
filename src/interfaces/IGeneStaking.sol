// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IGeneStaking
 * @dev Interface for staking Genes into Aminals
 * @notice Defines the standard for how Genes are staked and unstaked from Aminals
 */
interface IGeneStaking {
    /// @dev Event emitted when a Gene is staked to an Aminal
    event GeneStaked(address indexed aminal, address indexed geneContract, uint256 indexed tokenId, string traitType);
    
    /// @dev Event emitted when a Gene is unstaked from an Aminal
    event GeneUnstaked(address indexed aminal, address indexed geneContract, uint256 indexed tokenId, string traitType);
    
    /// @dev Error thrown when trying to stake to an invalid trait slot
    error InvalidTraitType();
    
    /// @dev Error thrown when trying to stake when slot is already occupied
    error SlotOccupied();
    
    /// @dev Error thrown when trying to unstake a gene that isn't staked
    error GeneNotStaked();
    
    /// @dev Error thrown when non-owner tries to stake/unstake
    error NotGeneOwner();
    
    /**
     * @notice Stake a Gene to this Aminal
     * @param geneContract The Gene contract address
     * @param tokenId The token ID of the gene to stake
     * @param traitType The trait slot to stake to (back, tail, ears, etc.)
     */
    function stakeGene(address geneContract, uint256 tokenId, string memory traitType) external;
    
    /**
     * @notice Unstake a Gene from this Aminal
     * @param traitType The trait slot to unstake from
     */
    function unstakeGene(string memory traitType) external;
    
    /**
     * @notice Get the staked gene for a specific trait type
     * @param traitType The trait type to query
     * @return geneContract The Gene contract address (address(0) if none)
     * @return tokenId The token ID (0 if none)
     */
    function getStakedGene(string memory traitType) external view returns (address geneContract, uint256 tokenId);
    
    /**
     * @notice Check if a specific gene is staked to this Aminal
     * @param geneContract The Gene contract address
     * @param tokenId The token ID
     * @return isStaked Whether the gene is staked
     * @return traitType The trait type it's staked as (empty if not staked)
     */
    function isGeneStaked(address geneContract, uint256 tokenId) external view returns (bool isStaked, string memory traitType);
}