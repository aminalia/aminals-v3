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
    
    /**
     * @notice Check if an address is a parent in a breeding ticket
     * @dev Used by Aminals to verify they're involved in the breeding
     * @param ticketId The breeding ticket ID
     * @param parent The address to check
     * @return True if the address is parent1 or parent2 in the ticket
     */
    function isParentInTicket(uint256 ticketId, address parent) external view returns (bool);
}