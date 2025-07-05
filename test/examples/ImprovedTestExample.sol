// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {BreedingTestBase} from "../base/BreedingTestBase.sol";
import {TestHelpers} from "../helpers/TestHelpers.sol";

/**
 * @title ImprovedTestExample
 * @notice Demonstrates improved testing patterns for the Aminals project
 */
contract ImprovedTestExample is BreedingTestBase {
    using TestHelpers for *;
    
    /// @notice Tests complete breeding flow with clear phases
    function test_BreedingFlow_FromProposalToChild() public {
        console2.log("=== Breeding Flow Test ===");
        
        // ========== Arrange ==========
        uint256 ticketId = _createBreedingTicket();
        address geneProposer = makeAddr("geneProposer");
        vm.deal(geneProposer, 1 ether);
        
        // ========== Gene Proposal Phase ==========
        console2.log("Phase 1: Gene Proposal");
        _assertPhase(ticketId, AminalBreedingVote.Phase.GENE_PROPOSAL);
        
        // Proposer suggests alternative gene
        _feedAminal(geneProposer, address(parent1), TestHelpers.SMALL_FEED);
        _feedAminal(geneProposer, address(parent2), TestHelpers.SMALL_FEED);
        
        // Would add gene proposal logic here
        
        // ========== Voting Phase ==========
        console2.log("Phase 2: Voting");
        _warpToVotingPhase();
        _assertPhase(ticketId, AminalBreedingVote.Phase.VOTING);
        
        // Multiple voters participate
        uint256[3] memory votingAmounts = [
            TestHelpers.SMALL_FEED,
            TestHelpers.MEDIUM_FEED,
            TestHelpers.LARGE_FEED
        ];
        
        address[3] memory voters = [voter1, voter2, voter3];
        
        for (uint i = 0; i < voters.length; i++) {
            _feedAminal(voters[i], address(parent1), votingAmounts[i]);
            _feedAminal(voters[i], address(parent2), votingAmounts[i] / 2);
        }
        
        // Cast votes with different preferences
        _voteWithPreferences(ticketId);
        
        // ========== Execution Phase ==========
        console2.log("Phase 3: Execution");
        _warpToExecutionPhase();
        _assertPhase(ticketId, AminalBreedingVote.Phase.EXECUTION);
        
        // Execute breeding
        address childAddress = breedingVote.executeBreeding(ticketId);
        
        // ========== Verify Results ==========
        console2.log("Phase 4: Verification");
        assertTrue(childAddress != address(0), "Child should be created");
        _assertPhase(ticketId, AminalBreedingVote.Phase.COMPLETED);
        
        // Log results for debugging
        console2.log("Child created at:", childAddress);
    }
    
    /// @notice Parameterized test for vote weight calculations
    function testFuzz_VotingPowerCalculation(
        uint96 amountParent1,
        uint96 amountParent2
    ) public {
        // Bound inputs to reasonable range
        amountParent1 = uint96(bound(amountParent1, 0.001 ether, 10 ether));
        amountParent2 = uint96(bound(amountParent2, 0.001 ether, 10 ether));
        
        uint256 ticketId = _createBreedingTicket();
        _warpToVotingPhase();
        
        // Feed both parents
        _feedAminal(voter1, address(parent1), amountParent1);
        _feedAminal(voter1, address(parent2), amountParent2);
        
        // Vote to lock power
        _voteOnVeto(voter1, ticketId, false);
        
        // Verify voting power
        uint256 votingPower = breedingVote.voterPower(ticketId, voter1);
        uint256 expectedPower = parent1.loveFromUser(voter1) + parent2.loveFromUser(voter2);
        
        assertLe(votingPower, expectedPower, "Voting power should not exceed total love");
    }
    
    /// @notice Edge case: Multiple vote changes
    function test_EdgeCase_MultipleVoteChanges() public {
        uint256 ticketId = _createBreedingTicket();
        _warpToVotingPhase();
        
        _feedAminal(voter1, address(parent1), TestHelpers.MEDIUM_FEED);
        
        // Vote multiple times
        bool[] memory voteSequence = new bool[](5);
        voteSequence[0] = true;   // Vote veto
        voteSequence[1] = false;  // Change to proceed
        voteSequence[2] = true;   // Back to veto
        voteSequence[3] = false;  // Back to proceed
        voteSequence[4] = true;   // Final: veto
        
        for (uint i = 0; i < voteSequence.length; i++) {
            _voteOnVeto(voter1, ticketId, voteSequence[i]);
            
            // Verify vote was recorded correctly
            (uint256 vetoVotes, uint256 proceedVotes,) = breedingVote.getVetoStatus(ticketId);
            
            if (voteSequence[i]) {
                assertGt(vetoVotes, 0, "Veto vote not recorded");
                assertEq(proceedVotes, 0, "Proceed vote should be zero");
            } else {
                assertEq(vetoVotes, 0, "Veto vote should be zero");
                assertGt(proceedVotes, 0, "Proceed vote not recorded");
            }
        }
    }
    
    // ========== Helper Functions ==========
    
    function _voteWithPreferences(uint256 ticketId) private {
        // Voter 1: Prefers parent1 traits
        AminalBreedingVote.GeneType[] memory types1 = new AminalBreedingVote.GeneType[](3);
        bool[] memory votes1 = new bool[](3);
        types1[0] = AminalBreedingVote.GeneType.BACK;
        types1[1] = AminalBreedingVote.GeneType.TAIL;
        types1[2] = AminalBreedingVote.GeneType.FACE;
        votes1[0] = true;
        votes1[1] = true;
        votes1[2] = true;
        _voteOnTraits(voter1, ticketId, types1, votes1);
        
        // Voter 2: Prefers parent2 traits
        AminalBreedingVote.GeneType[] memory types2 = new AminalBreedingVote.GeneType[](3);
        bool[] memory votes2 = new bool[](3);
        types2[0] = AminalBreedingVote.GeneType.ARM;
        types2[1] = AminalBreedingVote.GeneType.BODY;
        types2[2] = AminalBreedingVote.GeneType.MOUTH;
        // All false = parent2
        _voteOnTraits(voter2, ticketId, types2, votes2);
        
        // Voter 3: Mixed preferences
        AminalBreedingVote.GeneType[] memory types3 = new AminalBreedingVote.GeneType[](2);
        bool[] memory votes3 = new bool[](2);
        types3[0] = AminalBreedingVote.GeneType.EARS;
        types3[1] = AminalBreedingVote.GeneType.MISC;
        votes3[0] = true;
        votes3[1] = false;
        _voteOnTraits(voter3, ticketId, types3, votes3);
    }
}