// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IAminalBreedingVote
 * @notice Interface for the AminalBreedingVote contract
 */
interface IAminalBreedingVote {
    /**
     * @notice Create a breeding ticket that starts the trait voting process
     * @dev Called by BreedingSkill when a proposal is accepted
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
    ) external returns (uint256 ticketId);
}