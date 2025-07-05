// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Skill} from "../Skill.sol";
import {Aminal} from "../Aminal.sol";
import {AminalFactory} from "../AminalFactory.sol";
import {IGenes} from "../interfaces/ITraits.sol";
import {IAminalBreedingVote} from "../interfaces/IAminalBreedingVote.sol";

/**
 * @title BreedingSkill
 * @notice Allows Aminals to create and accept breeding proposals
 * @dev Implements a two-step breeding process:
 *      1. Create proposal: Costs 2,500 energy + love from proposer
 *      2. Accept proposal: Costs 2,500 energy + love from acceptor
 */
contract BreedingSkill is Skill {

    /// @dev Structure to store breeding proposals
    struct Proposal {
        address proposer; // The Aminal that created the proposal
        address target;   // The specific Aminal being proposed to
        string childDescription;
        string childTokenURI;
        uint256 timestamp;
        bool executed;
        uint256 breedingTicketId; // ID in AminalBreedingVote contract
    }

    /// @dev The AminalFactory contract
    AminalFactory public immutable factory;
    
    /// @dev The AminalBreedingVote contract for trait auctions
    address public immutable breedingVote;
    
    /// @dev Breeding cost per parent (2,500 units = 0.25 ETH worth)
    uint256 public constant BREEDING_COST = 2500;
    
    /// @dev Proposal expiry time (7 days)
    uint256 public constant PROPOSAL_EXPIRY = 7 days;
    
    /// @dev Mapping from proposal ID to proposal details
    mapping(uint256 => Proposal) public proposals;
    
    /// @dev Counter for proposal IDs
    uint256 public nextProposalId;
    
    /// @dev Mapping to track active proposals between Aminals
    /// @notice proposer => target => proposalId (0 means no active proposal)
    mapping(address => mapping(address => uint256)) public activeProposals;
    
    /// @dev Event emitted when a breeding proposal is created
    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        address indexed target,
        string childDescription,
        string childTokenURI
    );
    
    /// @dev Event emitted when a breeding proposal is accepted and auction starts
    event ProposalAccepted(
        uint256 indexed proposalId,
        address indexed acceptor,
        uint256 indexed breedingTicketId
    );
    
    
    /// @dev Error thrown when proposal doesn't exist
    error ProposalDoesNotExist();
    
    /// @dev Error thrown when proposal has expired
    error ProposalExpired();
    
    /// @dev Error thrown when proposal already executed
    error ProposalAlreadyExecuted();
    
    /// @dev Error thrown when caller is not authorized
    error NotAuthorized();
    
    /// @dev Error thrown when trying to breed with self
    error CannotBreedWithSelf();
    
    /// @dev Error thrown when there's already an active proposal
    error ActiveProposalExists();
    
    /// @dev Error thrown when parents are not valid Aminals
    error InvalidParent();

    constructor(address _factory, address _breedingVote) {
        factory = AminalFactory(_factory);
        breedingVote = _breedingVote;
    }


    /**
     * @notice Get the cost for a skill based on the function being called
     * @param data The encoded function call
     * @return The cost in energy/love units
     */
    function skillCost(bytes calldata data) external pure returns (uint256) {
        bytes4 selector = bytes4(data[:4]);
        
        if (selector == this.createProposal.selector) {
            return BREEDING_COST;
        } else if (selector == this.acceptProposal.selector) {
            return BREEDING_COST;
        } else {
            return 1; // Default cost
        }
    }

    /**
     * @notice Create a breeding proposal for this Aminal to breed with another
     * @dev Called via useSkill by the proposing Aminal, costs 2,500 energy + love
     * @dev User A with love in Aminal A creates proposal for Aminal A to breed with Aminal B
     * @param target The specific Aminal to propose breeding with
     * @param childDescription Description for the potential child
     * @param childTokenURI Token URI for the potential child
     * @return The cost of this action (2,500)
     */
    function createProposal(
        address target,
        string memory childDescription,
        string memory childTokenURI
    ) external returns (uint256) {
        // msg.sender is the proposing Aminal (Aminal A)
        address proposer = msg.sender;
        
        // Validate inputs
        if (!factory.isValidAminal(proposer)) revert InvalidParent();
        if (!factory.isValidAminal(target)) revert InvalidParent();
        if (proposer == target) revert CannotBreedWithSelf();
        
        // Check for existing active proposal
        if (activeProposals[proposer][target] != 0) {
            uint256 existingId = activeProposals[proposer][target];
            Proposal memory existing = proposals[existingId];
            // Only revert if proposal is not executed AND not expired
            if (!existing.executed && block.timestamp <= existing.timestamp + PROPOSAL_EXPIRY) {
                revert ActiveProposalExists();
            }
        }
        
        // Create new proposal
        uint256 proposalId = ++nextProposalId;
        
        proposals[proposalId] = Proposal({
            proposer: proposer,
            target: target,
            childDescription: childDescription,
            childTokenURI: childTokenURI,
            timestamp: block.timestamp,
            executed: false,
            breedingTicketId: 0 // Will be set when accepted
        });
        
        activeProposals[proposer][target] = proposalId;
        
        emit ProposalCreated(proposalId, proposer, target, childDescription, childTokenURI);
        
        return BREEDING_COST;
    }

    /**
     * @notice Accept a breeding proposal as the target Aminal
     * @dev Called via useSkill by the target Aminal, costs 2,500 energy + love
     * @dev User B with love in Aminal B accepts proposal for Aminal A to breed with Aminal B
     * @param proposalId The ID of the proposal to accept
     * @return The cost of this action (2,500)
     */
    function acceptProposal(uint256 proposalId) external returns (uint256) {
        // msg.sender is the target Aminal (Aminal B) accepting the proposal
        address acceptor = msg.sender;
        
        Proposal storage proposal = proposals[proposalId];
        if (proposal.proposer == address(0)) revert ProposalDoesNotExist();
        if (proposal.target != acceptor) revert NotAuthorized();
        if (proposal.executed) revert ProposalAlreadyExecuted();
        if (block.timestamp > proposal.timestamp + PROPOSAL_EXPIRY) revert ProposalExpired();
        
        // Mark as executed
        proposal.executed = true;
        
        // Clear active proposal mapping
        activeProposals[proposal.proposer][proposal.target] = 0;
        
        // Create breeding ticket in AminalBreedingVote contract
        // This starts the trait auction process
        uint256 breedingTicketId = IAminalBreedingVote(breedingVote).createBreedingTicket(
            proposal.proposer,
            acceptor,
            proposal.childDescription,
            proposal.childTokenURI
        );
        
        // Store the breeding ticket ID
        proposal.breedingTicketId = breedingTicketId;
        
        emit ProposalAccepted(proposalId, acceptor, breedingTicketId);
        
        return BREEDING_COST;
    }


    /**
     * @notice Check if there's an active proposal between two Aminals
     * @param proposer The proposing Aminal
     * @param target The target Aminal
     * @return hasActive Whether there's an active proposal
     * @return proposalId The active proposal ID (0 if none)
     */
    function hasActiveProposal(address proposer, address target) external view returns (bool hasActive, uint256 proposalId) {
        proposalId = activeProposals[proposer][target];
        if (proposalId == 0) return (false, 0);
        
        Proposal memory proposal = proposals[proposalId];
        hasActive = !proposal.executed && block.timestamp <= proposal.timestamp + PROPOSAL_EXPIRY;
        
        if (!hasActive) {
            proposalId = 0;
        }
    }

}