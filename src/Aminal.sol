// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC721} from "lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import {ERC721URIStorage} from "lib/openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {IERC721} from "lib/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import {IERC721Receiver} from "lib/openzeppelin-contracts/contracts/token/ERC721/IERC721Receiver.sol";
import {ReentrancyGuard} from "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC165Checker} from "lib/openzeppelin-contracts/contracts/utils/introspection/ERC165Checker.sol";
import {IGenes} from "src/interfaces/IGenes.sol";
import {AminalVRGDA} from "src/AminalVRGDA.sol";
import {ISkill} from "src/interfaces/ISkill.sol";
import {AminalRenderer} from "src/AminalRenderer.sol";
import {LibString} from "solady/utils/LibString.sol";
import {Base64} from "solady/utils/Base64.sol";
import {AminalFactory} from "src/AminalFactory.sol";
import {IAminalBreedingVote} from "src/interfaces/IAminalBreedingVote.sol";

/**
 * @title Aminal
 * @dev Self-sovereign, non-transferable ERC721 contract for unique 1-of-1 NFTs representing Aminals
 * @dev Each Aminal contract represents exactly one NFT with token ID 1, owned by itself
 * @dev This design ensures true self-sovereignty - each Aminal owns itself and cannot be controlled by external parties
 * @dev Aminals are permanently non-transferable, ensuring their self-sovereign status cannot be compromised
 *
 * @notice SELF-SOVEREIGN ARCHITECTURE:
 * - Each Aminal is deployed as a separate smart contract instance (not just a token ID)
 * - Each Aminal owns itself completely - the NFT is minted to address(this)
 * - No external party can control or transfer an Aminal once initialized
 * - Aminals are autonomous digital entities with their own blockchain identity
 * - The contract address serves as the Aminal's permanent, unique identity
 * - Administrative functions can only be called by the contract itself
 * - Transfer functions are permanently disabled to maintain self-sovereignty
 *
 * @notice ARCHITECTURAL BENEFITS:
 * - TRUE UNIQUENESS: Each Aminal is a 1-of-1 NFT with its own contract instance
 * - SELF-SOVEREIGNTY: Complete autonomy with no external control possible
 * - IMMUTABLE IDENTITY: Contract address serves as permanent blockchain identity
 * - NON-TRANSFERABLE: Ensures permanent self-ownership and sovereignty
 * - DECENTRALIZED: No single point of control over all Aminals
 * - COMPOSABLE: Each Aminal can interact independently with other protocols
 * - AUTONOMOUS: Operates as a truly independent digital entity
 *
 * @notice RENDERING ARCHITECTURE:
 * - Each Aminal deploys its own AminalRenderer for visual composition
 * - Rendering logic is separated from core NFT functionality
 * - Data flows from Aminal → AminalRenderer when tokenURI is called
 * - See AminalRenderer contract for detailed data flow documentation
 */
