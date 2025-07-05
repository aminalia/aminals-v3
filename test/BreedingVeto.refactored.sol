// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BreedingTestBase} from "./base/BreedingTestBase.sol";
import {AminalBreedingVote} from "src/AminalBreedingVote.sol";

/**
 * @title BreedingVetoTest
 * @notice Tests for the veto mechanism in breeding votes
 * @dev Refactored to use BreedingTestBase for cleaner code
 */
contract BreedingVetoTestRefactored is BreedingTestBase {
    // Additional test users for veto scenarios
    address public vetoVoter;
    address public proceedVoter1;
    address public proceedVoter2;
    
    function setUp() public override {
        super.setUp();
        
        // Setup veto-specific users
        vetoVoter = makeAddr("vetoVoter");
        proceedVoter1 = makeAddr("proceedVoter1");
        proceedVoter2 = makeAddr("proceedVoter2");
        
        // Fund them
        vm.deal(vetoVoter, 10 ether);
        vm.deal(proceedVoter1, 10 ether);
        vm.deal(proceedVoter2, 10 ether);
    }
    
    function test_VetoWinsOnTie() public {
        // Arrange
        uint256 ticketId = _createBreedingTicket();
        _warpToVotingPhase();
        
        // Give equal voting power to both sides
        _feedAminal(vetoVoter, address(parent1), 0.1 ether);
        _feedAminal(proceedVoter1, address(parent2), 0.1 ether);
        
        // Act
        _voteOnVeto(vetoVoter, ticketId, true);
        _voteOnVeto(proceedVoter1, ticketId, false);
        
        // Assert
        (uint256 vetoVotes, uint256 proceedVotes, bool wouldBeVetoed) = breedingVote.getVetoStatus(ticketId);
        assertTrue(wouldBeVetoed, "Veto should win on tie");
        
        // Execute and verify no child created
        _warpToExecutionPhase();
        address childAddress = breedingVote.executeBreeding(ticketId);
        assertEq(childAddress, address(0), "No child should be created when vetoed");
    }
    
    function test_NoVotesResultsInVeto() public {
        // Arrange
        uint256 ticketId = _createBreedingTicket();
        _warpToVotingPhase();
        
        // Act - nobody votes
        
        // Assert
        (uint256 vetoVotes, uint256 proceedVotes, bool wouldBeVetoed) = breedingVote.getVetoStatus(ticketId);
        assertEq(vetoVotes, 0, "No veto votes");
        assertEq(proceedVotes, 0, "No proceed votes");
        assertTrue(wouldBeVetoed, "Should be vetoed when no votes");
        
        // Execute and verify no child created
        _warpToExecutionPhase();
        address childAddress = breedingVote.executeBreeding(ticketId);
        assertEq(childAddress, address(0), "No child should be created when no votes");
    }
    
    function test_ProceedWinsWithMoreVotes() public {
        // Arrange
        uint256 ticketId = _createBreedingTicket();
        _warpToVotingPhase();
        
        // Give more voting power to proceed voters
        _feedAminal(vetoVoter, address(parent1), 0.1 ether);
        _feedAminal(proceedVoter1, address(parent1), 0.2 ether);
        _feedAminal(proceedVoter2, address(parent2), 0.2 ether);
        
        // Act
        _voteOnVeto(vetoVoter, ticketId, true);
        _voteOnVeto(proceedVoter1, ticketId, false);
        _voteOnVeto(proceedVoter2, ticketId, false);
        
        // Also vote on a trait to ensure breeding succeeds
        AminalBreedingVote.GeneType[] memory geneTypes = new AminalBreedingVote.GeneType[](1);
        bool[] memory votesForParent1 = new bool[](1);
        geneTypes[0] = AminalBreedingVote.GeneType.BACK;
        votesForParent1[0] = true;
        _voteOnTraits(proceedVoter1, ticketId, geneTypes, votesForParent1);
        
        // Assert
        (uint256 vetoVotes, uint256 proceedVotes, bool wouldBeVetoed) = breedingVote.getVetoStatus(ticketId);
        assertTrue(proceedVotes > vetoVotes, "Proceed should have more votes");
        assertFalse(wouldBeVetoed, "Should not be vetoed");
        
        // Execute and verify child is created
        _warpToExecutionPhase();
        address childAddress = breedingVote.executeBreeding(ticketId);
        assertTrue(childAddress != address(0), "Child should be created when proceed wins");
    }
    
    function test_RevertWhen_VotingOnVetoAfterDeadline() public {
        // Arrange
        uint256 ticketId = _createBreedingTicket();
        _warpToVotingPhase();
        _feedAminal(vetoVoter, address(parent1), 0.1 ether);
        
        // Act - warp past voting deadline
        _warpToExecutionPhase();
        
        // Assert
        vm.prank(vetoVoter);
        vm.expectRevert(
            abi.encodeWithSelector(
                AminalBreedingVote.WrongPhase.selector,
                AminalBreedingVote.Phase.EXECUTION,
                AminalBreedingVote.Phase.VOTING
            )
        );
        breedingVote.voteOnVeto(ticketId, true);
    }
}