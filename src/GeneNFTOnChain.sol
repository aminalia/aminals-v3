// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC721} from "lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import {ERC721Enumerable} from "lib/openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {Base64} from "lib/openzeppelin-contracts/contracts/utils/Base64.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ITraits} from "src/interfaces/ITraits.sol";

/**
 * @title GeneNFTOnChain
 * @dev Fully onchain ERC721 NFT contract for trait-based NFTs with SVG generation
 * @dev Each NFT represents a genetic trait that can be composed into larger Aminals
 * @notice Features dual output: raw SVG for composability and OpenSea-compatible metadata
 */
contract GeneNFTOnChain is ERC721, ERC721Enumerable, Ownable {
    using Strings for uint256;

    /// @dev Current token ID counter
    uint256 public currentTokenId;

    /// @dev Struct to store gene information
    struct Gene {
        string traitType;    // e.g., "back", "arm", "tail"
        string traitValue;   // e.g., "Dragon Wings", "Fire Tail"
        string svg;          // Raw SVG data for the trait
        string description;  // Description of the trait
    }

    /// @dev Mapping from token ID to gene data
    mapping(uint256 => Gene) public genes;

    /// @dev Event emitted when a GeneNFT is created
    event GeneNFTCreated(
        uint256 indexed tokenId, 
        address indexed owner, 
        string traitType, 
        string traitValue
    );

    /// @dev Error thrown when providing invalid parameters
    error InvalidParameters();

    /**
     * @dev Constructor sets the collection details
     * @param owner The address that will own the contract
     * @param name The name of this GeneNFT collection
     * @param symbol The symbol for this GeneNFT collection
     */
    constructor(
        address owner,
        string memory name,
        string memory symbol
    ) ERC721(name, symbol) Ownable(owner) {
        if (owner == address(0)) revert InvalidParameters();
    }

    /**
     * @notice Mint a GeneNFT with onchain SVG data
     * @dev Anyone can mint GeneNFTs. Traits are permanent and cannot be modified after minting.
     * @param to The address that will receive the NFT
     * @param traitType The trait type this NFT represents (e.g., "back", "arm")
     * @param traitValue The specific trait value (e.g., "Dragon Wings", "Fire Tail")
     * @param svg The raw SVG data for this trait (without outer <svg> tags for composability)
     * @param description Description of the trait
     * @return tokenId The ID of the newly minted token
     */
    function mint(
        address to,
        string memory traitType,
        string memory traitValue,
        string memory svg,
        string memory description
    ) external returns (uint256) {
        if (to == address(0)) revert InvalidParameters();
        if (bytes(traitType).length == 0) revert InvalidParameters();
        if (bytes(traitValue).length == 0) revert InvalidParameters();
        if (bytes(svg).length == 0) revert InvalidParameters();
        
        currentTokenId++;
        uint256 tokenId = currentTokenId;
        
        genes[tokenId] = Gene({
            traitType: traitType,
            traitValue: traitValue,
            svg: svg,
            description: description
        });
        
        _safeMint(to, tokenId);
        
        emit GeneNFTCreated(tokenId, to, traitType, traitValue);
        
        return tokenId;
    }

    /**
     * @notice Get the raw SVG for a gene (for composing into larger Aminals)
     * @dev Returns just the inner SVG elements without wrapper, ready for composition
     * @param tokenId The token ID to get the SVG for
     * @return The raw SVG data for the gene
     */
    function gene(uint256 tokenId) external view returns (string memory) {
        _requireOwned(tokenId);
        return genes[tokenId].svg;
    }

    /**
     * @notice Get the trait information for a specific token
     * @param tokenId The token ID to query
     * @return traitType The trait type
     * @return traitValue The trait value
     * @return svg The raw SVG data
     * @return description The trait description
     */
    function getGene(uint256 tokenId) external view returns (
        string memory traitType,
        string memory traitValue,
        string memory svg,
        string memory description
    ) {
        _requireOwned(tokenId);
        Gene memory g = genes[tokenId];
        return (g.traitType, g.traitValue, g.svg, g.description);
    }

    /**
     * @notice Generate a standalone SVG image for viewing the gene NFT
     * @dev Wraps the raw gene SVG in a proper SVG container with background
     * @param tokenId The token ID to generate the image for
     * @return The complete SVG image as a string
     */
    function generateStandaloneSVG(uint256 tokenId) public view returns (string memory) {
        _requireOwned(tokenId);
        Gene memory g = genes[tokenId];
        
        // Create a standalone SVG with background and proper viewport
        return string(abi.encodePacked(
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 500 500">',
            '<rect width="500" height="500" fill="#f0f0f0"/>',
            '<text x="250" y="50" text-anchor="middle" font-family="Arial" font-size="20" fill="#333">',
            g.traitType, ': ', g.traitValue,
            '</text>',
            '<g transform="translate(250, 250)">',
            g.svg,
            '</g>',
            '</svg>'
        ));
    }

    /**
     * @notice Get the OpenSea-compatible metadata URI for a token
     * @dev Returns a data URI with base64-encoded JSON metadata
     * @param tokenId The token ID to get the URI for
     * @return The complete data URI with metadata
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireOwned(tokenId);
        Gene memory g = genes[tokenId];
        
        // Generate the standalone SVG image
        string memory svgImage = generateStandaloneSVG(tokenId);
        string memory svgBase64 = Base64.encode(bytes(svgImage));
        
        // Create the JSON metadata
        string memory json = string(abi.encodePacked(
            '{',
            '"name": "', g.traitType, ': ', g.traitValue, '",',
            '"description": "', g.description, '",',
            '"image": "data:image/svg+xml;base64,', svgBase64, '",',
            '"attributes": [',
                '{',
                    '"trait_type": "Type",',
                    '"value": "', g.traitType, '"',
                '},',
                '{',
                    '"trait_type": "Value",',
                    '"value": "', g.traitValue, '"',
                '}',
            ']',
            '}'
        ));
        
        // Return as base64-encoded data URI
        return string(abi.encodePacked(
            'data:application/json;base64,',
            Base64.encode(bytes(json))
        ));
    }

    /**
     * @notice Get all tokens with a specific trait type
     * @param traitType The trait type to search for
     * @return tokenIds Array of token IDs with the specified trait type
     */
    function getTokensByTraitType(string memory traitType) external view returns (uint256[] memory) {
        uint256 total = totalSupply();
        uint256[] memory matchingTokens = new uint256[](total);
        uint256 matchCount = 0;
        
        for (uint256 i = 1; i <= currentTokenId; i++) {
            try this.ownerOf(i) returns (address) {
                if (keccak256(abi.encodePacked(genes[i].traitType)) == keccak256(abi.encodePacked(traitType))) {
                    matchingTokens[matchCount] = i;
                    matchCount++;
                }
            } catch {
                // Token doesn't exist, skip
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
     * @notice Get all tokens with a specific trait value
     * @param traitValue The trait value to search for
     * @return tokenIds Array of token IDs with the specified trait value
     */
    function getTokensByTraitValue(string memory traitValue) external view returns (uint256[] memory) {
        uint256 total = totalSupply();
        uint256[] memory matchingTokens = new uint256[](total);
        uint256 matchCount = 0;
        
        for (uint256 i = 1; i <= currentTokenId; i++) {
            try this.ownerOf(i) returns (address) {
                if (keccak256(abi.encodePacked(genes[i].traitValue)) == keccak256(abi.encodePacked(traitValue))) {
                    matchingTokens[matchCount] = i;
                    matchCount++;
                }
            } catch {
                // Token doesn't exist, skip
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
     * @dev Override _update to support ERC721Enumerable
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
    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}