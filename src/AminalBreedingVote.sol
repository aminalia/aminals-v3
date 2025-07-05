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
    
    /// @dev Structure to track veto votes
    struct VetoVote {
        uint256 vetoVotes;
        uint256 proceedVotes;
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
    
    /// @dev Mapping to track user's locked voting power for a ticket
    /// @notice ticketId => voter => votingPower (locked at first vote time)
    mapping(uint256 => mapping(address => uint256)) public voterPower;
    
    /// @dev Mapping to track user's current trait votes
    /// @notice ticketId => voter => traitType => votedForParent1
    mapping(uint256 => mapping(address => mapping(TraitType => bool))) public userTraitVotes;
    
    /// @dev Mapping to track if user has voted for a specific trait
    /// @notice ticketId => voter => traitType => hasVoted
    mapping(uint256 => mapping(address => mapping(TraitType => bool))) public hasVotedOnTrait;
    
    /// @dev Mapping to track user's current veto vote
    /// @notice ticketId => voter => votedForVeto
    mapping(uint256 => mapping(address => bool)) public userVetoVote;
    
    /// @dev Mapping to track if user has voted on veto
    /// @notice ticketId => voter => hasVotedOnVeto
    mapping(uint256 => mapping(address => bool)) public hasVotedOnVeto;
    
    /// @dev Voting duration for trait auctions (3 days)
    uint256 public constant VOTING_DURATION = 3 days;
    
    /// @dev Minimum love required to propose a gene (100 units = 0.01 ETH)
    uint256 public constant MIN_LOVE_FOR_GENE_PROPOSAL = 100;
    
    /// @dev Mapping from ticket ID to trait type to gene proposals
    /// @notice ticketId => TraitType => geneId => GeneProposal
    mapping(uint256 => mapping(TraitType => mapping(uint256 => GeneProposal))) public geneProposals;
    
    /// @dev Counter for gene proposal IDs
    mapping(uint256 => mapping(TraitType => uint256)) public nextGeneProposalId;
    
    /// @dev Mapping from ticket ID to veto votes
    mapping(uint256 => VetoVote) public vetoVotes;
    
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
    
    /// @dev Event emitted when someone votes on veto
    event VetoVoteCast(
        uint256 indexed ticketId,
        address indexed voter,
        uint256 votingPower,
        bool voteForVeto
    );
    
    /// @dev Event emitted when breeding is vetoed
    event BreedingVetoed(
        uint256 indexed ticketId,
        uint256 vetoVotes,
        uint256 proceedVotes
    );
    
    /// @dev Error thrown when trying to vote without love in both parents
    error InsufficientLoveInParents();
    
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
     * @dev Voting power is locked at first vote time, but votes can be changed
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
        
        uint256 votingPower = voterPower[ticketId][msg.sender];
        
        // If first time voting, lock in their voting power
        if (votingPower == 0) {
            // Get love from both parents
            Aminal parent1 = Aminal(payable(ticket.parent1));
            Aminal parent2 = Aminal(payable(ticket.parent2));
            
            uint256 loveInParent1 = parent1.loveFromUser(msg.sender);
            uint256 loveInParent2 = parent2.loveFromUser(msg.sender);
            
            // Voting power is the sum of love in both parents
            votingPower = loveInParent1 + loveInParent2;
            
            if (votingPower == 0) revert InsufficientLoveInParents();
            
            // Lock in voting power for this ticket
            voterPower[ticketId][msg.sender] = votingPower;
        }
        
        // Process each trait vote
        for (uint256 i = 0; i < traits.length; i++) {
            TraitType trait = traits[i];
            
            // If user already voted on this trait, remove their previous vote
            if (hasVotedOnTrait[ticketId][msg.sender][trait]) {
                bool previousVote = userTraitVotes[ticketId][msg.sender][trait];
                if (previousVote) {
                    traitVotes[ticketId][trait].parent1Votes -= votingPower;
                } else {
                    traitVotes[ticketId][trait].parent2Votes -= votingPower;
                }
            }
            
            // Apply new vote
            if (votesForParent1[i]) {
                traitVotes[ticketId][trait].parent1Votes += votingPower;
            } else {
                traitVotes[ticketId][trait].parent2Votes += votingPower;
            }
            
            // Record user's vote
            userTraitVotes[ticketId][msg.sender][trait] = votesForParent1[i];
            hasVotedOnTrait[ticketId][msg.sender][trait] = true;
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
     * @dev Uses locked voting power from first vote
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
        
        uint256 votingPower = voterPower[ticketId][msg.sender];
        
        // If first time voting, lock in their voting power
        if (votingPower == 0) {
            // Get love from both parents
            Aminal parent1 = Aminal(payable(ticket.parent1));
            Aminal parent2 = Aminal(payable(ticket.parent2));
            
            uint256 loveInParent1 = parent1.loveFromUser(msg.sender);
            uint256 loveInParent2 = parent2.loveFromUser(msg.sender);
            
            // Voting power is the sum of love in both parents
            votingPower = loveInParent1 + loveInParent2;
            
            if (votingPower == 0) revert InsufficientLoveInParents();
            
            // Lock in voting power for this ticket
            voterPower[ticketId][msg.sender] = votingPower;
        }
        
        // Note: Gene votes are additive and cannot be changed/removed
        // This is different from trait/veto votes which can be changed
        traitVotes[ticketId][traitType].geneVotes[geneId] += votingPower;
        
        emit GeneVoteCast(ticketId, msg.sender, votingPower, traitType, geneId);
    }
    
    /**
     * @notice Vote on whether to veto this breeding
     * @dev Voting power is locked at first vote time, but vote can be changed
     * @param ticketId The breeding ticket ID
     * @param voteForVeto True to vote for veto, false to vote for proceeding
     */
    function voteOnVeto(
        uint256 ticketId,
        bool voteForVeto
    ) external {
        BreedingTicket memory ticket = tickets[ticketId];
        if (ticket.parent1 == address(0)) revert ProposalDoesNotExist();
        if (block.timestamp > ticket.votingDeadline) revert VotingEnded();
        if (ticket.executed) revert ProposalAlreadyExecuted();
        
        uint256 votingPower = voterPower[ticketId][msg.sender];
        
        // If first time voting, lock in their voting power
        if (votingPower == 0) {
            // Get love from both parents
            Aminal parent1 = Aminal(payable(ticket.parent1));
            Aminal parent2 = Aminal(payable(ticket.parent2));
            
            uint256 loveInParent1 = parent1.loveFromUser(msg.sender);
            uint256 loveInParent2 = parent2.loveFromUser(msg.sender);
            
            // Voting power is the sum of love in both parents
            votingPower = loveInParent1 + loveInParent2;
            
            if (votingPower == 0) revert InsufficientLoveInParents();
            
            // Lock in voting power for this ticket
            voterPower[ticketId][msg.sender] = votingPower;
        }
        
        // If user already voted on veto, remove their previous vote
        if (hasVotedOnVeto[ticketId][msg.sender]) {
            bool previousVote = userVetoVote[ticketId][msg.sender];
            if (previousVote) {
                vetoVotes[ticketId].vetoVotes -= votingPower;
            } else {
                vetoVotes[ticketId].proceedVotes -= votingPower;
            }
        }
        
        // Apply new vote
        if (voteForVeto) {
            vetoVotes[ticketId].vetoVotes += votingPower;
        } else {
            vetoVotes[ticketId].proceedVotes += votingPower;
        }
        
        // Record user's vote
        userVetoVote[ticketId][msg.sender] = voteForVeto;
        hasVotedOnVeto[ticketId][msg.sender] = true;
        
        emit VetoVoteCast(ticketId, msg.sender, votingPower, voteForVeto);
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
        
        // Check if veto wins or ties
        VetoVote memory veto = vetoVotes[ticketId];
        if (veto.vetoVotes >= veto.proceedVotes) {
            // Veto wins on ties - no child created
            emit BreedingVetoed(ticketId, veto.vetoVotes, veto.proceedVotes);
            return address(0);
        }
        
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
     * @notice Get the parent vote counts for all traits in a ticket
     * @param ticketId The ticket to query
     * @return parent1Votes Array of parent1 vote counts for each trait
     * @return parent2Votes Array of parent2 vote counts for each trait
     */
    function getVoteResults(uint256 ticketId) external view returns (
        uint256[8] memory parent1Votes,
        uint256[8] memory parent2Votes
    ) {
        parent1Votes[0] = traitVotes[ticketId][TraitType.BACK].parent1Votes;
        parent1Votes[1] = traitVotes[ticketId][TraitType.ARM].parent1Votes;
        parent1Votes[2] = traitVotes[ticketId][TraitType.TAIL].parent1Votes;
        parent1Votes[3] = traitVotes[ticketId][TraitType.EARS].parent1Votes;
        parent1Votes[4] = traitVotes[ticketId][TraitType.BODY].parent1Votes;
        parent1Votes[5] = traitVotes[ticketId][TraitType.FACE].parent1Votes;
        parent1Votes[6] = traitVotes[ticketId][TraitType.MOUTH].parent1Votes;
        parent1Votes[7] = traitVotes[ticketId][TraitType.MISC].parent1Votes;
        
        parent2Votes[0] = traitVotes[ticketId][TraitType.BACK].parent2Votes;
        parent2Votes[1] = traitVotes[ticketId][TraitType.ARM].parent2Votes;
        parent2Votes[2] = traitVotes[ticketId][TraitType.TAIL].parent2Votes;
        parent2Votes[3] = traitVotes[ticketId][TraitType.EARS].parent2Votes;
        parent2Votes[4] = traitVotes[ticketId][TraitType.BODY].parent2Votes;
        parent2Votes[5] = traitVotes[ticketId][TraitType.FACE].parent2Votes;
        parent2Votes[6] = traitVotes[ticketId][TraitType.MOUTH].parent2Votes;
        parent2Votes[7] = traitVotes[ticketId][TraitType.MISC].parent2Votes;
    }
    
    /**
     * @notice Check if a user can vote on a ticket
     * @param ticketId The ticket ID
     * @param voter The potential voter
     * @return canVoteResult Whether the user can vote
     * @return votingPower The voting power they have (locked or potential)
     */
    function canVote(uint256 ticketId, address voter) external view returns (bool canVoteResult, uint256 votingPower) {
        BreedingTicket memory ticket = tickets[ticketId];
        if (ticket.parent1 == address(0)) return (false, 0);
        if (block.timestamp > ticket.votingDeadline) return (false, 0);
        if (ticket.executed) return (false, 0);
        
        // Check if voter already has locked voting power
        votingPower = voterPower[ticketId][voter];
        
        if (votingPower == 0) {
            // Calculate potential voting power
            Aminal parent1 = Aminal(payable(ticket.parent1));
            Aminal parent2 = Aminal(payable(ticket.parent2));
            
            uint256 loveInParent1 = parent1.loveFromUser(voter);
            uint256 loveInParent2 = parent2.loveFromUser(voter);
            
            votingPower = loveInParent1 + loveInParent2;
        }
        
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
    
    /**
     * @notice Get the current veto vote status
     * @param ticketId The ticket ID
     * @return vetoCount The number of votes to veto
     * @return proceedCount The number of votes to proceed
     * @return wouldBeVetoed Whether breeding would be vetoed with current votes
     */
    function getVetoStatus(
        uint256 ticketId
    ) external view returns (
        uint256 vetoCount,
        uint256 proceedCount,
        bool wouldBeVetoed
    ) {
        VetoVote memory veto = vetoVotes[ticketId];
        vetoCount = veto.vetoVotes;
        proceedCount = veto.proceedVotes;
        wouldBeVetoed = vetoCount >= proceedCount; // Veto wins on ties
    }
}