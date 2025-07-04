// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ISkill
 * @notice Interface for Aminal skills that can be executed with energy/love costs
 * @dev Similar to IERC721Receiver, this allows contracts to explicitly support being called as skills
 */
interface ISkill {
    /**
     * @notice Get the energy cost for executing a skill with the given calldata
     * @dev This function should be view/pure and return the cost without side effects
     * @param data The encoded function call that will be executed
     * @return energyCost The amount of energy/love required to execute this skill
     */
    function skillEnergyCost(bytes calldata data) external view returns (uint256 energyCost);
    
    /**
     * @notice Check if this contract implements the ISkill interface
     * @dev Should return the interface ID of ISkill
     * @return The selector 0x???????? if this is a valid skill contract
     */
    function isValidSkill() external pure returns (bytes4);
}