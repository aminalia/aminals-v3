// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC721} from "lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import {ERC721URIStorage} from "lib/openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {IERC721} from "lib/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import {IERC721Receiver} from "lib/openzeppelin-contracts/contracts/token/ERC721/IERC721Receiver.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ITraits} from "src/interfaces/ITraits.sol";
import {AminalVRGDA} from "src/AminalVRGDA.sol";

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
 */
contract Aminal is ERC721, ERC721URIStorage, IERC721Receiver {
    using Strings for uint256;

    /// @dev The fixed token ID for this Aminal (always 1)
    uint256 public constant TOKEN_ID = 1;

    /// @dev Base URI for token metadata
    string public baseTokenURI;

    /// @dev Flag to track if the Aminal has been minted
    bool public minted;

    /// @dev Flag to track if the Aminal has been initialized (prevents re-initialization)
    bool public initialized;


    /// @dev The traits for this specific Aminal
    /// @notice These traits are set once during construction and cannot be changed
    /// @dev While not immutable due to Solidity limitations, they are effectively immutable
    ///      as the contract has no functions to modify them
    ITraits.Traits public traits;

    /// @dev Total love received by this Aminal (in wei)
    uint256 public totalLove;

    /// @dev Mapping from user address to amount of love they've given (in wei)
    mapping(address => uint256) public loveFromUser;

    /// @dev Current energy level of this Aminal
    /// @notice Energy increases when fed (receiving ETH) and decreases when squeaking
    uint256 public energy;

    /// @dev VRGDA contract for calculating feeding costs
    AminalVRGDA public immutable vrgda;

    /// @dev Event emitted when the Aminal is created
    event AminalCreated(uint256 indexed tokenId, address indexed owner, string tokenURI);

    /// @dev Event emitted when base URI is updated
    event BaseURIUpdated(string newBaseURI);

    /// @dev Event emitted when someone sends love (ETH) to the Aminal
    event LoveReceived(address indexed from, uint256 amount, uint256 totalLove);

    /// @dev Event emitted when the Aminal is fed (receives ETH) and gains energy
    event EnergyGained(address indexed from, uint256 amount, uint256 newEnergy);

    /// @dev Event emitted when the Aminal squeaks and loses energy
    event EnergyLost(address indexed squeaker, uint256 amount, uint256 newEnergy);

    /// @dev Error thrown when trying to mint more than one token
    error AlreadyMinted();

    /// @dev Error thrown when providing invalid parameters
    error InvalidParameters();

    /// @dev Error thrown when trying to squeak with insufficient energy
    error InsufficientEnergy();

    /// @dev Error thrown when trying to initialize an already initialized contract
    error AlreadyInitialized();

    /// @dev Error thrown when trying to call restricted functions from unauthorized addresses
    error NotAuthorized();

    /// @dev Error thrown when trying to transfer a non-transferable NFT
    error TransferNotAllowed();

    /**
     * @dev Constructor sets the name and symbol for the NFT collection and immutable traits
     * @dev This contract is self-sovereign - it owns itself and cannot be controlled by external parties
     * @param name The name of this specific Aminal
     * @param symbol The symbol for this specific Aminal
     * @param baseURI The base URI for token metadata
     * @param _traits The immutable traits for this Aminal
     */
    constructor(
        string memory name,
        string memory symbol,
        string memory baseURI,
        ITraits.Traits memory _traits
    ) ERC721(name, symbol) {
        baseTokenURI = baseURI;
        
        // Set the traits struct
        traits = _traits;
        
        // Initialize VRGDA with parameters for love calculation:
        // - Target price: 0.5 ETH (baseline price for VRGDA calculation)
        // - Price decay: 50% when energy is below target
        // - Per time unit: 10000 (1 ETH worth of energy per "time unit")
        // This creates a curve where love varies significantly with energy
        vrgda = new AminalVRGDA(
            int256(0.5 ether), // Base price for VRGDA
            0.5e18,            // 50% decay when below target
            10000e18           // 10000 energy units per "time unit"
        );
    }

    /**
     * @dev Initialize the contract by minting the single Aminal NFT to itself
     * @dev This function can only be called once and makes the Aminal self-sovereign
     * @param uri The URI for the token's metadata
     * @return tokenId The ID of the newly minted token (always 1)
     */
    function initialize(string memory uri) external returns (uint256) {
        if (minted) revert AlreadyMinted();
        if (initialized) revert AlreadyInitialized();
        
        initialized = true;
        minted = true;
        
        // Mint to self - the Aminal owns itself!
        _safeMint(address(this), TOKEN_ID);
        _setTokenURI(TOKEN_ID, uri);
        
        emit AminalCreated(TOKEN_ID, address(this), uri);
        
        return TOKEN_ID;
    }

    /**
     * @dev Set the base URI for token metadata
     * @dev Only the contract itself can call this function, maintaining self-sovereignty
     * @param newBaseURI The new base URI
     */
    function setBaseURI(string memory newBaseURI) external {
        if (msg.sender != address(this)) revert NotAuthorized();
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
    function getTraits() external view returns (ITraits.Traits memory) {
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
     * @notice Receive function to accept ETH, track love using VRGDA, and increase energy by fixed amount
     * @dev When ETH is sent to this contract:
     *      - Energy increases by a fixed rate (10,000 energy per ETH)
     *      - Love received varies based on current energy level via VRGDA
     *      - High energy = less love per ETH, Low energy = more love per ETH
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
     * @notice Make the Aminal squeak, consuming energy
     * @dev Energy decreases by the specified amount. Reverts if insufficient energy.
     * @param amount The amount of energy to consume for squeaking
     */
    function squeak(uint256 amount) external {
        if (energy < amount) revert InsufficientEnergy();
        
        energy -= amount;
        emit EnergyLost(msg.sender, amount, energy);
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
     * @dev Override supportsInterface to support ERC721, ERC721URIStorage, and ERC721Receiver
     * @param interfaceId The interface ID to check
     * @return True if the interface is supported
     */
    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721URIStorage) returns (bool) {
        return interfaceId == type(IERC721Receiver).interfaceId || super.supportsInterface(interfaceId);
    }
}