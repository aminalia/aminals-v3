// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ISkill} from "../interfaces/ISkill.sol";
import {AminalBreedingVote} from "../AminalBreedingVote.sol";
import {Aminal} from "../Aminal.sol";

/**
 * @title BreedingPaymentSkill
 * @notice Skill that allows parent Aminals to pay gene owners after breeding
 * @dev Parents pay 10% of their ETH balance to gene owners who contributed to their child's genes
 */
contract BreedingPaymentSkill is ISkill {
    /// @dev The AminalBreedingVote contract
    AminalBreedingVote public immutable breedingVote;
    
    /// @dev Event emitted when a parent pays gene owners
    event ParentPaidGeneOwners(
        address indexed parent,
        uint256 indexed ticketId,
        uint256 amount
    );
    
    /// @dev Error thrown when caller is not an Aminal
    error NotAnAminal();
    
    /**
     * @dev Constructor
     * @param _breedingVote The AminalBreedingVote contract address
     */
    constructor(address _breedingVote) {
        breedingVote = AminalBreedingVote(_breedingVote);
    }
    
    /**
     * @notice Get the cost of using this skill
     * @dev For breeding payment, cost is 0 since we're sending ETH out, not consuming resources
     * @return cost The energy/love cost (0 for this skill)
     */
    function skillCost(bytes calldata) external pure override returns (uint256 cost) {
        return 0; // No energy cost for paying gene owners
    }
    
    /**
     * @notice Main entry point when called as a skill
     * @dev The Aminal's useSkill function calls this directly
     */
    fallback() external {
        // Decode the ticket ID from calldata
        uint256 ticketId = abi.decode(msg.data, (uint256));
        
        // The Aminal will call its own payGeneOwnersForBreeding function
        // which will then call the breeding vote contract with ETH
        bytes memory callData = abi.encodeWithSignature(
            "payGeneOwnersForBreeding(address,uint256)", 
            address(breedingVote), 
            ticketId
        );
        
        // Call the Aminal's payment function
        (bool callSuccess,) = msg.sender.call(callData);
        require(callSuccess, "Payment call failed");
        
        // Get the payment amount for the event (10% of Aminal's balance)
        uint256 paymentAmount = address(msg.sender).balance / 10;
        emit ParentPaidGeneOwners(msg.sender, ticketId, paymentAmount);
    }
    
    /**
     * @dev Support ISkill interface
     */
    function supportsInterface(bytes4 interfaceId) public pure override returns (bool) {
        return interfaceId == type(ISkill).interfaceId;
    }
}