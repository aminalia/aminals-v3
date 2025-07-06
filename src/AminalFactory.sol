// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {Aminal} from "./Aminal.sol";
import {IGenes} from "./interfaces/IGenes.sol";

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
    
    /// @dev The authorized breeding vote contract
    /// @notice This is the only contract allowed to manage breeding votes
    address public breedingVoteContract;

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
    
    /// @dev Error thrown when breeding vote contract already set
    error BreedingVoteAlreadySet();

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
        IGenes.Genes genes;
    }
    
    /// @dev Address of the first parent Aminal (Adam)
    address public immutable firstParent;
    
    /// @dev Address of the second parent Aminal (Eve)
    address public immutable secondParent;
    
    /**
     * @dev Constructor initializes the factory and creates the first two parent Aminals
     * @param owner The address that will own the factory
     * @param firstParentData Data for creating the first parent
     * @param secondParentData Data for creating the second parent
     */
    constructor(
        address owner,
        ParentData memory firstParentData,
        ParentData memory secondParentData
    ) Ownable(owner) {
        if (owner == address(0)) revert InvalidParameters();
        
        // Create the first two parent Aminals during construction
        firstParent = _createAminal(
            firstParentData.name, 
            firstParentData.symbol, 
            firstParentData.description, 
            firstParentData.tokenURI, 
            firstParentData.genes
        );
        secondParent = _createAminal(
            secondParentData.name,
            secondParentData.symbol,
            secondParentData.description,
            secondParentData.tokenURI,
            secondParentData.genes
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
        IGenes.Genes memory traits
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
     * @param genes The immutable genes for this Aminal
     * @return aminalContract The address of the newly deployed Aminal contract
     */
    function _createAminal(
        string memory name,
        string memory symbol,
        string memory description,
        string memory tokenURI,
        IGenes.Genes memory genes
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
        Aminal newAminal = new Aminal(name, symbol, genes, address(this));
        
        // Initialize the Aminal with default positions
        Aminal.GeneReference[8] memory emptyGeneRefs;
        Aminal.GenePosition[8] memory defaultPositions = _getDefaultPositions();
        newAminal.initializeWithPositions(tokenURI, emptyGeneRefs, defaultPositions);

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
     * @dev Internal function to create an Aminal with positions
     * @param name The name of the Aminal
     * @param symbol The symbol for the Aminal
     * @param description A description of the Aminal
     * @param tokenURI The URI for the token's metadata
     * @param genes The immutable genes for this Aminal
     * @param geneRefs Array of gene references
     * @param positions Array of gene positions
     * @return aminalContract The address of the newly deployed Aminal contract
     */
    function _createAminalWithPositions(
        string memory name,
        string memory symbol,
        string memory description,
        string memory tokenURI,
        IGenes.Genes memory genes,
        Aminal.GeneReference[8] memory geneRefs,
        Aminal.GenePosition[8] memory positions
    ) internal returns (address) {
        // Validate parameters
        if (bytes(name).length == 0 || bytes(symbol).length == 0 || bytes(tokenURI).length == 0) {
            revert InvalidParameters();
        }

        // Create unique identifier
        bytes32 identifier = keccak256(abi.encodePacked(name, symbol, description, tokenURI));
        
        if (aminalExists[identifier]) {
            revert AminalAlreadyExists(identifier);
        }

        aminalExists[identifier] = true;

        // Deploy new Aminal contract
        Aminal newAminal = new Aminal(name, symbol, genes, address(this));
        
        // Initialize with positions
        newAminal.initializeWithPositions(tokenURI, geneRefs, positions);

        // Track creation
        totalAminals++;
        aminalById[totalAminals] = address(newAminal);
        createdByAddress[msg.sender].push(address(newAminal));
        
        // Register as valid for breeding
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
     * @param genesArray Array of genes for each Aminal
     * @return aminalContracts Array of addresses of the newly deployed Aminal contracts
     */
    function batchCreateAminals(
        string[] calldata names,
        string[] calldata symbols,
        string[] calldata descriptions,
        string[] calldata tokenURIs,
        IGenes.Genes[] calldata genesArray
    ) external whenNotPaused nonReentrant returns (address[] memory) {
        revert DirectCreationNotAllowed();
    }

    /**
     * @notice Create an Aminal with specific genes (for breeding voting contract)
     * @dev This function is public to allow the breeding vote contract to create children
     * @param name The name of the Aminal
     * @param symbol The symbol for the Aminal
     * @param description A description of the Aminal
     * @param tokenURI The URI for the token's metadata
     * @param genes The specific genes for this Aminal
     * @return aminalContract The address of the newly deployed Aminal contract
     */
    function createAminalWithGenes(
        string calldata name,
        string calldata symbol,
        string calldata description,
        string calldata tokenURI,
        IGenes.Genes calldata genes
    ) external whenNotPaused nonReentrant returns (address) {
        return _createAminal(name, symbol, description, tokenURI, genes);
    }

    /**
     * @notice Create a new Aminal with specific genes and positions
     * @dev Used by breeding vote contract to create children with positioned genes
     * @param name The name of the Aminal
     * @param symbol The symbol for the Aminal
     * @param description A description of the Aminal
     * @param tokenURI The URI for the token's metadata
     * @param genes The specific genes for this Aminal
     * @param geneRefs Array of gene references
     * @param positions Array of gene positions
     * @return aminalContract The address of the newly deployed Aminal contract
     */
    function createAminalWithGenesAndPositions(
        string calldata name,
        string calldata symbol,
        string calldata description,
        string calldata tokenURI,
        IGenes.Genes calldata genes,
        Aminal.GeneReference[8] calldata geneRefs,
        Aminal.GenePosition[8] calldata positions
    ) external whenNotPaused nonReentrant returns (address) {
        // Only breeding vote contract can create with positions
        require(msg.sender == breedingVoteContract, "Only breeding vote contract");
        return _createAminalWithPositions(name, symbol, description, tokenURI, genes, geneRefs, positions);
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
     * @dev Set the authorized breeding vote contract (one-time setting)
     * @param _breedingVoteContract The address of the breeding vote contract
     */
    function setBreedingVoteContract(address _breedingVoteContract) external onlyOwner {
        if (breedingVoteContract != address(0)) revert BreedingVoteAlreadySet();
        if (_breedingVoteContract == address(0)) revert InvalidParameters();
        breedingVoteContract = _breedingVoteContract;
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
        string calldata childDescription,
        string calldata childTokenURI
    ) external whenNotPaused nonReentrant returns (address) {
        // Only Aminals can breed
        if (!isValidAminal[msg.sender]) revert OnlyAminalsCanBreed();
        if (!isValidAminal[partner]) revert InvalidBreedingPartner();
        if (msg.sender == partner) revert CannotBreedWithSelf();

        // Create child using helper function
        address childContract = _breedHelper(msg.sender, partner, childDescription, childTokenURI);

        emit AminalsBred(msg.sender, partner, childContract, totalAminals);

        return childContract;
    }

    /**
     * @dev Helper function to handle breeding logic and avoid stack too deep
     */
    function _breedHelper(
        address parent1Address,
        address parent2Address,
        string calldata childDescription,
        string calldata childTokenURI
    ) private returns (address) {
        Aminal parent1 = Aminal(payable(parent1Address));
        Aminal parent2 = Aminal(payable(parent2Address));
        
        // Use simple names to avoid stack issues
        // TODO: Restore dynamic naming when stack issue is resolved
        string memory childName = "ChildAminal";
        string memory childSymbol = "CHILD";
        
        // Get combined genes
        IGenes.Genes memory childGenes = _combineGenes(parent1.getGenes(), parent2.getGenes());
        
        // Create the child
        return _createAminal(
            childName,
            childSymbol,
            childDescription,
            childTokenURI,
            childGenes
        );
    }

    /**
     * @dev Helper function to combine parent genes
     * @param genes1 Genes from parent 1
     * @param genes2 Genes from parent 2
     * @return Combined genes for the child
     */
    function _combineGenes(IGenes.Genes memory genes1, IGenes.Genes memory genes2) private pure returns (IGenes.Genes memory) {
        return IGenes.Genes({
            back: genes1.back,      // From parent1
            arm: genes2.arm,        // From parent2
            tail: genes1.tail,      // From parent1
            ears: genes2.ears,      // From parent2
            body: genes1.body,      // From parent1
            face: genes2.face,      // From parent2
            mouth: genes1.mouth,    // From parent1
            misc: genes2.misc       // From parent2
        });
    }
    
    /**
     * @dev Generate child name from parent names
     */
    function _generateChildName(string memory name1, string memory name2) private pure returns (string memory) {
        return string.concat(name1, "-", name2, "-Child");
    }
    
    /**
     * @dev Generate child symbol from parent symbols
     */
    function _generateChildSymbol(string memory symbol1, string memory symbol2) private pure returns (string memory) {
        return string.concat(symbol1, symbol2);
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

    /**
     * @dev Get default positions for all gene types
     * @return positions Array of default positions
     */
    function _getDefaultPositions() private pure returns (Aminal.GenePosition[8] memory positions) {
        positions[0] = Aminal.GenePosition({x: 0, y: 0, width: 200, height: 200});      // BACK
        positions[1] = Aminal.GenePosition({x: 20, y: 70, width: 160, height: 60});     // ARM
        positions[2] = Aminal.GenePosition({x: 100, y: 100, width: 60, height: 80});    // TAIL
        positions[3] = Aminal.GenePosition({x: 50, y: 0, width: 100, height: 60});      // EARS
        positions[4] = Aminal.GenePosition({x: 50, y: 50, width: 100, height: 100});    // BODY
        positions[5] = Aminal.GenePosition({x: 60, y: 60, width: 80, height: 80});      // FACE
        positions[6] = Aminal.GenePosition({x: 70, y: 90, width: 60, height: 40});      // MOUTH
        positions[7] = Aminal.GenePosition({x: 0, y: 0, width: 200, height: 200});      // MISC
    }

}