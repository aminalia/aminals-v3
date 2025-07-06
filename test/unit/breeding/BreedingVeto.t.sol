// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BreedingTestBase} from "../../base/BreedingTestBase.sol";
import {AminalBreedingVote} from "src/AminalBreedingVote.sol";

/**
 * @title BreedingVetoTest
 * @notice Tests for the veto mechanism in breeding votes
 */
contract BreedingVetoTest is BreedingTestBase {
    // Additional test users for veto scenarios
    address public vetoVoter;
    address public proceedVoter1;
    address public proceedVoter2;
    
    function setUp() public override {
        super.setUp();
        
        vetoVoter = makeAddr("vetoVoter");
        proceedVoter1 = makeAddr("proceedVoter1");
        proceedVoter2 = makeAddr("proceedVoter2");
        
        vm.deal(vetoVoter, 10 ether);
        vm.deal(proceedVoter1, 10 ether);
        vm.deal(proceedVoter2, 10 ether);
    }
    
    function test_VetoWinsOnTie() public {
        // Create breeding and enter voting phase
        uint256 ticketId = _createBreedingTicket();
        _warpToVotingPhase();
        
        // Give equal voting power
        _feedAminal(vetoVoter, address(parent1), 0.1 ether);
        _feedAminal(proceedVoter1, address(parent2), 0.1 ether);
        
        // Vote
        _voteOnVeto(vetoVoter, ticketId, true);
        _voteOnVeto(proceedVoter1, ticketId, false);
        
        // Verify veto wins on tie
        (,, bool wouldBeVetoed) = breedingVote.getVetoStatus(ticketId);
        assertTrue(wouldBeVetoed, "Veto should win on tie");
        
        // Execute and verify no child
        _warpToExecutionPhase();
        address childAddress = breedingVote.executeBreeding(ticketId);
        assertEq(childAddress, address(0), "No child when vetoed");
    }
    
    function test_NoVotesResultsInVeto() public {
        uint256 ticketId = _createBreedingTicket();
        _warpToVotingPhase();
        
        // Nobody votes - verify default veto
        (uint256 vetoVotes, uint256 proceedVotes, bool wouldBeVetoed) = breedingVote.getVetoStatus(ticketId);
        assertEq(vetoVotes, 0);
        assertEq(proceedVotes, 0);
        assertTrue(wouldBeVetoed, "No votes = veto");
        
        _warpToExecutionPhase();
        assertEq(breedingVote.executeBreeding(ticketId), address(0));
    }
    
    function test_ProceedWinsWithMoreVotes() public {
        uint256 ticketId = _createBreedingTicket();
        _warpToVotingPhase();
        
        // More proceed votes
        _feedAminal(vetoVoter, address(parent1), 0.1 ether);
        _feedAminal(proceedVoter1, address(parent1), 0.2 ether);
        _feedAminal(proceedVoter2, address(parent2), 0.2 ether);
        
        _voteOnVeto(vetoVoter, ticketId, true);
        _voteOnVeto(proceedVoter1, ticketId, false);
        _voteOnVeto(proceedVoter2, ticketId, false);
        
        // Vote on traits too
        AminalBreedingVote.GeneType[] memory types = new AminalBreedingVote.GeneType[](1);
        bool[] memory votes = new bool[](1);
        types[0] = AminalBreedingVote.GeneType.BACK;
        votes[0] = true;
        _voteOnTraits(proceedVoter1, ticketId, types, votes);
        
        (,, bool wouldBeVetoed) = breedingVote.getVetoStatus(ticketId);
        assertFalse(wouldBeVetoed);
        
        _warpToExecutionPhase();
        assertTrue(breedingVote.executeBreeding(ticketId) != address(0));
    }
    
    function test_RevertWhen_VotingAfterDeadline() public {
        uint256 ticketId = _createBreedingTicket();
        _warpToVotingPhase();
        _feedAminal(vetoVoter, address(parent1), 0.1 ether);
        
        _warpToExecutionPhase();
        
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