// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC721} from "lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import {ERC721URIStorage} from "lib/openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";

/**
 * @title Aminal
 * @dev ERC721 contract for unique 1-of-1 NFTs representing Aminals
 * @dev Each Aminal is a unique NFT with its own metadata and characteristics
 */
contract Aminal is ERC721, ERC721URIStorage, Ownable {
    using Strings for uint256;

    /// @dev Counter for token IDs
    uint256 private _nextTokenId;

    /// @dev Base URI for token metadata
    string private _baseTokenURI;

    /// @dev Mapping to track if a token ID has been minted
    mapping(uint256 => bool) private _tokenExists;

    /// @dev Event emitted when a new Aminal is created
    event AminalCreated(uint256 indexed tokenId, address indexed owner, string tokenURI);

    /// @dev Event emitted when base URI is updated
    event BaseURIUpdated(string newBaseURI);

    /// @dev Error thrown when trying to mint an already existing token
    error TokenAlreadyExists(uint256 tokenId);

    /// @dev Error thrown when trying to access a non-existent token
    error TokenNotExists(uint256 tokenId);

    /// @dev Error thrown when providing invalid parameters
    error InvalidParameters();

    /**
     * @dev Constructor sets the name and symbol for the NFT collection
     * @param owner The address that will own the contract
     * @param baseURI The base URI for token metadata
     */
    constructor(
        address owner,
        string memory baseURI
    ) ERC721("Aminals", "AMINAL") Ownable(owner) {
        if (owner == address(0)) revert InvalidParameters();
        _baseTokenURI = baseURI;
    }

    /**
     * @dev Mint a new Aminal NFT to the specified address
     * @param to The address that will receive the NFT
     * @param uri The URI for the token's metadata
     * @return tokenId The ID of the newly minted token
     */
    function mint(
        address to,
        string memory uri
    ) external onlyOwner returns (uint256) {
        if (to == address(0)) revert InvalidParameters();
        
        uint256 tokenId = _nextTokenId++;
        
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
        
        emit AminalCreated(tokenId, to, uri);
        
        return tokenId;
    }

    /**
     * @dev Set the base URI for token metadata
     * @param newBaseURI The new base URI
     */
    function setBaseURI(string memory newBaseURI) external onlyOwner {
        _baseTokenURI = newBaseURI;
        emit BaseURIUpdated(newBaseURI);
    }

    /**
     * @dev Get the total number of tokens minted
     * @return The total supply of tokens
     */
    function totalSupply() external view returns (uint256) {
        return _nextTokenId;
    }

    /**
     * @dev Check if a token exists
     * @param tokenId The token ID to check
     * @return True if the token exists, false otherwise
     */
    function exists(uint256 tokenId) external view returns (bool) {
        return _ownerOf(tokenId) != address(0);
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
        return _baseTokenURI;
    }

    /**
     * @dev Override supportsInterface to support both ERC721 and ERC721URIStorage
     * @param interfaceId The interface ID to check
     * @return True if the interface is supported
     */
    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721URIStorage) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}