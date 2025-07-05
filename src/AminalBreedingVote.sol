// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Aminal} from "./Aminal.sol";
import {AminalFactory} from "./AminalFactory.sol";
import {ITraits} from "./interfaces/ITraits.sol";
import {IAminalBreedingVote} from "./interfaces/IAminalBreedingVote.sol";
import {IGene} from "./interfaces/IGene.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";

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
        mapping(uint256 => uint256) geneVotes; // geneId => votes
    }
    
    /// @dev Structure for a gene proposal
    struct GeneProposal {
        address geneContract;
        uint256 tokenId;
        address proposer;
        uint256 proposalTime;
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
    
    /// @dev Minimum love required to propose a gene (100 units = 0.01 ETH)
    uint256 public constant MIN_LOVE_FOR_GENE_PROPOSAL = 100;
    
    /// @dev Mapping from ticket ID to trait type to gene proposals
    /// @notice ticketId => TraitType => geneId => GeneProposal
    mapping(uint256 => mapping(TraitType => mapping(uint256 => GeneProposal))) public geneProposals;
    
    /// @dev Counter for gene proposal IDs
    mapping(uint256 => mapping(TraitType => uint256)) public nextGeneProposalId;
    
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
    
    /// @dev Event emitted when a gene is proposed for a trait
    event GeneProposed(
        uint256 indexed ticketId,
        TraitType indexed traitType,
        uint256 indexed geneId,
        address proposer,
        address geneContract,
        uint256 tokenId
    );
    
    /// @dev Event emitted when someone votes for a gene
    event GeneVoteCast(
        uint256 indexed ticketId,
        address indexed voter,
        uint256 votingPower,
        TraitType traitType,
        uint256 geneId
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
     * @notice Propose a gene as an alternative trait option
     * @dev Requires at least 100 combined love in both parents
     * @param ticketId The breeding ticket ID
     * @param traitType The trait category for this gene
     * @param geneContract The Gene NFT contract address
     * @param tokenId The specific gene token ID
     */
    function proposeGene(
        uint256 ticketId,
        TraitType traitType,
        address geneContract,
        uint256 tokenId
    ) external {
        BreedingTicket memory ticket = tickets[ticketId];
        if (ticket.parent1 == address(0)) revert ProposalDoesNotExist();
        if (block.timestamp > ticket.votingDeadline) revert VotingEnded();
        if (ticket.executed) revert ProposalAlreadyExecuted();
        
        // Check proposer has minimum love in parents
        Aminal parent1 = Aminal(payable(ticket.parent1));
        Aminal parent2 = Aminal(payable(ticket.parent2));
        
        uint256 combinedLove = parent1.loveFromUser(msg.sender) + parent2.loveFromUser(msg.sender);
        if (combinedLove < MIN_LOVE_FOR_GENE_PROPOSAL) revert InsufficientLoveInParents();
        
        // Verify the gene exists and is for the correct trait type
        require(geneContract.code.length > 0, "Invalid gene contract");
        
        // Verify the gene is for the correct trait type
        string memory geneTraitType = IGene(geneContract).traitType(tokenId);
        string memory expectedType = _traitTypeToString(traitType);
        require(
            keccak256(bytes(geneTraitType)) == keccak256(bytes(expectedType)),
            "Gene trait type mismatch"
        );
        
        // Create gene proposal
        uint256 geneId = nextGeneProposalId[ticketId][traitType]++;
        geneProposals[ticketId][traitType][geneId] = GeneProposal({
            geneContract: geneContract,
            tokenId: tokenId,
            proposer: msg.sender,
            proposalTime: block.timestamp
        });
        
        emit GeneProposed(ticketId, traitType, geneId, msg.sender, geneContract, tokenId);
    }
    
    /**
     * @notice Vote for a proposed gene
     * @dev Uses same voting power as trait voting
     * @param ticketId The breeding ticket ID
     * @param traitType The trait category
     * @param geneId The proposed gene ID to vote for
     */
    function voteForGene(
        uint256 ticketId,
        TraitType traitType,
        uint256 geneId
    ) external {
        BreedingTicket memory ticket = tickets[ticketId];
        if (ticket.parent1 == address(0)) revert ProposalDoesNotExist();
        if (block.timestamp > ticket.votingDeadline) revert VotingEnded();
        if (ticket.executed) revert ProposalAlreadyExecuted();
        
        // Verify gene proposal exists
        GeneProposal memory proposal = geneProposals[ticketId][traitType][geneId];
        require(proposal.geneContract != address(0), "Gene proposal does not exist");
        
        // Get voting power
        Aminal parent1 = Aminal(payable(ticket.parent1));
        Aminal parent2 = Aminal(payable(ticket.parent2));
        
        uint256 votingPower = parent1.loveFromUser(msg.sender) + parent2.loveFromUser(msg.sender);
        if (votingPower == 0) revert InsufficientLoveInParents();
        
        // Add votes to the gene
        traitVotes[ticketId][traitType].geneVotes[geneId] += votingPower;
        
        emit GeneVoteCast(ticketId, msg.sender, votingPower, traitType, geneId);
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
        
        // Determine winning traits based on votes (including gene proposals)
        ITraits.Traits memory childTraits;
        
        // Get winning trait for each category
        (childTraits.back,,,) = _getWinningTraitValue(ticketId, TraitType.BACK, traits1, traits2);
        (childTraits.arm,,,) = _getWinningTraitValue(ticketId, TraitType.ARM, traits1, traits2);
        (childTraits.tail,,,) = _getWinningTraitValue(ticketId, TraitType.TAIL, traits1, traits2);
        (childTraits.ears,,,) = _getWinningTraitValue(ticketId, TraitType.EARS, traits1, traits2);
        (childTraits.body,,,) = _getWinningTraitValue(ticketId, TraitType.BODY, traits1, traits2);
        (childTraits.face,,,) = _getWinningTraitValue(ticketId, TraitType.FACE, traits1, traits2);
        (childTraits.mouth,,,) = _getWinningTraitValue(ticketId, TraitType.MOUTH, traits1, traits2);
        (childTraits.misc,,,) = _getWinningTraitValue(ticketId, TraitType.MISC, traits1, traits2);
        
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
     * @dev Determine the winning trait value (could be from parent1, parent2, or a gene)
     * @param ticketId The ticket ID
     * @param trait The trait type
     * @param traits1 Parent1's traits
     * @param traits2 Parent2's traits
     * @return winningTrait The winning trait string
     * @return isGene Whether the winner is a gene
     * @return geneContract The gene contract if winner is a gene
     * @return geneTokenId The gene token ID if winner is a gene
     */
    function _getWinningTraitValue(
        uint256 ticketId,
        TraitType trait,
        ITraits.Traits memory traits1,
        ITraits.Traits memory traits2
    ) private view returns (
        string memory winningTrait,
        bool isGene,
        address geneContract,
        uint256 geneTokenId
    ) {
        TraitVote storage votes = traitVotes[ticketId][trait];
        
        uint256 highestVotes = votes.parent1Votes;
        winningTrait = _getTraitByType(traits1, trait);
        isGene = false;
        
        // Check if parent2 has more votes
        if (votes.parent2Votes > highestVotes) {
            highestVotes = votes.parent2Votes;
            winningTrait = _getTraitByType(traits2, trait);
        }
        
        // Check all gene proposals
        uint256 geneCount = nextGeneProposalId[ticketId][trait];
        for (uint256 i = 0; i < geneCount; i++) {
            uint256 geneVotes = votes.geneVotes[i];
            if (geneVotes > highestVotes) {
                highestVotes = geneVotes;
                GeneProposal memory proposal = geneProposals[ticketId][trait][i];
                
                // Try to get the trait value from the gene contract
                try IGene(proposal.geneContract).traitValue(proposal.tokenId) returns (string memory traitVal) {
                    winningTrait = traitVal;
                } catch {
                    // Fallback if gene doesn't implement traitValue
                    winningTrait = string(abi.encodePacked("Gene#", Strings.toString(proposal.tokenId)));
                }
                
                isGene = true;
                geneContract = proposal.geneContract;
                geneTokenId = proposal.tokenId;
            }
        }
        
        return (winningTrait, isGene, geneContract, geneTokenId);
    }
    
    /**
     * @dev Helper to get trait value by type
     */
    function _getTraitByType(ITraits.Traits memory traits, TraitType traitType) private pure returns (string memory) {
        if (traitType == TraitType.BACK) return traits.back;
        if (traitType == TraitType.ARM) return traits.arm;
        if (traitType == TraitType.TAIL) return traits.tail;
        if (traitType == TraitType.EARS) return traits.ears;
        if (traitType == TraitType.BODY) return traits.body;
        if (traitType == TraitType.FACE) return traits.face;
        if (traitType == TraitType.MOUTH) return traits.mouth;
        if (traitType == TraitType.MISC) return traits.misc;
        return "";
    }
    
    /**
     * @dev Convert TraitType enum to string
     */
    function _traitTypeToString(TraitType traitType) private pure returns (string memory) {
        if (traitType == TraitType.BACK) return "back";
        if (traitType == TraitType.ARM) return "arm";
        if (traitType == TraitType.TAIL) return "tail";
        if (traitType == TraitType.EARS) return "ears";
        if (traitType == TraitType.BODY) return "body";
        if (traitType == TraitType.FACE) return "face";
        if (traitType == TraitType.MOUTH) return "mouth";
        if (traitType == TraitType.MISC) return "misc";
        return "";
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
    
    /**
     * @notice Get all gene proposals for a specific trait in a ticket
     * @param ticketId The ticket ID
     * @param traitType The trait category
     * @return proposals Array of gene proposals for this trait
     */
    function getGeneProposals(
        uint256 ticketId,
        TraitType traitType
    ) external view returns (GeneProposal[] memory proposals) {
        uint256 count = nextGeneProposalId[ticketId][traitType];
        proposals = new GeneProposal[](count);
        
        for (uint256 i = 0; i < count; i++) {
            proposals[i] = geneProposals[ticketId][traitType][i];
        }
    }
    
    /**
     * @notice Get vote count for a specific gene proposal
     * @param ticketId The ticket ID
     * @param traitType The trait category
     * @param geneId The gene proposal ID
     * @return votes The number of votes for this gene
     */
    function getGeneVotes(
        uint256 ticketId,
        TraitType traitType,
        uint256 geneId
    ) external view returns (uint256 votes) {
        return traitVotes[ticketId][traitType].geneVotes[geneId];
    }
}