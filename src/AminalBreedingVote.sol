// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Aminal} from "./Aminal.sol";
import {AminalFactory} from "./AminalFactory.sol";
import {IGenes} from "./interfaces/ITraits.sol";
import {IAminalBreedingVote} from "./interfaces/IAminalBreedingVote.sol";
import {IGene} from "./interfaces/IGene.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";

/**
 * @title AminalBreedingVote
 * @author Aminals Protocol
 * @notice Manages the four-phase breeding process for Aminals
 * @dev Breeding occurs in four distinct phases: Gene Proposal, Voting, Execution, and Completed
 * 
 * @notice BREEDING PHASES:
 * Phase 1 - GENE_PROPOSAL (3 days):
 * - Community members can propose Gene NFTs as alternatives to parent genes
 * - Proposers need minimum 100 combined love in both parents
 * - Each user can only have one active gene proposal per breeding ticket
 * - Users can replace their gene proposal during this phase
 * 
 * Phase 2 - VOTING (4 days):
 * - Users vote on genes (parent1 vs parent2 vs proposed genes)
 * - Users vote on veto (proceed vs cancel breeding)
 * - Voting power = loveInParent1 + loveInParent2 (locked at first vote)
 * - Users can change parent gene votes and veto votes but not proposed gene votes
 * 
 * Phase 3 - EXECUTION:
 * - Anyone can execute breeding after voting ends
 * - Child is created with winning genes
 * - If vetoed, no child is created
 * 
 * Phase 4 - COMPLETED:
 * - Breeding process is complete
 * 
 * @notice GENE VOTING:
 * - 8 gene categories: back, arm, tail, ears, body, face, mouth, misc
 * - Each gene voted independently
 * - Highest vote count wins (parent1, parent2, or specific proposed gene)
 * - Ties default to parent1's gene
 */
