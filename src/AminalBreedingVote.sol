// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Aminal} from "./Aminal.sol";
import {AminalFactory} from "./AminalFactory.sol";
import {ITraits} from "./interfaces/ITraits.sol";

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
contract AminalBreedingVote {
    
    /// @dev Structure to track a single breeding proposal
    struct BreedingProposal {
        address parent1;
        address parent2;
        string childDescription;
        string childTokenURI;
        uint256 votingDeadline;
        bool executed;
        address childContract; // Set after breeding execution
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
    
    /// @dev Counter for breeding proposal IDs
    uint256 public nextProposalId;
    
    /// @dev Mapping from proposal ID to breeding proposal
    mapping(uint256 => BreedingProposal) public proposals;
    
    /// @dev Mapping from proposal ID to trait type to vote counts
    /// @notice proposalId => TraitType => TraitVote
    mapping(uint256 => mapping(TraitType => TraitVote)) public traitVotes;
    
    /// @dev Mapping to track if a user has voted on a proposal
    /// @notice proposalId => voter => hasVoted
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    
    /// @dev Mapping to track user's voting power for a proposal
    /// @notice proposalId => voter => votingPower (recorded at vote time)
    mapping(uint256 => mapping(address => uint256)) public voterPower;
    
    /// @dev Event emitted when a breeding proposal is created
    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed parent1,
        address indexed parent2,
        uint256 votingDeadline
    );
    
    /// @dev Event emitted when someone votes
    event VoteCast(
        uint256 indexed proposalId,
        address indexed voter,
        uint256 votingPower,
        TraitType[] traits,
        bool[] votesForParent1
    );
    
    /// @dev Event emitted when breeding is executed
    event BreedingExecuted(
        uint256 indexed proposalId,
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
    
    /**
     * @dev Constructor
     * @param _factory The AminalFactory contract address
     */
    constructor(address _factory) {
        factory = AminalFactory(_factory);
    }
    
    /**
     * @notice Create a breeding proposal for two Aminals
     * @dev Anyone can create a proposal, but only valid Aminals can be parents
     * @param parent1 The first parent Aminal
     * @param parent2 The second parent Aminal
     * @param childDescription Description for the child Aminal
     * @param childTokenURI Token URI for the child Aminal
     * @param votingDuration How long the voting period lasts (in seconds)
     * @return proposalId The ID of the created proposal
     */
    function createProposal(
        address parent1,
        address parent2,
        string memory childDescription,
        string memory childTokenURI,
        uint256 votingDuration
    ) external returns (uint256 proposalId) {
        // Validate parents
        if (!factory.isValidAminal(parent1)) revert InvalidParent();
        if (!factory.isValidAminal(parent2)) revert InvalidParent();
        if (parent1 == parent2) revert InvalidParent();
        
        proposalId = nextProposalId++;
        
        proposals[proposalId] = BreedingProposal({
            parent1: parent1,
            parent2: parent2,
            childDescription: childDescription,
            childTokenURI: childTokenURI,
            votingDeadline: block.timestamp + votingDuration,
            executed: false,
            childContract: address(0)
        });
        
        emit ProposalCreated(proposalId, parent1, parent2, block.timestamp + votingDuration);
    }
    
    /**
     * @notice Vote on trait inheritance for a breeding proposal
     * @dev Voting power is the combined love the voter has in both parents
     * @param proposalId The proposal to vote on
     * @param traits Array of trait types to vote on
     * @param votesForParent1 Array of votes (true = parent1, false = parent2)
     */
    function vote(
        uint256 proposalId,
        TraitType[] calldata traits,
        bool[] calldata votesForParent1
    ) external {
        if (traits.length != votesForParent1.length) revert ArrayLengthMismatch();
        
        BreedingProposal memory proposal = proposals[proposalId];
        if (proposal.parent1 == address(0)) revert ProposalDoesNotExist();
        if (block.timestamp > proposal.votingDeadline) revert VotingEnded();
        if (proposal.executed) revert ProposalAlreadyExecuted();
        if (hasVoted[proposalId][msg.sender]) revert AlreadyVoted();
        
        // Get love from both parents
        Aminal parent1 = Aminal(payable(proposal.parent1));
        Aminal parent2 = Aminal(payable(proposal.parent2));
        
        uint256 loveInParent1 = parent1.loveFromUser(msg.sender);
        uint256 loveInParent2 = parent2.loveFromUser(msg.sender);
        
        // Voting power is the sum of love in both parents
        uint256 votingPower = loveInParent1 + loveInParent2;
        
        if (votingPower == 0) revert InsufficientLoveInParents();
        
        // Record that user has voted and their voting power
        hasVoted[proposalId][msg.sender] = true;
        voterPower[proposalId][msg.sender] = votingPower;
        
        // Apply votes to each trait
        for (uint256 i = 0; i < traits.length; i++) {
            TraitType trait = traits[i];
            if (votesForParent1[i]) {
                traitVotes[proposalId][trait].parent1Votes += votingPower;
            } else {
                traitVotes[proposalId][trait].parent2Votes += votingPower;
            }
        }
        
        emit VoteCast(proposalId, msg.sender, votingPower, traits, votesForParent1);
    }
    
    /**
     * @notice Execute breeding based on voting results
     * @dev Anyone can execute after voting period ends
     * @param proposalId The proposal to execute
     * @return childContract The address of the created child Aminal
     */
    function executeBreeding(uint256 proposalId) external returns (address childContract) {
        BreedingProposal storage proposal = proposals[proposalId];
        if (proposal.parent1 == address(0)) revert ProposalDoesNotExist();
        if (block.timestamp <= proposal.votingDeadline) revert VotingNotEnded();
        if (proposal.executed) revert ProposalAlreadyExecuted();
        
        proposal.executed = true;
        
        // Get parent traits
        Aminal parent1 = Aminal(payable(proposal.parent1));
        Aminal parent2 = Aminal(payable(proposal.parent2));
        
        ITraits.Traits memory traits1 = parent1.getTraits();
        ITraits.Traits memory traits2 = parent2.getTraits();
        
        // Determine winning traits based on votes
        ITraits.Traits memory childTraits = ITraits.Traits({
            back: _getWinningTrait(proposalId, TraitType.BACK) ? traits1.back : traits2.back,
            arm: _getWinningTrait(proposalId, TraitType.ARM) ? traits1.arm : traits2.arm,
            tail: _getWinningTrait(proposalId, TraitType.TAIL) ? traits1.tail : traits2.tail,
            ears: _getWinningTrait(proposalId, TraitType.EARS) ? traits1.ears : traits2.ears,
            body: _getWinningTrait(proposalId, TraitType.BODY) ? traits1.body : traits2.body,
            face: _getWinningTrait(proposalId, TraitType.FACE) ? traits1.face : traits2.face,
            mouth: _getWinningTrait(proposalId, TraitType.MOUTH) ? traits1.mouth : traits2.mouth,
            misc: _getWinningTrait(proposalId, TraitType.MISC) ? traits1.misc : traits2.misc
        });
        
        // Generate child name and symbol from parent names
        string memory parent1Name = parent1.name();
        string memory parent2Name = parent2.name();
        string memory childName = string.concat(parent1Name, "-", parent2Name, "-Child");
        string memory childSymbol = string.concat(parent1.symbol(), parent2.symbol());
        
        // Create the child through the factory
        // Note: This will fail if factory doesn't have a function to create with specific traits
        // We'll need to add this to AminalFactory
        childContract = factory.createAminalWithTraits(
            childName,
            childSymbol,
            proposal.childDescription,
            proposal.childTokenURI,
            childTraits
        );
        
        proposal.childContract = childContract;
        
        emit BreedingExecuted(proposalId, childContract);
    }
    
    /**
     * @dev Determine which parent wins for a specific trait
     * @param proposalId The proposal ID
     * @param trait The trait type
     * @return True if parent1 wins, false if parent2 wins
     */
    function _getWinningTrait(uint256 proposalId, TraitType trait) private view returns (bool) {
        TraitVote memory votes = traitVotes[proposalId][trait];
        // Parent1 wins ties
        return votes.parent1Votes >= votes.parent2Votes;
    }
    
    /**
     * @notice Get the current vote counts for all traits in a proposal
     * @param proposalId The proposal to query
     * @return results Array of vote counts for each trait (8 elements)
     */
    function getVoteResults(uint256 proposalId) external view returns (TraitVote[8] memory results) {
        results[0] = traitVotes[proposalId][TraitType.BACK];
        results[1] = traitVotes[proposalId][TraitType.ARM];
        results[2] = traitVotes[proposalId][TraitType.TAIL];
        results[3] = traitVotes[proposalId][TraitType.EARS];
        results[4] = traitVotes[proposalId][TraitType.BODY];
        results[5] = traitVotes[proposalId][TraitType.FACE];
        results[6] = traitVotes[proposalId][TraitType.MOUTH];
        results[7] = traitVotes[proposalId][TraitType.MISC];
    }
    
    /**
     * @notice Check if a user can vote on a proposal
     * @param proposalId The proposal ID
     * @param voter The potential voter
     * @return canVoteResult Whether the user can vote
     * @return votingPower The voting power they would have
     */
    function canVote(uint256 proposalId, address voter) external view returns (bool canVoteResult, uint256 votingPower) {
        BreedingProposal memory proposal = proposals[proposalId];
        if (proposal.parent1 == address(0)) return (false, 0);
        if (block.timestamp > proposal.votingDeadline) return (false, 0);
        if (proposal.executed) return (false, 0);
        if (hasVoted[proposalId][voter]) return (false, 0);
        
        Aminal parent1 = Aminal(payable(proposal.parent1));
        Aminal parent2 = Aminal(payable(proposal.parent2));
        
        uint256 loveInParent1 = parent1.loveFromUser(voter);
        uint256 loveInParent2 = parent2.loveFromUser(voter);
        
        votingPower = loveInParent1 + loveInParent2;
        canVoteResult = votingPower > 0;
    }
}