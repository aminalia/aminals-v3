// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {Aminal} from "./Aminal.sol";
import {ITraits} from "./interfaces/ITraits.sol";

/**
 * @title AminalFactory
 * @author Aminals Protocol
 * @notice Factory contract for creating unique, self-sovereign Aminal NFTs
 * 
 * @dev ARCHITECTURE OVERVIEW:
 * This factory deploys each Aminal as a separate, independent smart contract rather than
 * managing multiple tokens within a single contract. This unique architecture provides:
 * 
 * 1. TRUE UNIQUENESS: Each Aminal is a 1-of-1 NFT with its own contract instance
 * 2. SELF-SOVEREIGNTY: Each Aminal owns itself completely - no external control possible
 * 3. INDIVIDUAL IDENTITY: Each contract can have unique behaviors, metadata, and state
 * 4. DECENTRALIZED OWNERSHIP: No single contract or entity controls all Aminals
 * 5. COMPOSABILITY: Each Aminal can be extended with custom functionality
 * 6. AUTONOMOUS ENTITIES: Each Aminal operates independently as its own sovereign entity
 * 
 * @dev TECHNICAL DETAILS:
 * - Each Aminal contract contains exactly one NFT with token ID 1
 * - Each Aminal can only initialize once (enforced by the Aminal contract)
 * - Every Aminal gets a unique contract address that serves as its identity
 * - Each Aminal owns itself - the NFT is minted to address(this)
 * - The factory tracks all created Aminals but does not control them post-creation
 * - This approach enables true digital uniqueness and self-sovereign NFT identities
 */