contract Aminal is ERC721, ERC721URIStorage, IERC721Receiver, ReentrancyGuard {
    using Strings for uint256;
    using LibString for string;
    using ERC165Checker for address;

    /// @dev The fixed token ID for this Aminal (always 1)
    uint256 public constant TOKEN_ID = 1;


    /// @dev Flag to track if the Aminal has been minted
    bool public minted;

    /// @dev Flag to track if the Aminal has been initialized (prevents re-initialization)
    bool public initialized;


    /// @dev The traits for this specific Aminal
    /// @notice These traits are set once during construction and cannot be changed
    /// @dev While not immutable due to Solidity limitations, they are effectively immutable
    ///      as the contract has no functions to modify them
    IGenes.Genes public genes;

    /// @dev Structure to store a Gene reference
    struct GeneReference {
        address geneContract;  // The Gene contract address
        uint256 tokenId;       // The specific token ID
    }
    
    /// @dev Immutable Gene references for each trait type
    /// @notice These define the visual appearance of the Aminal by referencing specific Genes
    GeneReference public backGene;
    GeneReference public armGene;
    GeneReference public tailGene;
    GeneReference public earsGene;
    GeneReference public bodyGene;
    GeneReference public faceGene;
    GeneReference public mouthGene;
    GeneReference public miscGene;

    /// @dev Total love received by this Aminal (in energy units)
    /// @notice Love is tracked per-user to create individual relationships
    uint256 public totalLove;

    /// @dev Mapping from user address to amount of love they've given (in energy units)
    /// @notice Each user builds their own bond with the Aminal through their love contributions
    mapping(address => uint256) public loveFromUser;

    /// @dev Current energy level of this Aminal (global per Aminal, shared by all users)
    /// @notice Energy is shared globally as it represents the Aminal's overall vitality,
    ///         while love is per-user to maintain individual connections and prevent exploitation
    uint256 public energy;

    /// @dev VRGDA contract for calculating feeding costs
    AminalVRGDA public immutable vrgda;
    
    /// @dev Renderer contract for generating metadata
    AminalRenderer public immutable renderer;
    
    /// @dev Factory contract that created this Aminal
    address public immutable factory;

    /// @dev Event emitted when the Aminal is created
    event AminalCreated(uint256 indexed tokenId, address indexed owner, string tokenURI);


    /// @dev Event emitted when someone sends love (ETH) to the Aminal
    event LoveReceived(address indexed from, uint256 amount, uint256 totalLove);

    /// @dev Event emitted when the Aminal is fed (receives ETH) and gains energy
    event EnergyGained(address indexed from, uint256 amount, uint256 newEnergy);

    /// @dev Event emitted when the Aminal loses energy through skill usage
    event EnergyLost(address indexed squeaker, uint256 amount, uint256 newEnergy);

    /// @dev Event emitted when love is consumed through skill usage
    event LoveConsumed(address indexed squeaker, uint256 amount, uint256 remainingLove);

    /// @dev Event emitted when a skill is used
    event SkillUsed(address indexed user, uint256 energyCost, address indexed target, bytes4 indexed selector);

    /// @dev Error thrown when trying to mint more than one token
    error AlreadyMinted();

    /// @dev Error thrown when providing invalid parameters
    error InvalidParameters();

    /// @dev Error thrown when trying to squeak with insufficient energy
    error InsufficientEnergy();

    /// @dev Error thrown when trying to squeak with insufficient love
    error InsufficientLove();

    /// @dev Error thrown when trying to initialize an already initialized contract
    error AlreadyInitialized();

    /// @dev Error thrown when trying to call restricted functions from unauthorized addresses
    error NotAuthorized();

    /// @dev Error thrown when trying to transfer a non-transferable NFT
    error TransferNotAllowed();

    /// @dev Error thrown when skill call fails
    error SkillCallFailed();
    
    /// @dev Error thrown when target doesn't support ISkill interface
    error SkillNotSupported();

    /**
     * @dev Constructor sets the name and symbol for the NFT collection and immutable traits
     * @dev This contract is self-sovereign - it owns itself and cannot be controlled by external parties
     * @notice DATA FLOW - Renderer Initialization:
     *         1. Deploys a new AminalRenderer instance specifically for this Aminal
     *         2. Stores the renderer address as an immutable variable
     *         3. The renderer will later access this contract's public data for composition
     * @param name The name of this specific Aminal
     * @param symbol The symbol for this specific Aminal
     * @param _genes The immutable genes for this Aminal
     * @param _factory The factory contract that deployed this Aminal
     */
    constructor(
        string memory name,
        string memory symbol,
        IGenes.Genes memory _genes,
        address _factory
    ) ERC721(name, symbol) {
        factory = _factory;
        
        // Set the genes struct
        genes = _genes;
        
        // Initialize Logistic VRGDA with parameters for love calculation:
        // - Target price: 1 ETH (baseline price for VRGDA calculation)
        // - Price decay: 1% for very gradual changes
        // - Logistic asymptote: 30 for very early curve start
        // - Time scale: 30 for extremely smooth transition
        // This creates an extremely gradual S-curve where love diminishes very smoothly
        vrgda = new AminalVRGDA(
            int256(1 ether),  // Base price for VRGDA
            0.01e18,          // 1% decay for very gradual changes
            30e18,            // Low asymptote for very early curve activation
            30e18             // Large time scale for very smooth transition
        );
        
        // Deploy the renderer for this Aminal
        renderer = new AminalRenderer();
    }

    /**
     * @dev Initialize the contract by minting the single Aminal NFT to itself (backward compatible)
     * @dev This function can only be called once and makes the Aminal self-sovereign
     * @param uri The URI for the token's metadata
     * @return tokenId The ID of the newly minted token (always 1)
     */
    function initialize(string memory uri) external returns (uint256) {
        GeneReference[8] memory emptyGenes;
        return this.initialize(uri, emptyGenes);
    }

    /**
     * @dev Initialize the contract by minting the single Aminal NFT to itself and setting gene references
     * @dev This function can only be called once and makes the Aminal self-sovereign
     * @param uri The URI for the token's metadata (can be empty as we'll generate it from genes)
     * @param geneRefs Array of gene references in order: back, arm, tail, ears, body, face, mouth, misc
     * @return tokenId The ID of the newly minted token (always 1)
     */
    function initialize(string calldata uri, GeneReference[8] calldata geneRefs) public returns (uint256) {
        if (minted) revert AlreadyMinted();
        if (initialized) revert AlreadyInitialized();
        
        initialized = true;
        minted = true;
        
        // Set the immutable gene references
        backGene = geneRefs[0];
        armGene = geneRefs[1];
        tailGene = geneRefs[2];
        earsGene = geneRefs[3];
        bodyGene = geneRefs[4];
        faceGene = geneRefs[5];
        mouthGene = geneRefs[6];
        miscGene = geneRefs[7];
        
        // Mint to self - the Aminal owns itself!
        _safeMint(address(this), TOKEN_ID);
        _setTokenURI(TOKEN_ID, uri);
        
        emit AminalCreated(TOKEN_ID, address(this), uri);
        
        return TOKEN_ID;
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
     * @dev Compose the Aminal's appearance from its Genes
     * @notice DATA FLOW: This is a convenience function that delegates to the renderer
     *         1. Passes the entire Aminal contract instance (`this`) to renderer.composeAminal()
     *         2. The renderer accesses gene references and traits from this contract
     *         3. Returns the fully composed SVG string
     * @dev This separation allows the Aminal contract to remain focused on core NFT logic
     *      while the renderer handles all visual composition complexity
     * @return The composed SVG as a string
     */
    function composeAminal() public view returns (string memory) {
        // Delegate to renderer for composition
        return renderer.composeAminal(this);
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
     * @dev Get all genes for this Aminal
     * @return The complete genes struct for this Aminal
     */
    function getGenes() external view returns (IGenes.Genes memory) {
        return genes;
    }



    /**
     * @notice Receive function to accept ETH, track love using VRGDA, and increase energy by fixed amount
     * @dev When ETH is sent to this contract:
     *      - Energy increases by a fixed rate (10,000 energy per ETH) - global per Aminal
     *      - Love received varies based on current energy level via VRGDA - per user per Aminal
     *      - High energy = less love per ETH, Low energy = more love per ETH
     * @dev This design ensures fair resource consumption: users can only squeak using their own love,
     *      preventing free-riding while energy remains a shared resource representing overall health
     */
    receive() external payable {
        if (msg.value > 0) {
            // Calculate love gained using VRGDA based on current energy
            // More energy = less love per ETH
            uint256 loveGained = vrgda.getLoveForETH(energy, msg.value);
            
            // Track love
            totalLove += loveGained;
            loveFromUser[msg.sender] += loveGained;
            
            // Energy increases by fixed amount (10,000 per ETH)
            uint256 energyGained = (msg.value * vrgda.ENERGY_PER_ETH()) / 1 ether;
            energy += energyGained;
            
            emit LoveReceived(msg.sender, loveGained, totalLove);
            emit EnergyGained(msg.sender, energyGained, energy);
        }
    }

    /**
     * @dev Get the amount of love a specific user has given to this Aminal
     * @param user The address to query
     * @return The amount of love (in wei) the user has given
     */
    function getLoveFromUser(address user) external view returns (uint256) {
        return loveFromUser[user];
    }

    /**
     * @dev Get the total amount of love this Aminal has received
     * @return The total amount of love (in wei) received
     */
    function getTotalLove() external view returns (uint256) {
        return totalLove;
    }


    /**
     * @notice Use a skill by calling an external function and consuming energy/love
     * @dev Only works with contracts implementing the ISkill interface
     * @dev Consumes resources equally based on the cost:
     *      - Energy: Deducted from global pool (per Aminal, shared by all users)
     *      - Love: Deducted from caller's personal love balance (per user per Aminal)
     * @dev Protected against reentrancy attacks with nonReentrant modifier
     * @dev SECURITY: Always calls with 0 ETH value to prevent draining funds through skills
     * @param target The contract address to call
     * @param data The raw ABI-encoded calldata for the skill
     */
    function useSkill(address target, bytes calldata data) external nonReentrant {
        // Check if the target implements ISkill interface
        if (!target.supportsInterface(type(ISkill).interfaceId)) {
            revert SkillNotSupported();
        }
        
        // Extract function selector for event
        bytes4 selector = bytes4(data);
        
        // Get the cost from the skill contract
        uint256 energyCost;
        try ISkill(target).skillCost(data) returns (uint256 cost) {
            energyCost = cost;
        } catch {
            // If cost query fails, default to 1
            energyCost = 1;
        }
        
        // Cap at a reasonable maximum to prevent accidental huge costs
        if (energyCost > 10000) {
            energyCost = energy > 10000 ? 10000 : energy;
        }
        
        // Ensure minimum cost of 1
        if (energyCost == 0) {
            energyCost = 1;
        }
        
        // Check resources before execution
        if (energy < energyCost) revert InsufficientEnergy();
        if (loveFromUser[msg.sender] < energyCost) revert InsufficientLove();
        
        // Execute the skill first (before consuming resources)
        // CRITICAL: Use call with 0 value to prevent spending ETH
        (bool success,) = target.call{value: 0}(data);
        if (!success) revert SkillCallFailed();
        
        // Only consume resources after successful execution
        energy -= energyCost;
        loveFromUser[msg.sender] -= energyCost;
        totalLove -= energyCost;
        
        emit EnergyLost(msg.sender, energyCost, energy);
        emit LoveConsumed(msg.sender, energyCost, loveFromUser[msg.sender]);
        emit SkillUsed(msg.sender, energyCost, target, selector);
    }


    /**
     * @dev Get the current energy level of this Aminal
     * @return The current energy level
     */
    function getEnergy() external view returns (uint256) {
        return energy;
    }

    /**
     * @notice Get the current love multiplier based on energy level
     * @dev Returns how much love is gained per 1 ETH
     * @return The love amount gained per 1 ETH (in wei)
     */
    function getCurrentLoveMultiplier() external view returns (uint256) {
        return vrgda.getLoveMultiplier(energy);
    }

    /**
     * @notice Calculate how much love would be gained for a given ETH amount
     * @param ethAmount The amount of ETH to calculate love for
     * @return The amount of love that would be gained
     */
    function calculateLoveForETH(uint256 ethAmount) external view returns (uint256) {
        return vrgda.getLoveForETH(energy, ethAmount);
    }

    /**
     * @dev Override _update to prevent all transfers - Aminals are non-transferable
     * @dev This ensures permanent self-sovereignty - once an Aminal owns itself, it cannot be transferred
     * @dev The only exception is during minting (from == address(0))
     */
    function _update(address to, uint256 tokenId, address auth) internal override returns (address) {
        address from = _ownerOf(tokenId);
        
        // Allow minting (from == address(0)) but prevent all transfers
        if (from != address(0)) {
            revert TransferNotAllowed();
        }
        
        return super._update(to, tokenId, auth);
    }

    /**
     * @dev Override approve to prevent approvals - not needed for non-transferable NFTs
     * @dev This prevents any approval mechanisms that could potentially be used for transfers
     */
    function approve(address /* to */, uint256 /* tokenId */) public pure override(ERC721, IERC721) {
        revert TransferNotAllowed();
    }

    /**
     * @dev Override setApprovalForAll to prevent approvals - not needed for non-transferable NFTs
     * @dev This prevents any approval mechanisms that could potentially be used for transfers
     */
    function setApprovalForAll(address /* operator */, bool /* approved */) public pure override(ERC721, IERC721) {
        revert TransferNotAllowed();
    }

    /**
     * @dev Implementation of ERC721Receiver to accept NFT transfers during initialization only
     * @dev This allows the Aminal to receive its own NFT during the initial mint, but prevents later transfers
     * @return selector The function selector to confirm receipt
     */
    function onERC721Received(
        address /* operator */,
        address /* from */,
        uint256 /* tokenId */,
        bytes calldata /* data */
    ) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    /**
     * @dev Override tokenURI to use the renderer for metadata generation
     * @notice DATA FLOW: When tokenURI is called (e.g., by OpenSea or wallets):
     *         1. This function passes the entire Aminal contract instance (`this`) to the renderer
     *         2. The renderer can then access all public state variables and functions:
     *            - name(), energy(), totalLove() for metadata description
     *            - getTraits() to determine positioning logic
     *            - Gene references (backGene, armGene, etc.) to fetch SVGs from Gene contracts
     *         3. The renderer composes the SVG and generates OpenSea-compatible metadata
     *         4. Returns a base64-encoded data URI containing the complete metadata JSON
     * @param tokenId The token ID (always 1 for Aminals)
     * @return The complete data URI with metadata
     */
    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        if (!_exists(tokenId)) revert InvalidParameters();
        return renderer.tokenURI(this, tokenId);
    }

    /**
     * @dev Check if a token exists
     * @param tokenId The token ID to check
     * @return True if the token exists
     */
    function _exists(uint256 tokenId) internal view returns (bool) {
        return tokenId == TOKEN_ID && minted;
    }

    /**
     * @notice Pay for breeding - sends 10% of balance to specified recipients
     * @dev SPECIAL CASE: This is the ONLY function that allows ETH to flow out of an Aminal
     * @dev Only callable by authorized breeding contracts to ensure security
     * @dev The caller must provide proof they are authorized by the factory
     * @param recipients Array of addresses to pay (gene owners)
     * @param breedingTicketId The breeding ticket ID for verification
     * @return totalPaid The total amount paid out
     */
    function payBreedingFee(
        address[] calldata recipients,
        uint256 breedingTicketId
    ) external nonReentrant returns (uint256 totalPaid) {
        // SECURITY: Verify caller is the authorized breeding vote contract
        address breedingVoteContract = AminalFactory(factory).breedingVoteContract();
        require(
            msg.sender == breedingVoteContract,
            "Only authorized breeding vote contract"
        );
        
        // SECURITY: Verify this Aminal is actually part of the breeding ticket
        require(
            IAminalBreedingVote(breedingVoteContract).isParentInTicket(breedingTicketId, address(this)),
            "Aminal not part of this breeding"
        );
        
        require(recipients.length > 0, "No recipients");
        require(recipients.length <= 50, "Too many recipients"); // Prevent gas griefing
        
        // Calculate 10% of balance
        totalPaid = address(this).balance / 10;
        
        if (totalPaid == 0) return 0;
        
        // Calculate payment per recipient
        uint256 paymentPerRecipient = totalPaid / recipients.length;
        uint256 distributed = 0;
        
        // Distribute payments
        for (uint256 i = 0; i < recipients.length; i++) {
            // SECURITY: Validate recipient address
            require(recipients[i] != address(0), "Invalid recipient");
            
            if (i == recipients.length - 1) {
                // Last recipient gets any remainder due to rounding
                uint256 remainder = totalPaid - distributed;
                (bool success,) = payable(recipients[i]).call{value: remainder}("");
                require(success, "Payment failed");
            } else {
                (bool success,) = payable(recipients[i]).call{value: paymentPerRecipient}("");
                require(success, "Payment failed");
                distributed += paymentPerRecipient;
            }
        }
        
        emit BreedingFeePaid(totalPaid, recipients.length, breedingTicketId);
    }
    
    /// @dev Event emitted when breeding fee is paid
    event BreedingFeePaid(uint256 totalAmount, uint256 recipientCount, uint256 breedingTicketId);
    
    /**
     * @dev Override supportsInterface to support ERC721, ERC721URIStorage, and ERC721Receiver
     * @param interfaceId The interface ID to check
     * @return True if the interface is supported
     */
    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721URIStorage) returns (bool) {
        return interfaceId == type(IERC721Receiver).interfaceId || super.supportsInterface(interfaceId);
    }
    
}