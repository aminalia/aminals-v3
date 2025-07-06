// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title RecommendedFixes
 * @notice Recommended security fixes for the Aminals protocol
 * @dev This file shows how to properly secure the payBreedingFee function
 */

// Example 1: Simple Authorization Fix
contract AminalWithSimpleAuth {
    address public immutable authorizedBreedingVote;
    
    modifier onlyBreedingVote() {
        require(msg.sender == authorizedBreedingVote, "Only breeding vote contract");
        _;
    }
    
    function payBreedingFee(
        address[] calldata recipients,
        uint256 breedingTicketId
    ) external onlyBreedingVote returns (uint256 totalPaid) {
        // Function implementation...
    }
}

// Example 2: Full Security Implementation
interface IAminalBreedingVote {
    function isParentInTicket(uint256 ticketId, address parent) external view returns (bool);
}

contract SecureAminal {
    address public immutable breedingVoteContract;
    
    // Events
    event BreedingFeePaid(uint256 totalAmount, uint256 recipientCount, uint256 breedingTicketId);
    event BreedingFeePaymentFailed(uint256 breedingTicketId, string reason);
    
    modifier onlyAuthorizedBreeding() {
        require(msg.sender == breedingVoteContract, "Only authorized breeding contract");
        _;
    }
    
    modifier nonReentrant() {
        // Reentrancy guard implementation
        _;
    }
    
    /**
     * @notice Pay breeding fee to gene owners - SECURED VERSION
     * @dev Only callable by authorized breeding contract
     * @dev Validates that this Aminal is actually part of the breeding
     * @param recipients Array of addresses to pay (gene owners)
     * @param breedingTicketId The breeding ticket ID for verification
     * @return totalPaid The total amount paid out
     */
    function payBreedingFee(
        address[] calldata recipients,
        uint256 breedingTicketId
    ) external onlyAuthorizedBreeding nonReentrant returns (uint256 totalPaid) {
        // SECURITY: Validate this Aminal is actually part of the breeding
        require(
            IAminalBreedingVote(breedingVoteContract).isParentInTicket(
                breedingTicketId,
                address(this)
            ),
            "Aminal not part of this breeding"
        );
        
        // SECURITY: Validate recipients
        require(recipients.length > 0, "No recipients");
        require(recipients.length <= 20, "Too many recipients"); // Prevent gas griefing
        
        // Calculate 10% of balance
        totalPaid = address(this).balance / 10;
        
        if (totalPaid == 0) {
            emit BreedingFeePaymentFailed(breedingTicketId, "Insufficient balance");
            return 0;
        }
        
        // SECURITY: Check minimum payment threshold to prevent dust attacks
        uint256 paymentPerRecipient = totalPaid / recipients.length;
        require(paymentPerRecipient >= 0.001 ether, "Payment too small");
        
        // Distribute payments
        uint256 distributed = 0;
        for (uint256 i = 0; i < recipients.length; i++) {
            // SECURITY: Validate recipient address
            require(recipients[i] != address(0), "Invalid recipient");
            
            uint256 payment;
            if (i == recipients.length - 1) {
                // Last recipient gets remainder
                payment = totalPaid - distributed;
            } else {
                payment = paymentPerRecipient;
                distributed += payment;
            }
            
            // SECURITY: Use low-level call with gas limit
            (bool success,) = payable(recipients[i]).call{value: payment, gas: 2300}("");
            if (!success) {
                // Log failed payment but continue
                emit BreedingFeePaymentFailed(breedingTicketId, "Transfer failed");
            }
        }
        
        emit BreedingFeePaid(totalPaid, recipients.length, breedingTicketId);
    }
}

// Example 3: Factory-Based Authorization
interface IAminalFactory {
    function isAuthorizedBreedingContract(address contract_) external view returns (bool);
}

contract AminalWithFactoryAuth {
    IAminalFactory public immutable factory;
    
    modifier onlyAuthorizedBreeding() {
        require(
            factory.isAuthorizedBreedingContract(msg.sender),
            "Unauthorized breeding contract"
        );
        _;
    }
    
    function payBreedingFee(
        address[] calldata recipients,
        uint256 breedingTicketId
    ) external onlyAuthorizedBreeding returns (uint256 totalPaid) {
        // Implementation...
    }
}

// Example 4: Required Changes to AminalBreedingVote
contract AminalBreedingVoteSecure {
    // Add function to validate parent involvement
    function isParentInTicket(uint256 ticketId, address parent) external view returns (bool) {
        // Check if the address is parent1 or parent2 in the ticket
        // This allows Aminals to verify they're actually involved
    }
    
    // Remove tx.origin usage
    function createBreedingTicket(
        address parent1,
        address parent2,
        string memory childDescription,
        string memory childTokenURI,
        address actualUser // Pass the actual user instead of using tx.origin
    ) external returns (uint256 ticketId) {
        // Implementation...
    }
}