// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {Aminal} from "./Aminal.sol";

/**
 * @title AminalFactory
 * @dev Factory contract for creating and managing Aminal NFTs
 * @dev Each Aminal is deployed as a separate contract with a single NFT (token ID 1)
 */
contract AminalFactory is Ownable, ReentrancyGuard {

    /// @dev Counter for tracking total Aminals created
    uint256 private _totalCreated;

    /// @dev Base URI for all Aminal metadata
    string private _baseTokenURI;

    /// @dev Mapping to track created Aminals by their unique identifier
    mapping(bytes32 => bool) private _aminalExists;

    /// @dev Mapping to track Aminal contracts created by an address
    mapping(address => address[]) private _createdByAddress;

    /// @dev Array of all created Aminal contracts
    address[] private _allAminals;

    /// @dev Event emitted when a new Aminal is created
    event AminalFactoryCreated(
        address indexed aminalContract,
        address indexed creator,
        address indexed owner,
        string name,
        string symbol,
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
     * @dev Constructor initializes the factory
     * @param owner The address that will own the factory
     * @param baseURI The base URI for Aminal metadata
     */
    constructor(address owner, string memory baseURI) Ownable(owner) {
        if (owner == address(0)) revert InvalidParameters();
        _baseTokenURI = baseURI;
    }

    /**
     * @dev Create a new unique Aminal NFT as a separate contract
     * @param to The address that will receive the NFT
     * @param name The name of the Aminal
     * @param symbol The symbol for the Aminal
     * @param description A description of the Aminal
     * @param tokenURI The URI for the token's metadata
     * @return aminalContract The address of the newly created Aminal contract
     */
    function createAminal(
        address to,
        string memory name,
        string memory symbol,
        string memory description,
        string memory tokenURI
    ) external onlyOwner whenNotPaused nonReentrant returns (address) {
        return _createAminal(to, name, symbol, description, tokenURI);
    }

    /**
     * @dev Internal function to create a new unique Aminal NFT
     * @param to The address that will receive the NFT
     * @param name The name of the Aminal
     * @param symbol The symbol for the Aminal
     * @param description A description of the Aminal
     * @param tokenURI The URI for the token's metadata
     * @return aminalContract The address of the newly created Aminal contract
     */
    function _createAminal(
        address to,
        string memory name,
        string memory symbol,
        string memory description,
        string memory tokenURI
    ) internal returns (address) {
        if (to == address(0) || bytes(name).length == 0 || bytes(symbol).length == 0 || bytes(tokenURI).length == 0) {
            revert InvalidParameters();
        }

        // Create unique identifier for this Aminal
        bytes32 identifier = keccak256(abi.encodePacked(name, symbol, description, tokenURI));
        
        if (_aminalExists[identifier]) {
            revert AminalAlreadyExists(identifier);
        }

        // Mark this Aminal as existing
        _aminalExists[identifier] = true;

        // Deploy new Aminal contract
        Aminal newAminal = new Aminal(address(this), name, symbol, _baseTokenURI);
        
        // Mint the single NFT
        newAminal.mint(to, tokenURI);

        // Track creation
        _totalCreated++;
        _createdByAddress[msg.sender].push(address(newAminal));
        _allAminals.push(address(newAminal));

        emit AminalFactoryCreated(address(newAminal), msg.sender, to, name, symbol, description, tokenURI);

        return address(newAminal);
    }

    /**
     * @dev Batch create multiple Aminals
     * @param recipients Array of addresses that will receive the NFTs
     * @param names Array of names for the Aminals
     * @param symbols Array of symbols for the Aminals
     * @param descriptions Array of descriptions for the Aminals
     * @param tokenURIs Array of URIs for the tokens' metadata
     * @return aminalContracts Array of addresses of the newly created Aminal contracts
     */
    function batchCreateAminals(
        address[] memory recipients,
        string[] memory names,
        string[] memory symbols,
        string[] memory descriptions,
        string[] memory tokenURIs
    ) external onlyOwner whenNotPaused nonReentrant returns (address[] memory) {
        if (recipients.length != names.length || 
            recipients.length != symbols.length ||
            recipients.length != descriptions.length || 
            recipients.length != tokenURIs.length ||
            recipients.length == 0) {
            revert InvalidParameters();
        }

        address[] memory aminalContracts = new address[](recipients.length);

        for (uint256 i = 0; i < recipients.length; i++) {
            aminalContracts[i] = _createAminal(recipients[i], names[i], symbols[i], descriptions[i], tokenURIs[i]);
        }

        return aminalContracts;
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
     * @dev Update the base URI for future Aminal metadata
     * @param newBaseURI The new base URI
     */
    function setBaseURI(string memory newBaseURI) external onlyOwner {
        _baseTokenURI = newBaseURI;
    }

    /**
     * @dev Get the total number of Aminals created
     * @return The total number of Aminals created by this factory
     */
    function totalCreated() external view returns (uint256) {
        return _totalCreated;
    }

    /**
     * @dev Get the Aminal contracts created by a specific address
     * @param creator The address to query
     * @return An array of Aminal contract addresses created by the address
     */
    function getCreatedByAddress(address creator) external view returns (address[] memory) {
        return _createdByAddress[creator];
    }

    /**
     * @dev Get all created Aminal contracts
     * @return An array of all Aminal contract addresses
     */
    function getAllAminals() external view returns (address[] memory) {
        return _allAminals;
    }

    /**
     * @dev Check if an Aminal with the given identifier exists
     * @param name The name of the Aminal
     * @param symbol The symbol for the Aminal
     * @param description The description of the Aminal
     * @param tokenURI The URI for the token's metadata
     * @return True if the Aminal exists, false otherwise
     */
    function aminalExists(
        string memory name,
        string memory symbol,
        string memory description,
        string memory tokenURI
    ) external view returns (bool) {
        bytes32 identifier = keccak256(abi.encodePacked(name, symbol, description, tokenURI));
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
     * @dev Get the current base URI for metadata
     * @return The current base URI
     */
    function getBaseURI() external view returns (string memory) {
        return _baseTokenURI;
    }
}