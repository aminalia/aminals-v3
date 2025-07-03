// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC721} from "lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import {ERC721URIStorage} from "lib/openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";

/**
 * @title Aminal
 * @dev ERC721 contract for unique 1-of-1 NFTs representing Aminals
 * @dev Each Aminal contract represents exactly one NFT with token ID 1
 */
contract Aminal is ERC721, ERC721URIStorage, Ownable {
    using Strings for uint256;

    /// @dev The fixed token ID for this Aminal (always 1)
    uint256 public constant TOKEN_ID = 1;

    /// @dev Base URI for token metadata
    string public baseTokenURI;

    /// @dev Flag to track if the Aminal has been minted
    bool public minted;

    /// @dev Struct defining all traits for an Aminal
    /// @notice These traits are immutable and define the Aminal's unique characteristics
    /// @dev Future versions will query these from corresponding GeneNFT contracts
    struct Traits {
        string back;
        string arm;
        string tail;
        string ears;
        string body;
        string face;
        string mouth;
        string misc;
    }

    /// @dev The traits for this specific Aminal
    /// @notice These traits are set once during construction and cannot be changed
    /// @dev While not immutable due to Solidity limitations, they are effectively immutable
    ///      as the contract has no functions to modify them
    Traits public traits;

    /// @dev Event emitted when the Aminal is created
    event AminalCreated(uint256 indexed tokenId, address indexed owner, string tokenURI);

    /// @dev Event emitted when base URI is updated
    event BaseURIUpdated(string newBaseURI);

    /// @dev Error thrown when trying to mint more than one token
    error AlreadyMinted();

    /// @dev Error thrown when providing invalid parameters
    error InvalidParameters();

    /**
     * @dev Constructor sets the name and symbol for the NFT collection and immutable traits
     * @param owner The address that will own the contract
     * @param name The name of this specific Aminal
     * @param symbol The symbol for this specific Aminal
     * @param baseURI The base URI for token metadata
     * @param _traits The immutable traits for this Aminal
     */
    constructor(
        address owner,
        string memory name,
        string memory symbol,
        string memory baseURI,
        Traits memory _traits
    ) ERC721(name, symbol) Ownable(owner) {
        if (owner == address(0)) revert InvalidParameters();
        baseTokenURI = baseURI;
        
        // Set the traits struct
        traits = _traits;
    }

    /**
     * @dev Mint the single Aminal NFT to the specified address
     * @param to The address that will receive the NFT
     * @param uri The URI for the token's metadata
     * @return tokenId The ID of the newly minted token (always 1)
     */
    function mint(
        address to,
        string memory uri
    ) external onlyOwner returns (uint256) {
        if (to == address(0)) revert InvalidParameters();
        if (minted) revert AlreadyMinted();
        
        minted = true;
        _safeMint(to, TOKEN_ID);
        _setTokenURI(TOKEN_ID, uri);
        
        emit AminalCreated(TOKEN_ID, to, uri);
        
        return TOKEN_ID;
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
     * @dev Get the total number of tokens minted (always 0 or 1)
     * @return The total supply of tokens
     */
    function totalSupply() external view returns (uint256) {
        return minted ? 1 : 0;
    }

    /**
     * @dev Check if the Aminal has been minted
     * @return True if the Aminal has been minted, false otherwise
     */
    function isMinted() external view returns (bool) {
        return minted;
    }

    /**
     * @dev Check if a token exists
     * @param tokenId The token ID to check
     * @return True if the token exists, false otherwise
     */
    function exists(uint256 tokenId) external view returns (bool) {
        return tokenId == TOKEN_ID && minted;
    }

    /**
     * @dev Get all traits for this Aminal
     * @return The complete traits struct for this Aminal
     */
    function getTraits() external view returns (Traits memory) {
        return traits;
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
     * @dev Override supportsInterface to support both ERC721 and ERC721URIStorage
     * @param interfaceId The interface ID to check
     * @return True if the interface is supported
     */
    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721URIStorage) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}