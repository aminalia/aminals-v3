// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC721} from "lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import {ERC721URIStorage} from "lib/openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {ERC721Enumerable} from "lib/openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

/**
 * @title GeneNFT
 * @dev ERC721 contract for trait-based NFTs that represent genetic components
 * @dev Unlike Aminals, GeneNFTs are regular NFTs with standard ID schemes (1, 2, 3, etc.)
 */
contract GeneNFT is ERC721, ERC721URIStorage, ERC721Enumerable, Ownable {
    /// @dev Base URI for token metadata
    string public baseTokenURI;

    /// @dev The trait type this GeneNFT collection represents (e.g., "BACK", "ARM", "TAIL")
    string public traitType;

    /// @dev The specific trait value for this GeneNFT collection (e.g., "Dragon Wings", "Fire Tail")
    string public traitValue;

    /// @dev Current token ID counter
    uint256 public currentTokenId;

    /// @dev Event emitted when a GeneNFT is created
    event GeneNFTCreated(uint256 indexed tokenId, address indexed owner, string tokenURI);

    /// @dev Event emitted when base URI is updated
    event BaseURIUpdated(string newBaseURI);

    /// @dev Error thrown when providing invalid parameters
    error InvalidParameters();

    /**
     * @dev Constructor sets the collection details and immutable trait information
     * @param owner The address that will own the contract
     * @param name The name of this GeneNFT collection
     * @param symbol The symbol for this GeneNFT collection
     * @param baseURI The base URI for token metadata
     * @param _traitType The trait type this collection represents
     * @param _traitValue The specific trait value for this collection
     */
    constructor(
        address owner,
        string memory name,
        string memory symbol,
        string memory baseURI,
        string memory _traitType,
        string memory _traitValue
    ) ERC721(name, symbol) Ownable(owner) {
        if (owner == address(0)) revert InvalidParameters();
        if (bytes(_traitType).length == 0) revert InvalidParameters();
        if (bytes(_traitValue).length == 0) revert InvalidParameters();
        
        baseTokenURI = baseURI;
        traitType = _traitType;
        traitValue = _traitValue;
    }

    /**
     * @dev Mint a GeneNFT to the specified address
     * @param to The address that will receive the NFT
     * @param uri The URI for the token's metadata
     * @return tokenId The ID of the newly minted token
     */
    function mint(
        address to,
        string memory uri
    ) external onlyOwner returns (uint256) {
        if (to == address(0)) revert InvalidParameters();
        
        currentTokenId++;
        uint256 tokenId = currentTokenId;
        
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
        
        emit GeneNFTCreated(tokenId, to, uri);
        
        return tokenId;
    }

    /**
     * @dev Batch mint multiple GeneNFTs to specified addresses
     * @param recipients Array of addresses that will receive the NFTs
     * @param uris Array of URIs for the tokens' metadata
     * @return tokenIds Array of IDs of the newly minted tokens
     */
    function batchMint(
        address[] memory recipients,
        string[] memory uris
    ) external onlyOwner returns (uint256[] memory) {
        if (recipients.length != uris.length || recipients.length == 0) {
            revert InvalidParameters();
        }

        uint256[] memory tokenIds = new uint256[](recipients.length);

        for (uint256 i = 0; i < recipients.length; i++) {
            if (recipients[i] == address(0)) revert InvalidParameters();
            
            currentTokenId++;
            uint256 tokenId = currentTokenId;
            
            _safeMint(recipients[i], tokenId);
            _setTokenURI(tokenId, uris[i]);
            
            tokenIds[i] = tokenId;
            emit GeneNFTCreated(tokenId, recipients[i], uris[i]);
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
     * @dev Get the trait information for this GeneNFT collection
     * @return _traitType The trait type
     * @return _traitValue The trait value
     */
    function getTraitInfo() external view returns (string memory _traitType, string memory _traitValue) {
        return (traitType, traitValue);
    }

    /**
     * @dev Override tokenURI to return the full URI for a token
     * @param tokenId The token ID to get the URI for
     * @return The complete URI for the token
     */
    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
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