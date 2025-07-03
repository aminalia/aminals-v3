// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {Aminal} from "./Aminal.sol";

/**
 * @title AminalFactory
 * @dev Factory contract for creating and managing Aminal NFTs
 * @dev Handles the creation of unique 1-of-1 Aminals with controlled minting
 */
contract AminalFactory is Ownable, ReentrancyGuard {
    /// @dev The Aminal NFT contract
    Aminal public immutable aminalContract;

    /// @dev Counter for tracking total Aminals created
    uint256 private _totalCreated;

    /// @dev Mapping to track created Aminals by their unique identifier
    mapping(bytes32 => bool) private _aminalExists;

    /// @dev Mapping to track Aminals created by an address
    mapping(address => uint256[]) private _createdByAddress;

    /// @dev Event emitted when a new Aminal is created
    event AminalFactoryCreated(
        uint256 indexed tokenId,
        address indexed creator,
        address indexed owner,
        string name,
        string description,
        string tokenURI
    );

    /// @dev Event emitted when the factory is paused/unpaused
    event FactoryPaused(bool paused);

    /// @dev Flag to pause/unpause the factory
    bool private _paused;

    /// @dev Error thrown when trying to create duplicate Aminal
    error AminalAlreadyExists(bytes32 identifier);

    /// @dev Error thrown when factory is paused
    error FactoryIsPaused();

    /// @dev Error thrown when providing invalid parameters
    error InvalidParameters();

    /// @dev Modifier to check if factory is not paused
    modifier whenNotPaused() {
        if (_paused) revert FactoryIsPaused();
        _;
    }

    /**
     * @dev Constructor initializes the factory with an Aminal contract
     * @param owner The address that will own the factory
     * @param baseURI The base URI for Aminal metadata
     */
    constructor(address owner, string memory baseURI) Ownable(owner) {
        if (owner == address(0)) revert InvalidParameters();
        
        aminalContract = new Aminal(address(this), baseURI);
    }

    /**
     * @dev Create a new unique Aminal NFT
     * @param to The address that will receive the NFT
     * @param name The name of the Aminal
     * @param description A description of the Aminal
     * @param tokenURI The URI for the token's metadata
     * @return tokenId The ID of the newly created Aminal
     */
    function createAminal(
        address to,
        string memory name,
        string memory description,
        string memory tokenURI
    ) external onlyOwner whenNotPaused nonReentrant returns (uint256) {
        return _createAminal(to, name, description, tokenURI);
    }

    /**
     * @dev Internal function to create a new unique Aminal NFT
     * @param to The address that will receive the NFT
     * @param name The name of the Aminal
     * @param description A description of the Aminal
     * @param tokenURI The URI for the token's metadata
     * @return tokenId The ID of the newly created Aminal
     */
    function _createAminal(
        address to,
        string memory name,
        string memory description,
        string memory tokenURI
    ) internal returns (uint256) {
        if (to == address(0) || bytes(name).length == 0 || bytes(tokenURI).length == 0) {
            revert InvalidParameters();
        }

        // Create unique identifier for this Aminal
        bytes32 identifier = keccak256(abi.encodePacked(name, description, tokenURI));
        
        if (_aminalExists[identifier]) {
            revert AminalAlreadyExists(identifier);
        }

        // Mark this Aminal as existing
        _aminalExists[identifier] = true;

        // Mint the NFT
        uint256 tokenId = aminalContract.mint(to, tokenURI);

        // Track creation
        _totalCreated++;
        _createdByAddress[msg.sender].push(tokenId);

        emit AminalFactoryCreated(tokenId, msg.sender, to, name, description, tokenURI);

        return tokenId;
    }

    /**
     * @dev Batch create multiple Aminals
     * @param recipients Array of addresses that will receive the NFTs
     * @param names Array of names for the Aminals
     * @param descriptions Array of descriptions for the Aminals
     * @param tokenURIs Array of URIs for the tokens' metadata
     * @return tokenIds Array of IDs of the newly created Aminals
     */
    function batchCreateAminals(
        address[] memory recipients,
        string[] memory names,
        string[] memory descriptions,
        string[] memory tokenURIs
    ) external onlyOwner whenNotPaused nonReentrant returns (uint256[] memory) {
        if (recipients.length != names.length || 
            recipients.length != descriptions.length || 
            recipients.length != tokenURIs.length ||
            recipients.length == 0) {
            revert InvalidParameters();
        }

        uint256[] memory tokenIds = new uint256[](recipients.length);

        for (uint256 i = 0; i < recipients.length; i++) {
            tokenIds[i] = _createAminal(recipients[i], names[i], descriptions[i], tokenURIs[i]);
        }

        return tokenIds;
    }

    /**
     * @dev Pause or unpause the factory
     * @param paused True to pause, false to unpause
     */
    function setPaused(bool paused) external onlyOwner {
        _paused = paused;
        emit FactoryPaused(paused);
    }

    /**
     * @dev Update the base URI for Aminal metadata
     * @param newBaseURI The new base URI
     */
    function setBaseURI(string memory newBaseURI) external onlyOwner {
        aminalContract.setBaseURI(newBaseURI);
    }

    /**
     * @dev Get the total number of Aminals created
     * @return The total number of Aminals created by this factory
     */
    function totalCreated() external view returns (uint256) {
        return _totalCreated;
    }

    /**
     * @dev Get the Aminals created by a specific address
     * @param creator The address to query
     * @return An array of token IDs created by the address
     */
    function getCreatedByAddress(address creator) external view returns (uint256[] memory) {
        return _createdByAddress[creator];
    }

    /**
     * @dev Check if an Aminal with the given identifier exists
     * @param name The name of the Aminal
     * @param description The description of the Aminal
     * @param tokenURI The URI for the token's metadata
     * @return True if the Aminal exists, false otherwise
     */
    function aminalExists(
        string memory name,
        string memory description,
        string memory tokenURI
    ) external view returns (bool) {
        bytes32 identifier = keccak256(abi.encodePacked(name, description, tokenURI));
        return _aminalExists[identifier];
    }

    /**
     * @dev Check if the factory is paused
     * @return True if paused, false otherwise
     */
    function isPaused() external view returns (bool) {
        return _paused;
    }

    /**
     * @dev Get the address of the Aminal contract
     * @return The address of the Aminal contract
     */
    function getAminalContract() external view returns (address) {
        return address(aminalContract);
    }
}