contract AminalFactory is Ownable, ReentrancyGuard {

    /// @dev Total number of Aminals created (starts at 0, increments to 1, 2, 3...)
    /// @notice This represents the total count of unique Aminal contracts deployed
    uint256 public totalAminals;

    /// @dev Base URI for all Aminal metadata - passed to each new Aminal contract
    /// @notice This URI is used by individual Aminal contracts for metadata resolution
    string public baseTokenURI;

    /// @dev Mapping from Aminal ID to contract address (ID starts at 1)
    /// @notice Provides O(1) lookup of any Aminal contract by its sequential ID
    /// @dev More gas efficient than arrays for large numbers of Aminals
    mapping(uint256 => address) public aminalById;

    /// @dev Mapping to prevent duplicate Aminals based on content hash
    /// @notice Uses keccak256 hash of (name, symbol, description, tokenURI) as unique identifier
    /// @dev This ensures each Aminal concept is truly unique across all deployments
    mapping(bytes32 => bool) public aminalExists;

    /// @dev Mapping to track which Aminal contracts were created by each address
    /// @notice Maps creator address to array of deployed Aminal contract addresses
    /// @dev Note: This array approach is acceptable for per-user tracking as individual
    ///      users are unlikely to create thousands of Aminals
    mapping(address => address[]) public createdByAddress;

    /// @dev Registry of valid Aminal contracts (address => true if valid)
    /// @notice Only Aminals in this registry can breed
    mapping(address => bool) public isValidAminal;

    /// @dev Event emitted when a new Aminal is created
    event AminalFactoryCreated(
        address indexed aminalContract,
        address indexed creator,
        address indexed owner,
        uint256 aminalId,
        string name,
        string symbol,
        string description,
        string tokenURI
    );

    /// @dev Event emitted when the factory is paused/unpaused
    event FactoryPaused(bool paused);

    /// @dev Event emitted when two Aminals breed
    event AminalsBred(
        address indexed parent1,
        address indexed parent2,
        address indexed child,
        uint256 childId
    );

    /// @dev Flag to pause/unpause the factory
    bool public paused;

    /// @dev Error thrown when trying to create duplicate Aminal
    error AminalAlreadyExists(bytes32 identifier);

    /// @dev Error thrown when factory is paused
    error FactoryIsPaused();

    /// @dev Error thrown when providing invalid parameters
    error InvalidParameters();

    /// @dev Error thrown when non-Aminal tries to breed
    error OnlyAminalsCanBreed();

    /// @dev Error thrown when trying to breed with non-Aminal
    error InvalidBreedingPartner();

    /// @dev Error thrown when Aminal tries to breed with itself
    error CannotBreedWithSelf();
    
    /// @dev Error thrown when trying to create Aminals directly (only breeding allowed)
    error DirectCreationNotAllowed();

    /// @dev Modifier to check if factory is not paused
    modifier whenNotPaused() {
        if (paused) revert FactoryIsPaused();
        _;
    }

    /// @dev Structure to hold parent creation data
    struct ParentData {
        string name;
        string symbol;
        string description;
        string tokenURI;
        ITraits.Traits traits;
    }
    
    /// @dev Address of the first parent Aminal (Adam)
    address public immutable firstParent;
    
    /// @dev Address of the second parent Aminal (Eve)
    address public immutable secondParent;
    
    /**
     * @dev Constructor initializes the factory and creates the first two parent Aminals
     * @param owner The address that will own the factory
     * @param baseURI The base URI for Aminal metadata
     * @param firstParentData Data for creating the first parent
     * @param secondParentData Data for creating the second parent
     */
    constructor(
        address owner, 
        string memory baseURI,
        ParentData memory firstParentData,
        ParentData memory secondParentData
    ) Ownable(owner) {
        if (owner == address(0)) revert InvalidParameters();
        baseTokenURI = baseURI;
        
        // Create the first two parent Aminals during construction
        firstParent = _createAminal(
            firstParentData.name, 
            firstParentData.symbol, 
            firstParentData.description, 
            firstParentData.tokenURI, 
            firstParentData.traits
        );
        secondParent = _createAminal(
            secondParentData.name,
            secondParentData.symbol,
            secondParentData.description,
            secondParentData.tokenURI,
            secondParentData.traits
        );
    }

    /**
     * @notice Creates a new unique Aminal as an independent smart contract
     * @dev This function deploys a completely separate Aminal contract instance,
     *      not just a new token ID within this contract. Each Aminal becomes
     *      a self-sovereign entity with its own contract address.
     * 
     * @dev DEPLOYMENT PROCESS:
     * 1. Validates input parameters and checks for duplicates
     * 2. Deploys a new Aminal contract with unique name/symbol
     * 3. The new contract initializes itself, minting exactly one NFT (token ID 1) to itself
     * 4. The new contract can never mint again (one-time initialization enforcement)
     * 5. Returns the address of the new contract (the Aminal's "identity")
     * 6. The Aminal is now self-sovereign - it owns itself and cannot be controlled by external parties
     * 
     * @dev UNIQUENESS GUARANTEE:
     * Each Aminal is guaranteed to be unique based on the combination of
     * name, symbol, description, and tokenURI. Duplicate combinations are rejected.
     * 
     * @param name The name of the Aminal (used for contract name)
     * @param symbol The symbol for the Aminal (used for contract symbol)
     * @param description A description of the Aminal (used for uniqueness)
     * @param tokenURI The URI for the token's metadata
     * @param traits The immutable traits for this Aminal
     * @return aminalContract The address of the newly deployed Aminal contract
     */
    function createAminal(
        string memory name,
        string memory symbol,
        string memory description,
        string memory tokenURI,
        ITraits.Traits memory traits
    ) external whenNotPaused nonReentrant returns (address) {
        revert DirectCreationNotAllowed();
    }

    /**
     * @dev Internal function that handles the core Aminal contract deployment logic
     * 
     * @dev CONTRACT DEPLOYMENT FLOW:
     * 1. Input validation ensures all required parameters are provided
     * 2. Creates a unique identifier hash from the Aminal's characteristics
     * 3. Checks the identifier against existing Aminals to prevent duplicates
     * 4. Deploys a new Aminal contract instance using the `new` keyword
     * 5. Calls the initialize function on the new contract (mints token ID 1 to itself)
     * 6. Updates tracking mappings and arrays
     * 7. Emits creation event with all relevant details
     * 
     * @dev ARCHITECTURAL BENEFITS:
     * - Each Aminal gets its own contract address (true digital identity)
     * - No single point of failure or control over all Aminals
     * - Each Aminal is self-sovereign - it owns itself completely
     * - Each Aminal can evolve independently with custom functionality
     * - Gas costs are distributed across deployments rather than centralized
     * - Enables true composability with other protocols
     * 
     * @param name The name of the Aminal
     * @param symbol The symbol for the Aminal
     * @param description A description of the Aminal
     * @param tokenURI The URI for the token's metadata
     * @param traits The immutable traits for this Aminal
     * @return aminalContract The address of the newly deployed Aminal contract
     */
    function _createAminal(
        string memory name,
        string memory symbol,
        string memory description,
        string memory tokenURI,
        ITraits.Traits memory traits
    ) internal returns (address) {
        // Note: 'to' is ignored since Aminals always own themselves
        if (bytes(name).length == 0 || bytes(symbol).length == 0 || bytes(tokenURI).length == 0) {
            revert InvalidParameters();
        }

        // Create unique identifier for this Aminal based on its characteristics
        // This ensures no two Aminals can have identical properties
        bytes32 identifier = keccak256(abi.encodePacked(name, symbol, description, tokenURI));
        
        if (aminalExists[identifier]) {
            revert AminalAlreadyExists(identifier);
        }

        // Mark this Aminal as existing to prevent future duplicates
        aminalExists[identifier] = true;

        // Deploy new Aminal contract - each Aminal gets its own contract instance
        // This gives each Aminal a unique address and self-sovereign identity
        Aminal newAminal = new Aminal(name, symbol, baseTokenURI, traits);
        
        // Initialize the Aminal to mint the NFT to itself (self-sovereign)
        // Each Aminal contract can only initialize once, ensuring 1-of-1 uniqueness
        newAminal.initialize(tokenURI);

        // Track creation with efficient mapping-based approach
        totalAminals++;
        aminalById[totalAminals] = address(newAminal);
        createdByAddress[msg.sender].push(address(newAminal));
        
        // Register the Aminal as valid for breeding
        isValidAminal[address(newAminal)] = true;

        emit AminalFactoryCreated(address(newAminal), msg.sender, address(newAminal), totalAminals, name, symbol, description, tokenURI);

        return address(newAminal);
    }

    /**
     * @notice Batch creates multiple unique Aminals as separate contract instances
     * @dev This function deploys multiple independent Aminal contracts in a single transaction,
     *      with each Aminal getting its own contract address and minting exactly one NFT.
     * 
     * @dev BATCH DEPLOYMENT BENEFITS:
     * - More gas efficient than individual deployments
     * - Atomic operation - all succeed or all fail
     * - Maintains uniqueness guarantees across the batch
     * - Each Aminal still gets its own contract instance and address
     * 
     * @param names Array of names for the Aminals
     * @param symbols Array of symbols for the Aminals
     * @param descriptions Array of descriptions for the Aminals
     * @param tokenURIs Array of URIs for the tokens' metadata
     * @param traitsArray Array of traits for each Aminal
     * @return aminalContracts Array of addresses of the newly deployed Aminal contracts
     */
    function batchCreateAminals(
        string[] memory names,
        string[] memory symbols,
        string[] memory descriptions,
        string[] memory tokenURIs,
        ITraits.Traits[] memory traitsArray
    ) external whenNotPaused nonReentrant returns (address[] memory) {
        revert DirectCreationNotAllowed();
    }

    /**
     * @notice Create an Aminal with specific traits (for breeding voting contract)
     * @dev This function is public to allow the breeding vote contract to create children
     * @param name The name of the Aminal
     * @param symbol The symbol for the Aminal
     * @param description A description of the Aminal
     * @param tokenURI The URI for the token's metadata
     * @param traits The specific traits for this Aminal
     * @return aminalContract The address of the newly deployed Aminal contract
     */
    function createAminalWithTraits(
        string memory name,
        string memory symbol,
        string memory description,
        string memory tokenURI,
        ITraits.Traits memory traits
    ) external whenNotPaused nonReentrant returns (address) {
        return _createAminal(name, symbol, description, tokenURI, traits);
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
     * @dev Update the base URI for future Aminal metadata
     * @param newBaseURI The new base URI
     */
    function setBaseURI(string memory newBaseURI) external onlyOwner {
        baseTokenURI = newBaseURI;
    }


    /**
     * @notice Get a range of Aminal contracts by their IDs
     * @dev More gas efficient than returning all Aminals at once.
     *      Each returned address represents a unique, self-sovereign Aminal instance.
     * 
     * @dev USAGE:
     * Each returned address can be used to interact directly with the Aminal
     * contract, query its metadata, check ownership, or call any custom functions.
     * Use this for pagination instead of loading all Aminals at once.
     * 
     * @param startId The starting Aminal ID (1-based, inclusive)
     * @param endId The ending Aminal ID (1-based, inclusive)
     * @return aminals Array of Aminal contract addresses in the specified range
     */
    function getAminalsByRange(uint256 startId, uint256 endId) external view returns (address[] memory) {
        if (startId == 0 || startId > totalAminals || endId < startId || endId > totalAminals) {
            revert InvalidParameters();
        }
        
        uint256 length = endId - startId + 1;
        address[] memory aminals = new address[](length);
        
        for (uint256 i = 0; i < length; i++) {
            aminals[i] = aminalById[startId + i];
        }
        
        return aminals;
    }

    /**
     * @dev Get the Aminal contracts created by a specific address
     * @param creator The address to query
     * @return An array of Aminal contract addresses created by the address
     */
    function getCreatedByAddress(address creator) external view returns (address[] memory) {
        return createdByAddress[creator];
    }

    /**
     * @notice Allows two Aminals to breed and create a child Aminal
     * @dev BREEDING MECHANICS:
     * - Only valid Aminals (in the registry) can call this function
     * - The caller (msg.sender) must be a valid Aminal
     * - The partner must also be a valid Aminal
     * - Aminals cannot breed with themselves
     * - Child traits alternate between parents (parent1's back, parent2's arm, etc.)
     * - Child gets a unique name and symbol based on parent names
     * 
     * @param partner The address of the other Aminal to breed with
     * @param childDescription Description for the child Aminal
     * @param childTokenURI Token URI for the child Aminal
     * @return childContract The address of the newly created child Aminal
     */
    function breed(
        address partner,
        string memory childDescription,
        string memory childTokenURI
    ) external whenNotPaused nonReentrant returns (address) {
        // Only Aminals can breed
        if (!isValidAminal[msg.sender]) revert OnlyAminalsCanBreed();
        if (!isValidAminal[partner]) revert InvalidBreedingPartner();
        if (msg.sender == partner) revert CannotBreedWithSelf();

        // Get parent Aminals
        Aminal parent1 = Aminal(payable(msg.sender));
        Aminal parent2 = Aminal(payable(partner));

        // Get parent traits
        ITraits.Traits memory traits1 = parent1.getTraits();
        ITraits.Traits memory traits2 = parent2.getTraits();

        // Create child traits by alternating between parents
        ITraits.Traits memory childTraits = ITraits.Traits({
            back: traits1.back,      // From parent1
            arm: traits2.arm,        // From parent2
            tail: traits1.tail,      // From parent1
            ears: traits2.ears,      // From parent2
            body: traits1.body,      // From parent1
            face: traits2.face,      // From parent2
            mouth: traits1.mouth,    // From parent1
            misc: traits2.misc       // From parent2
        });

        // Generate child name and symbol from parent names
        string memory parent1Name = parent1.name();
        string memory parent2Name = parent2.name();
        string memory childName = string.concat(parent1Name, "-", parent2Name, "-Child");
        string memory childSymbol = string.concat(parent1.symbol(), parent2.symbol());

        // Create the child Aminal
        address childContract = _createAminal(
            childName,
            childSymbol,
            childDescription,
            childTokenURI,
            childTraits
        );

        emit AminalsBred(msg.sender, partner, childContract, totalAminals);

        return childContract;
    }

    /**
     * @notice Check if an Aminal with the given characteristics already exists
     * @dev Uses the same hashing mechanism as creation to check for duplicates.
     *      This prevents creating identical Aminals and ensures true uniqueness.
     * 
     * @dev UNIQUENESS CHECK:
     * Combines all identifying characteristics (name, symbol, description, tokenURI)
     * into a single hash to determine if an identical Aminal has been created.
     * 
     * @param name The name of the Aminal
     * @param symbol The symbol for the Aminal
     * @param description The description of the Aminal
     * @param tokenURI The URI for the token's metadata
     * @return True if an Aminal with these exact characteristics exists, false otherwise
     */
    function checkAminalExists(
        string memory name,
        string memory symbol,
        string memory description,
        string memory tokenURI
    ) external view returns (bool) {
        bytes32 identifier = keccak256(abi.encodePacked(name, symbol, description, tokenURI));
        return aminalExists[identifier];
    }

}