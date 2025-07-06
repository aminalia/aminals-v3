// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC721} from "lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import {ERC721URIStorage} from "lib/openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {ERC721Enumerable} from "lib/openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {LibString} from "solady/utils/LibString.sol";
import {Base64} from "solady/utils/Base64.sol";
import {IGenes} from "src/interfaces/IGenes.sol";
import {IGene} from "src/interfaces/IGene.sol";
import {GeneRenderer} from "src/GeneRenderer.sol";

/**
 * @title Gene
 * @dev Fully onchain ERC721 NFT contract for trait-based NFTs with SVG generation
 * @dev Each NFT represents a genetic trait that can be composed into larger Aminals
 * @notice Features dual output: raw SVG for composability and OpenSea-compatible metadata
 */
contract Gene is ERC721, ERC721URIStorage, ERC721Enumerable, Ownable, IGene {
    using LibString for uint256;
    using LibString for string;
    /// @dev Base URI for token metadata
    string public baseTokenURI;

    /// @dev Current token ID counter
    uint256 public currentTokenId;

    /// @dev Mapping from token ID to trait type (e.g., "back", "arm", "tail")
    mapping(uint256 => string) public tokenTraitType;

    /// @dev Mapping from token ID to trait value (e.g., "Dragon Wings", "Fire Tail")
    mapping(uint256 => string) public tokenTraitValue;

    /// @dev Mapping from token ID to raw SVG data for the trait
    mapping(uint256 => string) public gene;

    /// @dev Mapping from token ID to trait description
    mapping(uint256 => string) public tokenDescription;

    /// @dev Event emitted when a Gene is created
    event GeneCreated(uint256 indexed tokenId, address indexed owner, string traitType, string traitValue, string tokenURI);

    /// @dev Event emitted when base URI is updated
    event BaseURIUpdated(string newBaseURI);

    /// @dev Error thrown when providing invalid parameters
    error InvalidParameters();

    /**
     * @dev Constructor sets the collection details
     * @param owner The address that will own the contract
     * @param name The name of this Gene collection
     * @param symbol The symbol for this Gene collection
     * @param baseURI The base URI for token metadata
     */
    constructor(
        address owner,
        string memory name,
        string memory symbol,
        string memory baseURI
    ) ERC721(name, symbol) Ownable(owner) {
        if (owner == address(0)) revert InvalidParameters();
        baseTokenURI = baseURI;
    }

    /**
     * @notice Mint a Gene with onchain SVG data
     * @dev Anyone can mint Genes. Traits are permanent and cannot be modified after minting.
     * @param to The address that will receive the NFT
     * @param traitType The trait type this NFT represents (e.g., "back", "arm")
     * @param traitValue The specific trait value (e.g., "Dragon Wings", "Fire Tail")
     * @param svg The raw SVG data for this trait (without outer <svg> tags for composability)
     * @param description Description of the trait
     * @return tokenId The ID of the newly minted token
     */
    function mint(
        address to,
        string calldata traitType,
        string calldata traitValue,
        string calldata svg,
        string calldata description
    ) external returns (uint256) {
        if (to == address(0)) revert InvalidParameters();
        if (bytes(traitType).length == 0) revert InvalidParameters();
        if (bytes(traitValue).length == 0) revert InvalidParameters();
        if (bytes(svg).length == 0) revert InvalidParameters();
        
        currentTokenId++;
        uint256 tokenId = currentTokenId;
        
        tokenTraitType[tokenId] = traitType;
        tokenTraitValue[tokenId] = traitValue;
        gene[tokenId] = svg;
        tokenDescription[tokenId] = description;
        
        _safeMint(to, tokenId);
        
        emit GeneCreated(tokenId, to, traitType, traitValue, "");
        
        return tokenId;
    }

    /**
     * @notice Batch mint multiple Genes to specified addresses
     * @dev Anyone can mint Genes. Traits are permanent and cannot be modified after minting.
     * @param recipients Array of addresses that will receive the NFTs
     * @param traitTypes Array of trait types for each NFT
     * @param traitValues Array of trait values for each NFT
     * @param svgs Array of SVG data for each NFT
     * @param descriptions Array of descriptions for each NFT
     * @return tokenIds Array of IDs of the newly minted tokens
     */
    function batchMint(
        address[] calldata recipients,
        string[] calldata traitTypes,
        string[] calldata traitValues,
        string[] calldata svgs,
        string[] calldata descriptions
    ) external returns (uint256[] memory) {
        if (recipients.length != traitTypes.length || 
            recipients.length != traitValues.length ||
            recipients.length != svgs.length ||
            recipients.length != descriptions.length || 
            recipients.length == 0) {
            revert InvalidParameters();
        }

        uint256[] memory tokenIds = new uint256[](recipients.length);

        for (uint256 i = 0; i < recipients.length; i++) {
            if (recipients[i] == address(0)) revert InvalidParameters();
            if (bytes(traitTypes[i]).length == 0) revert InvalidParameters();
            if (bytes(traitValues[i]).length == 0) revert InvalidParameters();
            if (bytes(svgs[i]).length == 0) revert InvalidParameters();
            
            currentTokenId++;
            uint256 tokenId = currentTokenId;
            
            tokenTraitType[tokenId] = traitTypes[i];
            tokenTraitValue[tokenId] = traitValues[i];
            gene[tokenId] = svgs[i];
            tokenDescription[tokenId] = descriptions[i];
            
            _safeMint(recipients[i], tokenId);
            
            tokenIds[i] = tokenId;
            emit GeneCreated(tokenId, recipients[i], traitTypes[i], traitValues[i], "");
        }

        return tokenIds;
    }

    /**
     * @dev Set the base URI for token metadata
     * @param newBaseURI The new base URI
     */
    function setBaseURI(string memory newBaseURI) external onlyOwner {
        baseTokenURI = newBaseURI;
        emit BaseURIUpdated(newBaseURI);
    }

    /**
     * @dev Get the trait information for a specific token
     * @param tokenId The token ID to query
     * @return traitType The trait type
     * @return traitValue The trait value
     * @return svg The raw SVG data
     * @return description The trait description
     */
    function getTokenTraits(uint256 tokenId) external view returns (
        string memory traitType, 
        string memory traitValue,
        string memory svg,
        string memory description
    ) {
        if (!_exists(tokenId)) revert InvalidParameters();
        return (tokenTraitType[tokenId], tokenTraitValue[tokenId], gene[tokenId], tokenDescription[tokenId]);
    }

    /**
     * @notice Generate a standalone SVG image for viewing the gene NFT
     * @dev Wraps the raw gene SVG in a proper SVG container with background
     * @param tokenId The token ID to generate the image for
     * @return The complete SVG image as a string
     */
    function generateStandaloneSVG(uint256 tokenId) public view returns (string memory) {
        if (!_exists(tokenId)) revert InvalidParameters();
        
        // Use GeneRenderer for efficient SVG generation
        return GeneRenderer.generateStandaloneGeneSVG(
            tokenTraitType[tokenId],
            tokenTraitValue[tokenId],
            gene[tokenId]
        );
    }

    /**
     * @dev Get all tokens with a specific trait type
     * @param traitType The trait type to search for
     * @return tokenIds Array of token IDs with the specified trait type
     */
    function getTokensByTraitType(string calldata traitType) external view returns (uint256[] memory) {
        uint256[] memory matchingTokens = new uint256[](totalSupply());
        uint256 matchCount = 0;
        
        for (uint256 i = 1; i <= currentTokenId; i++) {
            if (_exists(i) && keccak256(abi.encodePacked(tokenTraitType[i])) == keccak256(abi.encodePacked(traitType))) {
                matchingTokens[matchCount] = i;
                matchCount++;
            }
        }
        
        // Create properly sized return array
        uint256[] memory result = new uint256[](matchCount);
        for (uint256 i = 0; i < matchCount; i++) {
            result[i] = matchingTokens[i];
        }
        
        return result;
    }

    /**
     * @dev Get all tokens with a specific trait value
     * @param traitValue The trait value to search for
     * @return tokenIds Array of token IDs with the specified trait value
     */
    function getTokensByTraitValue(string calldata traitValue) external view returns (uint256[] memory) {
        uint256[] memory matchingTokens = new uint256[](totalSupply());
        uint256 matchCount = 0;
        
        for (uint256 i = 1; i <= currentTokenId; i++) {
            if (_exists(i) && keccak256(abi.encodePacked(tokenTraitValue[i])) == keccak256(abi.encodePacked(traitValue))) {
                matchingTokens[matchCount] = i;
                matchCount++;
            }
        }
        
        // Create properly sized return array
        uint256[] memory result = new uint256[](matchCount);
        for (uint256 i = 0; i < matchCount; i++) {
            result[i] = matchingTokens[i];
        }
        
        return result;
    }

    /**
     * @notice Get the trait type this gene represents
     * @param tokenId The token ID of the gene
     * @return The trait type as a string (e.g., "back", "arm", etc.)
     */
    function traitType(uint256 tokenId) external view returns (string memory) {
        return tokenTraitType[tokenId];
    }
    
    /**
     * @notice Get the trait value/name for this gene
     * @param tokenId The token ID of the gene
     * @return The trait value (e.g., "Dragon Wings", "Fluffy Tail")
     */
    function traitValue(uint256 tokenId) external view returns (string memory) {
        return tokenTraitValue[tokenId];
    }

    /**
     * @dev Check if a token exists
     * @param tokenId The token ID to check
     * @return True if the token exists
     */
    function _exists(uint256 tokenId) internal view returns (bool) {
        return tokenId > 0 && tokenId <= currentTokenId && _ownerOf(tokenId) != address(0);
    }

    /**
     * @dev Override tokenURI to return onchain metadata with SVG
     * @param tokenId The token ID to get the URI for
     * @return The complete data URI with metadata
     */
    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        if (!_exists(tokenId)) revert InvalidParameters();
        
        // Use the raw gene SVG for the image
        string memory svgImage = gene[tokenId];
        
        // Create the metadata using GeneRenderer
        string memory name = string.concat(tokenTraitType[tokenId], ': ', tokenTraitValue[tokenId]);
        string memory imageDataURI = GeneRenderer.svgToBase64DataURI(svgImage);
        
        string memory json = GeneRenderer.generateMetadata(
            name,
            tokenDescription[tokenId],
            imageDataURI,
            tokenTraitType[tokenId],
            tokenTraitValue[tokenId]
        );
        
        // Return as base64-encoded data URI
        return GeneRenderer.jsonToBase64DataURI(json);
    }

    /**
     * @dev Override _baseURI to return the base URI
     * @return The base URI for tokens
     */
    function _baseURI() internal view override returns (string memory) {
        return baseTokenURI;
    }

    /**
     * @dev Override _update to support both ERC721Enumerable and base ERC721
     * @param to The address receiving the token
     * @param tokenId The token ID being transferred
     * @param auth The authorized address
     * @return The previous owner
     */
    function _update(address to, uint256 tokenId, address auth) internal override(ERC721, ERC721Enumerable) returns (address) {
        return super._update(to, tokenId, auth);
    }

    /**
     * @dev Override _increaseBalance to support ERC721Enumerable
     * @param account The account whose balance is being increased
     * @param value The amount to increase
     */
    function _increaseBalance(address account, uint128 value) internal override(ERC721, ERC721Enumerable) {
        super._increaseBalance(account, value);
    }


    /**
     * @dev Override supportsInterface to support all implemented interfaces
     * @param interfaceId The interface ID to check
     * @return True if the interface is supported
     */
    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721URIStorage, ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}