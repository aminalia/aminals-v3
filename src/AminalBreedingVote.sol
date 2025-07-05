// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Aminal} from "./Aminal.sol";
import {AminalFactory} from "./AminalFactory.sol";
import {ITraits} from "./interfaces/ITraits.sol";
import {IAminalBreedingVote} from "./interfaces/IAminalBreedingVote.sol";

/**
 * @title AminalBreedingVote
 * @author Aminals Protocol
 * @notice Manages voting for trait inheritance during Aminal breeding
 * @dev Users vote using their combined love from both parent Aminals to determine which traits the child inherits
 * 
 * @notice VOTING MECHANICS:
 * - Users can vote if they have love in either parent Aminal
 * - Voting power = loveInParent1 + loveInParent2
 * - Each trait category has its own independent vote
 * - Users vote for parent1 or parent2 for each trait
 * - Love is recorded at vote time (no revoting if love changes)
 * - Voting concludes when executeBreeding is called
 * 
 * @notice TRAIT VOTING:
 * - 8 trait categories: back, arm, tail, ears, body, face, mouth, misc
 * - For each trait, users choose which parent's trait to inherit
 * - The parent with more votes wins for that trait
 * - Ties default to parent1's trait
 */
contract AminalBreedingVote is IAminalBreedingVote {
    
    /// @dev Structure to track a breeding ticket (formerly proposal)
    struct BreedingTicket {
        address parent1;
        address parent2;
        string childDescription;
        string childTokenURI;
        uint256 votingDeadline;
        bool executed;
        address childContract; // Set after breeding execution
        address creator; // Who initiated this breeding (for permissions)
    }
    
    /// @dev Structure to track votes for a specific trait
    struct TraitVote {
        uint256 parent1Votes;
        uint256 parent2Votes;
    }
    
    /// @dev Enum for trait types
    enum TraitType {
        BACK,
        ARM,
        TAIL,
        EARS,
        BODY,
        FACE,
        MOUTH,
        MISC
    }
    
    /// @dev The AminalFactory contract
    AminalFactory public immutable factory;
    
    /// @dev Counter for breeding ticket IDs
    uint256 public nextTicketId;
    
    /// @dev Mapping from ticket ID to breeding ticket
    mapping(uint256 => BreedingTicket) public tickets;
    
    /// @dev Authorized breeding skill contract
    address public immutable breedingSkill;
    
    /// @dev Mapping from ticket ID to trait type to vote counts
    /// @notice ticketId => TraitType => TraitVote
    mapping(uint256 => mapping(TraitType => TraitVote)) public traitVotes;
    
    /// @dev Mapping to track if a user has voted on a ticket
    /// @notice ticketId => voter => hasVoted
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    
    /// @dev Mapping to track user's voting power for a ticket
    /// @notice ticketId => voter => votingPower (recorded at vote time)
    mapping(uint256 => mapping(address => uint256)) public voterPower;
    
    /// @dev Voting duration for trait auctions (3 days)
    uint256 public constant VOTING_DURATION = 3 days;
    
    /// @dev Event emitted when a breeding ticket is created
    event BreedingTicketCreated(
        uint256 indexed ticketId,
        address indexed parent1,
        address indexed parent2,
        uint256 votingDeadline
    );
    
    /// @dev Event emitted when someone votes
    event VoteCast(
        uint256 indexed ticketId,
        address indexed voter,
        uint256 votingPower,
        TraitType[] traits,
        bool[] votesForParent1
    );
    
    /// @dev Event emitted when breeding is executed
    event BreedingExecuted(
        uint256 indexed ticketId,
        address indexed childContract
    );
    
    /// @dev Error thrown when trying to vote without love in both parents
    error InsufficientLoveInParents();
    
    /// @dev Error thrown when trying to vote twice
    error AlreadyVoted();
    
    /// @dev Error thrown when voting period has ended
    error VotingEnded();
    
    /// @dev Error thrown when voting period hasn't ended
    error VotingNotEnded();
    
    /// @dev Error thrown when proposal already executed
    error ProposalAlreadyExecuted();
    
    /// @dev Error thrown when proposal doesn't exist
    error ProposalDoesNotExist();
    
    /// @dev Error thrown when arrays have mismatched lengths
    error ArrayLengthMismatch();
    
    /// @dev Error thrown when parent is not a valid Aminal
    error InvalidParent();
    
    /// @dev Error thrown when called by unauthorized address
    error NotAuthorized();
    
    /**
     * @dev Constructor
     * @param _factory The AminalFactory contract address
     * @param _breedingSkill The authorized BreedingSkill contract
     */
    constructor(address _factory, address _breedingSkill) {
        factory = AminalFactory(_factory);
        breedingSkill = _breedingSkill;
    }
    
    /**
     * @notice Create a breeding ticket that starts the trait voting process
     * @dev Only callable by the authorized BreedingSkill contract
     * @param parent1 The first parent Aminal
     * @param parent2 The second parent Aminal
     * @param childDescription Description for the child Aminal
     * @param childTokenURI Token URI for the child Aminal
     * @return ticketId The ID of the created breeding ticket
     */
    function createBreedingTicket(
        address parent1,
        address parent2,
        string memory childDescription,
        string memory childTokenURI
    ) external returns (uint256 ticketId) {
        // Only the authorized BreedingSkill can create tickets
        if (msg.sender != breedingSkill) revert NotAuthorized();
        
        // Validate parents
        if (!factory.isValidAminal(parent1)) revert InvalidParent();
        if (!factory.isValidAminal(parent2)) revert InvalidParent();
        if (parent1 == parent2) revert InvalidParent();
        
        ticketId = ++nextTicketId;
        
        tickets[ticketId] = BreedingTicket({
            parent1: parent1,
            parent2: parent2,
            childDescription: childDescription,
            childTokenURI: childTokenURI,
            votingDeadline: block.timestamp + VOTING_DURATION,
            executed: false,
            childContract: address(0),
            creator: tx.origin // Track the original user who initiated breeding
        });
        
        emit BreedingTicketCreated(ticketId, parent1, parent2, block.timestamp + VOTING_DURATION);
    }
    
    /**
     * @notice Vote on trait inheritance for a breeding ticket
     * @dev Voting power is the combined love the voter has in both parents
     * @param ticketId The ticket to vote on
     * @param traits Array of trait types to vote on
     * @param votesForParent1 Array of votes (true = parent1, false = parent2)
     */
    function vote(
        uint256 ticketId,
        TraitType[] calldata traits,
        bool[] calldata votesForParent1
    ) external {
        if (traits.length != votesForParent1.length) revert ArrayLengthMismatch();
        
        BreedingTicket memory ticket = tickets[ticketId];
        if (ticket.parent1 == address(0)) revert ProposalDoesNotExist();
        if (block.timestamp > ticket.votingDeadline) revert VotingEnded();
        if (ticket.executed) revert ProposalAlreadyExecuted();
        if (hasVoted[ticketId][msg.sender]) revert AlreadyVoted();
        
        // Get love from both parents
        Aminal parent1 = Aminal(payable(ticket.parent1));
        Aminal parent2 = Aminal(payable(ticket.parent2));
        
        uint256 loveInParent1 = parent1.loveFromUser(msg.sender);
        uint256 loveInParent2 = parent2.loveFromUser(msg.sender);
        
        // Voting power is the sum of love in both parents
        uint256 votingPower = loveInParent1 + loveInParent2;
        
        if (votingPower == 0) revert InsufficientLoveInParents();
        
        // Record that user has voted and their voting power
        hasVoted[ticketId][msg.sender] = true;
        voterPower[ticketId][msg.sender] = votingPower;
        
        // Apply votes to each trait
        for (uint256 i = 0; i < traits.length; i++) {
            TraitType trait = traits[i];
            if (votesForParent1[i]) {
                traitVotes[ticketId][trait].parent1Votes += votingPower;
            } else {
                traitVotes[ticketId][trait].parent2Votes += votingPower;
            }
        }
        
        emit VoteCast(ticketId, msg.sender, votingPower, traits, votesForParent1);
    }
    
    /**
     * @notice Execute breeding based on voting results
     * @dev Anyone can execute after voting period ends
     * @param ticketId The ticket to execute
     * @return childContract The address of the created child Aminal
     */
    function executeBreeding(uint256 ticketId) external returns (address childContract) {
        BreedingTicket storage ticket = tickets[ticketId];
        if (ticket.parent1 == address(0)) revert ProposalDoesNotExist();
        if (block.timestamp <= ticket.votingDeadline) revert VotingNotEnded();
        if (ticket.executed) revert ProposalAlreadyExecuted();
        
        ticket.executed = true;
        
        // Get parent traits
        Aminal parent1 = Aminal(payable(ticket.parent1));
        Aminal parent2 = Aminal(payable(ticket.parent2));
        
        ITraits.Traits memory traits1 = parent1.getTraits();
        ITraits.Traits memory traits2 = parent2.getTraits();
        
        // Determine winning traits based on votes
        ITraits.Traits memory childTraits = ITraits.Traits({
            back: _getWinningTrait(ticketId, TraitType.BACK) ? traits1.back : traits2.back,
            arm: _getWinningTrait(ticketId, TraitType.ARM) ? traits1.arm : traits2.arm,
            tail: _getWinningTrait(ticketId, TraitType.TAIL) ? traits1.tail : traits2.tail,
            ears: _getWinningTrait(ticketId, TraitType.EARS) ? traits1.ears : traits2.ears,
            body: _getWinningTrait(ticketId, TraitType.BODY) ? traits1.body : traits2.body,
            face: _getWinningTrait(ticketId, TraitType.FACE) ? traits1.face : traits2.face,
            mouth: _getWinningTrait(ticketId, TraitType.MOUTH) ? traits1.mouth : traits2.mouth,
            misc: _getWinningTrait(ticketId, TraitType.MISC) ? traits1.misc : traits2.misc
        });
        
        // Generate child name and symbol from parent names
        string memory parent1Name = parent1.name();
        string memory parent2Name = parent2.name();
        string memory childName = string.concat(parent1Name, "-", parent2Name, "-Child");
        string memory childSymbol = string.concat(parent1.symbol(), parent2.symbol());
        
        // Create the child through the factory
        childContract = factory.createAminalWithTraits(
            childName,
            childSymbol,
            ticket.childDescription,
            ticket.childTokenURI,
            childTraits
        );
        
        ticket.childContract = childContract;
        
        emit BreedingExecuted(ticketId, childContract);
    }
    
    /**
     * @dev Determine which parent wins for a specific trait
     * @param ticketId The ticket ID
     * @param trait The trait type
     * @return True if parent1 wins, false if parent2 wins
     */
    function _getWinningTrait(uint256 ticketId, TraitType trait) private view returns (bool) {
        TraitVote memory votes = traitVotes[ticketId][trait];
        // Parent1 wins ties
        return votes.parent1Votes >= votes.parent2Votes;
    }
    
    /**
     * @notice Get the current vote counts for all traits in a ticket
     * @param ticketId The ticket to query
     * @return results Array of vote counts for each trait (8 elements)
     */
    function getVoteResults(uint256 ticketId) external view returns (TraitVote[8] memory results) {
        results[0] = traitVotes[ticketId][TraitType.BACK];
        results[1] = traitVotes[ticketId][TraitType.ARM];
        results[2] = traitVotes[ticketId][TraitType.TAIL];
        results[3] = traitVotes[ticketId][TraitType.EARS];
        results[4] = traitVotes[ticketId][TraitType.BODY];
        results[5] = traitVotes[ticketId][TraitType.FACE];
        results[6] = traitVotes[ticketId][TraitType.MOUTH];
        results[7] = traitVotes[ticketId][TraitType.MISC];
    }
    
    /**
     * @notice Check if a user can vote on a ticket
     * @param ticketId The ticket ID
     * @param voter The potential voter
     * @return canVoteResult Whether the user can vote
     * @return votingPower The voting power they would have
     */
    function canVote(uint256 ticketId, address voter) external view returns (bool canVoteResult, uint256 votingPower) {
        BreedingTicket memory ticket = tickets[ticketId];
        if (ticket.parent1 == address(0)) return (false, 0);
        if (block.timestamp > ticket.votingDeadline) return (false, 0);
        if (ticket.executed) return (false, 0);
        if (hasVoted[ticketId][voter]) return (false, 0);
        
        Aminal parent1 = Aminal(payable(ticket.parent1));
        Aminal parent2 = Aminal(payable(ticket.parent2));
        
        uint256 loveInParent1 = parent1.loveFromUser(voter);
        uint256 loveInParent2 = parent2.loveFromUser(voter);
        
        votingPower = loveInParent1 + loveInParent2;
        canVoteResult = votingPower > 0;
    }
}