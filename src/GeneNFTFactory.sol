// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {GeneNFT} from "./GeneNFT.sol";

/**
 * @title GeneNFTFactory
 * @dev Factory contract for creating GeneNFT collections
 * @dev Each GeneNFT collection represents a specific trait type and value combination
 */
contract GeneNFTFactory is Ownable, ReentrancyGuard {
    /// @dev Total number of GeneNFT collections created
    uint256 public totalCollections;

    /// @dev Base URI for all GeneNFT metadata
    string public baseTokenURI;

    /// @dev Mapping from collection ID to contract address
    mapping(uint256 => address) public collectionById;

    /// @dev Mapping to prevent duplicate collections based on trait type and value
    mapping(bytes32 => bool) public collectionExists;

    /// @dev Mapping to track which collections were created by each address
    mapping(address => address[]) public createdByAddress;

    /// @dev Mapping from trait type to array of collection addresses
    mapping(string => address[]) public collectionsByTraitType;

    /// @dev Flag to pause/unpause the factory
    bool public paused;

    /// @dev Event emitted when a new GeneNFT collection is created
    event GeneNFTCollectionCreated(
        address indexed collectionContract,
        address indexed creator,
        uint256 collectionId,
        string name,
        string symbol,
        string traitType,
        string traitValue
    );

    /// @dev Event emitted when the factory is paused/unpaused
    event FactoryPaused(bool paused);

    /// @dev Error thrown when trying to create duplicate collection
    error CollectionAlreadyExists(bytes32 identifier);

    /// @dev Error thrown when factory is paused
    error FactoryIsPaused();

    /// @dev Error thrown when providing invalid parameters
    error InvalidParameters();

    /// @dev Modifier to check if factory is not paused
    modifier whenNotPaused() {
        if (paused) revert FactoryIsPaused();
        _;
    }

    /**
     * @dev Constructor initializes the factory
     * @param owner The address that will own the factory
     * @param baseURI The base URI for GeneNFT metadata
     */
    constructor(address owner, string memory baseURI) Ownable(owner) {
        if (owner == address(0)) revert InvalidParameters();
        baseTokenURI = baseURI;
    }

    /**
     * @dev Creates a new GeneNFT collection with specific trait type and value
     * @param name The name of the GeneNFT collection
     * @param symbol The symbol for the GeneNFT collection
     * @param traitType The trait type this collection represents (e.g., "BACK", "ARM")
     * @param traitValue The specific trait value (e.g., "Dragon Wings", "Fire Tail")
     * @return collectionContract The address of the newly deployed GeneNFT contract
     */
    function createCollection(
        string memory name,
        string memory symbol,
        string memory traitType,
        string memory traitValue
    ) external onlyOwner whenNotPaused nonReentrant returns (address) {
        if (bytes(name).length == 0 || 
            bytes(symbol).length == 0 || 
            bytes(traitType).length == 0 || 
            bytes(traitValue).length == 0) {
            revert InvalidParameters();
        }

        // Create unique identifier for this collection based on trait type and value
        bytes32 identifier = keccak256(abi.encodePacked(traitType, traitValue));
        
        if (collectionExists[identifier]) {
            revert CollectionAlreadyExists(identifier);
        }

        // Mark this collection as existing
        collectionExists[identifier] = true;

        // Deploy new GeneNFT contract
        GeneNFT newCollection = new GeneNFT(
            address(this),
            name,
            symbol,
            baseTokenURI,
            traitType,
            traitValue
        );

        // Track creation
        totalCollections++;
        collectionById[totalCollections] = address(newCollection);
        createdByAddress[msg.sender].push(address(newCollection));
        collectionsByTraitType[traitType].push(address(newCollection));

        emit GeneNFTCollectionCreated(
            address(newCollection),
            msg.sender,
            totalCollections,
            name,
            symbol,
            traitType,
            traitValue
        );

        return address(newCollection);
    }

    /**
     * @dev Mint a GeneNFT from a specific collection
     * @param collectionAddress The address of the GeneNFT collection
     * @param to The address that will receive the NFT
     * @param uri The URI for the token's metadata
     * @return tokenId The ID of the newly minted token
     */
    function mintFromCollection(
        address collectionAddress,
        address to,
        string memory uri
    ) external onlyOwner whenNotPaused nonReentrant returns (uint256) {
        if (collectionAddress == address(0) || to == address(0)) {
            revert InvalidParameters();
        }

        GeneNFT collection = GeneNFT(collectionAddress);
        return collection.mint(to, uri);
    }

    /**
     * @dev Batch mint GeneNFTs from a specific collection
     * @param collectionAddress The address of the GeneNFT collection
     * @param recipients Array of addresses that will receive the NFTs
     * @param uris Array of URIs for the tokens' metadata
     * @return tokenIds Array of IDs of the newly minted tokens
     */
    function batchMintFromCollection(
        address collectionAddress,
        address[] memory recipients,
        string[] memory uris
    ) external onlyOwner whenNotPaused nonReentrant returns (uint256[] memory) {
        if (collectionAddress == address(0)) {
            revert InvalidParameters();
        }

        GeneNFT collection = GeneNFT(collectionAddress);
        return collection.batchMint(recipients, uris);
    }

    /**
     * @dev Pause or unpause the factory
     * @param _paused True to pause, false to unpause
     */
    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
        emit FactoryPaused(_paused);
    }

    /**
     * @dev Update the base URI for future GeneNFT metadata
     * @param newBaseURI The new base URI
     */
    function setBaseURI(string memory newBaseURI) external onlyOwner {
        baseTokenURI = newBaseURI;
    }

    /**
     * @dev Get collections by trait type
     * @param traitType The trait type to query
     * @return Array of collection addresses for the specified trait type
     */
    function getCollectionsByTraitType(string memory traitType) external view returns (address[] memory) {
        return collectionsByTraitType[traitType];
    }

    /**
     * @dev Get collections created by a specific address
     * @param creator The address to query
     * @return Array of collection addresses created by the address
     */
    function getCreatedByAddress(address creator) external view returns (address[] memory) {
        return createdByAddress[creator];
    }

    /**
     * @dev Get a range of collection contracts by their IDs
     * @param startId The starting collection ID (1-based, inclusive)
     * @param endId The ending collection ID (1-based, inclusive)
     * @return collections Array of collection addresses in the specified range
     */
    function getCollectionsByRange(uint256 startId, uint256 endId) external view returns (address[] memory) {
        if (startId == 0 || startId > totalCollections || endId < startId || endId > totalCollections) {
            revert InvalidParameters();
        }
        
        uint256 length = endId - startId + 1;
        address[] memory collections = new address[](length);
        
        for (uint256 i = 0; i < length; i++) {
            collections[i] = collectionById[startId + i];
        }
        
        return collections;
    }

    /**
     * @dev Check if a collection with the given trait type and value exists
     * @param traitType The trait type
     * @param traitValue The trait value
     * @return True if a collection with these traits exists
     */
    function checkCollectionExists(
        string memory traitType,
        string memory traitValue
    ) external view returns (bool) {
        bytes32 identifier = keccak256(abi.encodePacked(traitType, traitValue));
        return collectionExists[identifier];
    }
}