contract AminalBreedingVote is IAminalBreedingVote {
    
    /// @dev Enum for breeding phases
    enum Phase {
        GENE_PROPOSAL,
        VOTING,
        EXECUTION,
        COMPLETED
    }
    
    /// @dev Structure to track a breeding ticket (formerly proposal)
    struct BreedingTicket {
        address parent1;
        address parent2;
        string childDescription;
        string childTokenURI;
        uint256 geneProposalDeadline; // End of gene proposal phase
        uint256 votingStartTime;       // Start of voting phase
        uint256 votingDeadline;        // End of voting phase
        bool executed;
        address childContract; // Set after breeding execution
        address creator; // Who initiated this breeding (for permissions)
    }
    
    /// @dev Structure to track votes for a specific gene category
    struct GeneVote {
        uint256 parent1Votes;
        uint256 parent2Votes;
        mapping(uint256 => uint256) proposedGeneVotes; // proposedGeneId => votes
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
    
    /// @dev Enum for gene types
    enum GeneType {
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
    
    /// @dev Mapping from ticket ID to gene type to vote counts
    /// @notice ticketId => GeneType => GeneVote
    mapping(uint256 => mapping(GeneType => GeneVote)) public geneVotes;
    
    /// @dev Mapping to track user's locked voting power for a ticket
    /// @notice ticketId => voter => votingPower (locked at first vote time)
    mapping(uint256 => mapping(address => uint256)) public voterPower;
    
    /// @dev Mapping to track user's current gene votes
    /// @notice ticketId => voter => geneType => votedForParent1
    mapping(uint256 => mapping(address => mapping(GeneType => bool))) public userGeneVotes;
    
    /// @dev Mapping to track if user has voted for a specific gene category
    /// @notice ticketId => voter => geneType => hasVoted
    mapping(uint256 => mapping(address => mapping(GeneType => bool))) public hasVotedOnGene;
    
    /// @dev Mapping to track user's current veto vote
    /// @notice ticketId => voter => votedForVeto
    mapping(uint256 => mapping(address => bool)) public userVetoVote;
    
    /// @dev Mapping to track if user has voted on veto
    /// @notice ticketId => voter => hasVotedOnVeto
    mapping(uint256 => mapping(address => bool)) public hasVotedOnVeto;
    
    /// @dev Phase durations
    uint256 public constant GENE_PROPOSAL_DURATION = 3 days;
    uint256 public constant VOTING_DURATION = 4 days;
    
    /// @dev Minimum love required to propose a gene (100 units = 0.01 ETH)
    uint256 public constant MIN_LOVE_FOR_GENE_PROPOSAL = 100;
    
    /// @dev Mapping from ticket ID to gene type to gene proposals
    /// @notice ticketId => GeneType => proposalId => GeneProposal
    mapping(uint256 => mapping(GeneType => mapping(uint256 => GeneProposal))) public geneProposals;
    
    /// @dev Counter for gene proposal IDs
    mapping(uint256 => mapping(GeneType => uint256)) public nextGeneProposalId;
    
    /// @dev Mapping to track user's active gene proposal for a ticket
    /// @notice ticketId => proposer => (geneType, proposalId)
    /// @dev (GeneType.BACK, 0) indicates no active proposal
    mapping(uint256 => mapping(address => ActiveGeneProposal)) public userActiveProposal;
    
    /// @dev Structure to track a user's active gene proposal
    struct ActiveGeneProposal {
        GeneType geneType;
        uint256 proposalId;
        bool hasProposal;
    }
    
    /// @dev Mapping from ticket ID to veto votes
    mapping(uint256 => VetoVote) public vetoVotes;
    
    /// @dev Event emitted when a breeding ticket is created
    event BreedingTicketCreated(
        uint256 indexed ticketId,
        address indexed parent1,
        address indexed parent2,
        uint256 geneProposalDeadline,
        uint256 votingStartTime,
        uint256 votingDeadline
    );
    
    /// @dev Event emitted when someone votes
    event VoteCast(
        uint256 indexed ticketId,
        address indexed voter,
        uint256 votingPower,
        GeneType[] geneTypes,
        bool[] votesForParent1
    );
    
    /// @dev Event emitted when breeding is executed
    event BreedingExecuted(
        uint256 indexed ticketId,
        address indexed childContract
    );
    
    /// @dev Event emitted when a gene is proposed for a gene category
    event GeneProposed(
        uint256 indexed ticketId,
        GeneType indexed geneType,
        uint256 indexed proposalId,
        address proposer,
        address geneContract,
        uint256 tokenId
    );
    
    /// @dev Event emitted when a gene proposal is replaced
    event GeneProposalReplaced(
        uint256 indexed ticketId,
        address indexed proposer,
        GeneType oldGeneType,
        uint256 oldProposalId,
        GeneType newGeneType,
        uint256 newProposalId
    );
    
    /// @dev Event emitted when someone votes for a proposed gene
    event ProposedGeneVoteCast(
        uint256 indexed ticketId,
        address indexed voter,
        uint256 votingPower,
        GeneType geneType,
        uint256 proposalId
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
    
    /// @dev Error thrown when action is attempted in wrong phase
    error WrongPhase(Phase currentPhase, Phase requiredPhase);
    
    /// @dev Error thrown when user already has an active gene proposal
    error AlreadyHasGeneProposal(GeneType existingType, uint256 existingProposalId);
    
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
     * @notice Get the current phase of a breeding ticket
     * @param ticketId The ticket ID to check
     * @return phase The current phase of the breeding process
     */
    function getCurrentPhase(uint256 ticketId) public view returns (Phase) {
        BreedingTicket memory ticket = tickets[ticketId];
        if (ticket.parent1 == address(0)) revert ProposalDoesNotExist();
        
        if (ticket.executed) return Phase.COMPLETED;
        
        if (block.timestamp < ticket.geneProposalDeadline) {
            return Phase.GENE_PROPOSAL;
        } else if (block.timestamp < ticket.votingDeadline) {
            return Phase.VOTING;
        } else {
            return Phase.EXECUTION;
        }
    }
    
    /**
     * @notice Create a breeding ticket that starts the gene voting process
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
        
        uint256 geneProposalEnd = block.timestamp + GENE_PROPOSAL_DURATION;
        uint256 votingStart = geneProposalEnd;
        uint256 votingEnd = votingStart + VOTING_DURATION;
        
        tickets[ticketId] = BreedingTicket({
            parent1: parent1,
            parent2: parent2,
            childDescription: childDescription,
            childTokenURI: childTokenURI,
            geneProposalDeadline: geneProposalEnd,
            votingStartTime: votingStart,
            votingDeadline: votingEnd,
            executed: false,
            childContract: address(0),
            creator: tx.origin // Track the original user who initiated breeding
        });
        
        emit BreedingTicketCreated(ticketId, parent1, parent2, geneProposalEnd, votingStart, votingEnd);
    }
    
    /**
     * @notice Vote on gene inheritance for a breeding ticket
     * @dev Voting power is locked at first vote time, but votes can be changed
     * @param ticketId The ticket to vote on
     * @param geneTypes Array of gene types to vote on
     * @param votesForParent1 Array of votes (true = parent1's gene, false = parent2's gene)
     */
    function vote(
        uint256 ticketId,
        GeneType[] calldata geneTypes,
        bool[] calldata votesForParent1
    ) external {
        if (geneTypes.length != votesForParent1.length) revert ArrayLengthMismatch();
        
        BreedingTicket memory ticket = tickets[ticketId];
        if (ticket.parent1 == address(0)) revert ProposalDoesNotExist();
        if (ticket.executed) revert ProposalAlreadyExecuted();
        
        // Check we're in voting phase
        Phase currentPhase = getCurrentPhase(ticketId);
        if (currentPhase != Phase.VOTING) {
            revert WrongPhase(currentPhase, Phase.VOTING);
        }
        
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
        
        // Process each gene vote
        for (uint256 i = 0; i < geneTypes.length; i++) {
            GeneType geneType = geneTypes[i];
            
            // If user already voted on this gene category, remove their previous vote
            if (hasVotedOnGene[ticketId][msg.sender][geneType]) {
                bool previousVote = userGeneVotes[ticketId][msg.sender][geneType];
                if (previousVote) {
                    geneVotes[ticketId][geneType].parent1Votes -= votingPower;
                } else {
                    geneVotes[ticketId][geneType].parent2Votes -= votingPower;
                }
            }
            
            // Apply new vote
            if (votesForParent1[i]) {
                geneVotes[ticketId][geneType].parent1Votes += votingPower;
            } else {
                geneVotes[ticketId][geneType].parent2Votes += votingPower;
            }
            
            // Record user's vote
            userGeneVotes[ticketId][msg.sender][geneType] = votesForParent1[i];
            hasVotedOnGene[ticketId][msg.sender][geneType] = true;
        }
        
        emit VoteCast(ticketId, msg.sender, votingPower, geneTypes, votesForParent1);
    }
    
    /**
     * @notice Propose a gene as an alternative to parent genes
     * @dev Requires at least 100 combined love in both parents
     * @param ticketId The breeding ticket ID
     * @param geneType The gene category for this proposal
     * @param geneContract The Gene NFT contract address
     * @param tokenId The specific gene token ID
     */
    function proposeGene(
        uint256 ticketId,
        GeneType geneType,
        address geneContract,
        uint256 tokenId
    ) external {
        BreedingTicket memory ticket = tickets[ticketId];
        if (ticket.parent1 == address(0)) revert ProposalDoesNotExist();
        if (ticket.executed) revert ProposalAlreadyExecuted();
        
        // Check we're in gene proposal phase
        Phase currentPhase = getCurrentPhase(ticketId);
        if (currentPhase != Phase.GENE_PROPOSAL) {
            revert WrongPhase(currentPhase, Phase.GENE_PROPOSAL);
        }
        
        // Check if user already has an active gene proposal
        ActiveGeneProposal storage activeProposal = userActiveProposal[ticketId][msg.sender];
        if (activeProposal.hasProposal) {
            // User already has a proposal - emit replacement event for the old one
            emit GeneProposalReplaced(
                ticketId,
                msg.sender,
                activeProposal.geneType,
                activeProposal.proposalId,
                geneType,
                nextGeneProposalId[ticketId][geneType]
            );
            
            // Mark the old proposal as replaced by clearing the proposer
            geneProposals[ticketId][activeProposal.geneType][activeProposal.proposalId].proposer = address(0);
        }
        
        // Check proposer has minimum love in parents
        Aminal parent1 = Aminal(payable(ticket.parent1));
        Aminal parent2 = Aminal(payable(ticket.parent2));
        
        uint256 combinedLove = parent1.loveFromUser(msg.sender) + parent2.loveFromUser(msg.sender);
        if (combinedLove < MIN_LOVE_FOR_GENE_PROPOSAL) revert InsufficientLoveInParents();
        
        // Verify the gene exists and is for the correct trait type
        require(geneContract.code.length > 0, "Invalid gene contract");
        
        // Verify the gene is for the correct gene type
        string memory contractGeneType = IGene(geneContract).traitType(tokenId);
        string memory expectedType = _geneTypeToString(geneType);
        require(
            keccak256(bytes(contractGeneType)) == keccak256(bytes(expectedType)),
            "Gene type mismatch"
        );
        
        // Create gene proposal
        uint256 proposalId = nextGeneProposalId[ticketId][geneType]++;
        geneProposals[ticketId][geneType][proposalId] = GeneProposal({
            geneContract: geneContract,
            tokenId: tokenId,
            proposer: msg.sender,
            proposalTime: block.timestamp
        });
        
        // Update user's active proposal
        activeProposal.geneType = geneType;
        activeProposal.proposalId = proposalId;
        activeProposal.hasProposal = true;
        
        emit GeneProposed(ticketId, geneType, proposalId, msg.sender, geneContract, tokenId);
    }
    
    /**
     * @notice Vote for a proposed gene
     * @dev Uses locked voting power from first vote
     * @param ticketId The breeding ticket ID
     * @param geneType The gene category
     * @param proposalId The proposed gene ID to vote for
     */
    function voteForGene(
        uint256 ticketId,
        GeneType geneType,
        uint256 proposalId
    ) external {
        BreedingTicket memory ticket = tickets[ticketId];
        if (ticket.parent1 == address(0)) revert ProposalDoesNotExist();
        if (ticket.executed) revert ProposalAlreadyExecuted();
        
        // Check we're in voting phase
        Phase currentPhase = getCurrentPhase(ticketId);
        if (currentPhase != Phase.VOTING) {
            revert WrongPhase(currentPhase, Phase.VOTING);
        }
        
        // Verify gene proposal exists and hasn't been replaced
        GeneProposal memory proposal = geneProposals[ticketId][geneType][proposalId];
        require(proposal.geneContract != address(0), "Gene proposal does not exist");
        require(proposal.proposer != address(0), "Gene proposal was replaced");
        
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
        
        // Note: Proposed gene votes are additive and cannot be changed/removed
        // This is different from parent gene/veto votes which can be changed
        geneVotes[ticketId][geneType].proposedGeneVotes[proposalId] += votingPower;
        
        emit ProposedGeneVoteCast(ticketId, msg.sender, votingPower, geneType, proposalId);
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
        if (ticket.executed) revert ProposalAlreadyExecuted();
        
        // Check we're in voting phase
        Phase currentPhase = getCurrentPhase(ticketId);
        if (currentPhase != Phase.VOTING) {
            revert WrongPhase(currentPhase, Phase.VOTING);
        }
        
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
        if (ticket.executed) revert ProposalAlreadyExecuted();
        
        // Check we're in execution phase
        Phase currentPhase = getCurrentPhase(ticketId);
        if (currentPhase != Phase.EXECUTION) {
            revert WrongPhase(currentPhase, Phase.EXECUTION);
        }
        
        ticket.executed = true;
        
        // Check if veto wins or ties
        VetoVote memory veto = vetoVotes[ticketId];
        if (veto.vetoVotes >= veto.proceedVotes) {
            // Veto wins on ties - no child created
            emit BreedingVetoed(ticketId, veto.vetoVotes, veto.proceedVotes);
            return address(0);
        }
        
        // Extract parent addresses first
        address parent1Address = ticket.parent1;
        address parent2Address = ticket.parent2;
        
        // Build child and create
        childContract = _createChild(ticketId, parent1Address, parent2Address, ticket.childDescription, ticket.childTokenURI);
        
        ticket.childContract = childContract;
        
        emit BreedingExecuted(ticketId, childContract);
    }
    
    /**
     * @dev Create child Aminal with winning genes
     */
    function _createChild(
        uint256 ticketId,
        address parent1Address,
        address parent2Address,
        string memory childDescription,
        string memory childTokenURI
    ) private returns (address childContract) {
        // Get parent genes (stored as traits)
        Aminal parent1 = Aminal(payable(parent1Address));
        Aminal parent2 = Aminal(payable(parent2Address));
        
        IGenes.Genes memory parent1Genes = parent1.getTraits();
        IGenes.Genes memory parent2Genes = parent2.getTraits();
        
        // Build child genes in a separate function to avoid stack too deep
        IGenes.Genes memory childGenes = _buildChildGenes(ticketId, parent1Genes, parent2Genes);
        
        // Generate child name and symbol from parent names
        string memory parent1Name = parent1.name();
        string memory parent2Name = parent2.name();
        string memory childName = string.concat(parent1Name, "-", parent2Name, "-Child");
        string memory childSymbol = string.concat(parent1.symbol(), parent2.symbol());
        
        // Create the child through the factory
        childContract = factory.createAminalWithTraits(
            childName,
            childSymbol,
            childDescription,
            childTokenURI,
            childGenes
        );
    }
    
    /**
     * @dev Build child genes from voting results
     * @param ticketId The ticket ID
     * @param parent1Genes Parent1's genes (stored as traits)
     * @param parent2Genes Parent2's genes (stored as traits)
     * @return childGenes The assembled child genes
     */
    function _buildChildGenes(
        uint256 ticketId,
        IGenes.Genes memory parent1Genes,
        IGenes.Genes memory parent2Genes
    ) private view returns (IGenes.Genes memory childGenes) {
        (childGenes.back,,,) = _getWinningGeneValue(ticketId, GeneType.BACK, parent1Genes, parent2Genes);
        (childGenes.arm,,,) = _getWinningGeneValue(ticketId, GeneType.ARM, parent1Genes, parent2Genes);
        (childGenes.tail,,,) = _getWinningGeneValue(ticketId, GeneType.TAIL, parent1Genes, parent2Genes);
        (childGenes.ears,,,) = _getWinningGeneValue(ticketId, GeneType.EARS, parent1Genes, parent2Genes);
        (childGenes.body,,,) = _getWinningGeneValue(ticketId, GeneType.BODY, parent1Genes, parent2Genes);
        (childGenes.face,,,) = _getWinningGeneValue(ticketId, GeneType.FACE, parent1Genes, parent2Genes);
        (childGenes.mouth,,,) = _getWinningGeneValue(ticketId, GeneType.MOUTH, parent1Genes, parent2Genes);
        (childGenes.misc,,,) = _getWinningGeneValue(ticketId, GeneType.MISC, parent1Genes, parent2Genes);
    }
    
    /**
     * @dev Determine the winning gene value (could be from parent1, parent2, or a proposed gene)
     * @param ticketId The ticket ID
     * @param geneType The gene type
     * @param parent1Genes Parent1's genes (stored as traits)
     * @param parent2Genes Parent2's genes (stored as traits)
     * @return winningGene The winning gene string
     * @return isProposedGene Whether the winner is a proposed gene
     * @return geneContract The gene contract if winner is a proposed gene
     * @return geneTokenId The gene token ID if winner is a proposed gene
     */
    function _getWinningGeneValue(
        uint256 ticketId,
        GeneType geneType,
        IGenes.Genes memory parent1Genes,
        IGenes.Genes memory parent2Genes
    ) private view returns (
        string memory winningGene,
        bool isProposedGene,
        address geneContract,
        uint256 geneTokenId
    ) {
        GeneVote storage votes = geneVotes[ticketId][geneType];
        
        uint256 highestVotes = votes.parent1Votes;
        winningGene = _getGeneByType(parent1Genes, geneType);
        isProposedGene = false;
        
        // Check if parent2's gene has more votes
        if (votes.parent2Votes > highestVotes) {
            highestVotes = votes.parent2Votes;
            winningGene = _getGeneByType(parent2Genes, geneType);
        }
        
        // Check all proposed genes
        uint256 proposalCount = nextGeneProposalId[ticketId][geneType];
        for (uint256 i = 0; i < proposalCount; i++) {
            uint256 proposedGeneVotes = votes.proposedGeneVotes[i];
            if (proposedGeneVotes > highestVotes) {
                GeneProposal memory proposal = geneProposals[ticketId][geneType][i];
                
                // Skip replaced proposals (proposer set to address(0))
                if (proposal.proposer == address(0)) continue;
                
                highestVotes = proposedGeneVotes;
                
                // Try to get the gene value from the gene contract
                try IGene(proposal.geneContract).traitValue(proposal.tokenId) returns (string memory geneVal) {
                    winningGene = geneVal;
                } catch {
                    // Fallback if gene doesn't implement traitValue
                    winningGene = string(abi.encodePacked("Gene#", Strings.toString(proposal.tokenId)));
                }
                
                isProposedGene = true;
                geneContract = proposal.geneContract;
                geneTokenId = proposal.tokenId;
            }
        }
        
        return (winningGene, isProposedGene, geneContract, geneTokenId);
    }
    
    /**
     * @dev Helper to get gene value by type
     */
    function _getGeneByType(IGenes.Genes memory genes, GeneType geneType) private pure returns (string memory) {
        if (geneType == GeneType.BACK) return genes.back;
        if (geneType == GeneType.ARM) return genes.arm;
        if (geneType == GeneType.TAIL) return genes.tail;
        if (geneType == GeneType.EARS) return genes.ears;
        if (geneType == GeneType.BODY) return genes.body;
        if (geneType == GeneType.FACE) return genes.face;
        if (geneType == GeneType.MOUTH) return genes.mouth;
        if (geneType == GeneType.MISC) return genes.misc;
        return "";
    }
    
    /**
     * @dev Convert GeneType enum to string
     */
    function _geneTypeToString(GeneType geneType) private pure returns (string memory) {
        if (geneType == GeneType.BACK) return "back";
        if (geneType == GeneType.ARM) return "arm";
        if (geneType == GeneType.TAIL) return "tail";
        if (geneType == GeneType.EARS) return "ears";
        if (geneType == GeneType.BODY) return "body";
        if (geneType == GeneType.FACE) return "face";
        if (geneType == GeneType.MOUTH) return "mouth";
        if (geneType == GeneType.MISC) return "misc";
        return "";
    }
    
    /**
     * @notice Get the parent vote counts for all gene categories in a ticket
     * @param ticketId The ticket to query
     * @return parent1Votes Array of parent1 vote counts for each gene category
     * @return parent2Votes Array of parent2 vote counts for each gene category
     */
    function getVoteResults(uint256 ticketId) external view returns (
        uint256[8] memory parent1Votes,
        uint256[8] memory parent2Votes
    ) {
        parent1Votes[0] = geneVotes[ticketId][GeneType.BACK].parent1Votes;
        parent1Votes[1] = geneVotes[ticketId][GeneType.ARM].parent1Votes;
        parent1Votes[2] = geneVotes[ticketId][GeneType.TAIL].parent1Votes;
        parent1Votes[3] = geneVotes[ticketId][GeneType.EARS].parent1Votes;
        parent1Votes[4] = geneVotes[ticketId][GeneType.BODY].parent1Votes;
        parent1Votes[5] = geneVotes[ticketId][GeneType.FACE].parent1Votes;
        parent1Votes[6] = geneVotes[ticketId][GeneType.MOUTH].parent1Votes;
        parent1Votes[7] = geneVotes[ticketId][GeneType.MISC].parent1Votes;
        
        parent2Votes[0] = geneVotes[ticketId][GeneType.BACK].parent2Votes;
        parent2Votes[1] = geneVotes[ticketId][GeneType.ARM].parent2Votes;
        parent2Votes[2] = geneVotes[ticketId][GeneType.TAIL].parent2Votes;
        parent2Votes[3] = geneVotes[ticketId][GeneType.EARS].parent2Votes;
        parent2Votes[4] = geneVotes[ticketId][GeneType.BODY].parent2Votes;
        parent2Votes[5] = geneVotes[ticketId][GeneType.FACE].parent2Votes;
        parent2Votes[6] = geneVotes[ticketId][GeneType.MOUTH].parent2Votes;
        parent2Votes[7] = geneVotes[ticketId][GeneType.MISC].parent2Votes;
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
     * @notice Get all gene proposals for a specific gene category in a ticket (including replaced ones)
     * @param ticketId The ticket ID
     * @param geneType The gene category
     * @return proposals Array of gene proposals for this gene category
     */
    function getGeneProposals(
        uint256 ticketId,
        GeneType geneType
    ) external view returns (GeneProposal[] memory proposals) {
        uint256 count = nextGeneProposalId[ticketId][geneType];
        proposals = new GeneProposal[](count);
        
        for (uint256 i = 0; i < count; i++) {
            proposals[i] = geneProposals[ticketId][geneType][i];
        }
    }
    
    /**
     * @notice Get only active (non-replaced) gene proposals for a specific gene category
     * @param ticketId The ticket ID
     * @param geneType The gene category
     * @return activeProposals Array of active gene proposals
     * @return activeCount Number of active proposals
     */
    function getActiveGeneProposals(
        uint256 ticketId,
        GeneType geneType
    ) external view returns (GeneProposal[] memory activeProposals, uint256 activeCount) {
        uint256 totalCount = nextGeneProposalId[ticketId][geneType];
        
        // First pass: count active proposals
        for (uint256 i = 0; i < totalCount; i++) {
            if (geneProposals[ticketId][geneType][i].proposer != address(0)) {
                activeCount++;
            }
        }
        
        // Second pass: fill array with active proposals
        activeProposals = new GeneProposal[](activeCount);
        uint256 activeIndex = 0;
        for (uint256 i = 0; i < totalCount; i++) {
            GeneProposal memory proposal = geneProposals[ticketId][geneType][i];
            if (proposal.proposer != address(0)) {
                activeProposals[activeIndex++] = proposal;
            }
        }
    }
    
    /**
     * @notice Get vote count for a specific proposed gene
     * @param ticketId The ticket ID
     * @param geneType The gene category
     * @param proposalId The gene proposal ID
     * @return votes The number of votes for this proposed gene
     */
    function getGeneVotes(
        uint256 ticketId,
        GeneType geneType,
        uint256 proposalId
    ) external view returns (uint256 votes) {
        return geneVotes[ticketId][geneType].proposedGeneVotes[proposalId];
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