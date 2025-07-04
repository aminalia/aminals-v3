// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {GeneNFTOnChain} from "src/GeneNFTOnChain.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

/**
 * @title GeneNFTFactory
 * @dev Factory contract for deploying GeneNFTOnChain collections
 * @notice Each trait type can have its own collection for better organization
 */
contract GeneNFTFactory is Ownable {
    /// @dev Mapping from trait type to deployed GeneNFT contract
    mapping(string => address) public traitTypeCollections;
    
    /// @dev Array of all deployed GeneNFT contracts
    address[] public deployedCollections;
    
    /// @dev Event emitted when a new GeneNFT collection is deployed
    event CollectionDeployed(string indexed traitType, address indexed collection);
    
    /**
     * @dev Constructor
     * @param owner The address that will own the factory
     */
    constructor(address owner) Ownable(owner) {}
    
    /**
     * @notice Deploy a new GeneNFT collection for a specific trait type
     * @param traitType The trait type this collection will represent
     * @param name The name of the collection
     * @param symbol The symbol for the collection
     * @return collection The address of the deployed collection
     */
    function deployCollection(
        string memory traitType,
        string memory name,
        string memory symbol
    ) external onlyOwner returns (address) {
        require(traitTypeCollections[traitType] == address(0), "Collection already exists for trait type");
        
        GeneNFTOnChain collection = new GeneNFTOnChain(msg.sender, name, symbol);
        
        traitTypeCollections[traitType] = address(collection);
        deployedCollections.push(address(collection));
        
        emit CollectionDeployed(traitType, address(collection));
        
        return address(collection);
    }
    
    /**
     * @notice Get the collection address for a specific trait type
     * @param traitType The trait type to query
     * @return The address of the collection
     */
    function getCollection(string memory traitType) external view returns (address) {
        return traitTypeCollections[traitType];
    }
    
    /**
     * @notice Get all deployed collections
     * @return Array of deployed collection addresses
     */
    function getAllCollections() external view returns (address[] memory) {
        return deployedCollections;
    }
}