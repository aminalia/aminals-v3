# Security Audit Report: Aminals Protocol

## Executive Summary

This security audit has identified **CRITICAL vulnerabilities** in the Aminals protocol that allow unauthorized ETH drainage from any Aminal contract. The main issue is in the `payBreedingFee` function which lacks any authorization checks.

### Severity Ratings
- 🔴 **CRITICAL**: Immediate exploitation possible, significant financial loss
- 🟠 **HIGH**: Significant security risk requiring urgent fix
- 🟡 **MEDIUM**: Security concern that should be addressed
- 🟢 **LOW**: Minor issue or best practice recommendation

## Critical Vulnerabilities

### 1. 🔴 CRITICAL: Unauthorized ETH Drainage via payBreedingFee

**Location**: `Aminal.sol:522-554`

**Description**: The `payBreedingFee` function can be called by ANY external address to drain 10% of an Aminal's ETH balance per call. There are NO authorization checks.

**Proof of Concept**:
```solidity
// Any attacker can repeatedly steal funds
address[] memory recipients = new address[](1);
recipients[0] = attacker;

// Drain 10% each time
aminal.payBreedingFee(recipients, 123); // Steals 10% of balance
aminal.payBreedingFee(recipients, 456); // Steals 10% of remaining
aminal.payBreedingFee(recipients, 789); // Steals 10% of remaining
```

**Impact**: 
- Complete theft of all ETH from any Aminal
- Attacker can drain funds in ~20 transactions
- No way to prevent or recover stolen funds

**Recommendation**:
```solidity
// Add authorization check
modifier onlyAuthorizedBreeding() {
    require(msg.sender == address(breedingVote), "Unauthorized");
    _;
}

function payBreedingFee(
    address[] calldata recipients,
    uint256 breedingTicketId
) external onlyAuthorizedBreeding nonReentrant returns (uint256 totalPaid) {
    // Also validate this Aminal is actually part of the breeding ticket
    require(isParentInBreeding(breedingTicketId), "Not part of breeding");
    // ... rest of function
}
```

### 2. 🔴 CRITICAL: No Breeding Ticket Validation

**Location**: `Aminal.sol:525`

**Description**: The `breedingTicketId` parameter is never validated. Attackers can pass any value.

**Impact**: Even with authorization, there's no verification that this Aminal is involved in the specified breeding.

### 3. 🟠 HIGH: Reentrancy Vulnerability

**Location**: `Aminal.sol:540-551`

**Description**: The `payBreedingFee` function uses `.call{}` without reentrancy protection.

**Recommendation**: Add `nonReentrant` modifier

### 4. 🟡 MEDIUM: tx.origin Usage

**Location**: `AminalBreedingVote.sol:351`

**Description**: Uses `tx.origin` which can be manipulated and breaks composability.

**Recommendation**: Track the actual caller through proper authentication flow.

## Additional Security Concerns

### 5. 🟡 MEDIUM: Insufficient Skill Validation

**Location**: `Aminal.sol:366-411`

**Description**: While skills check the ISkill interface, there's no whitelist of trusted skills.

**Recommendation**: Consider implementing a skill registry or whitelist.

### 6. 🟢 LOW: Gene Proposal Spam

**Location**: `AminalBreedingVote.sol`

**Description**: Low barrier (100 love units) allows spam proposals.

**Recommendation**: Increase minimum requirement or add rate limiting.

## Exploit Scenarios

### Scenario 1: Direct Theft
1. Attacker identifies valuable Aminals with high ETH balance
2. Calls `payBreedingFee` repeatedly with their address
3. Drains 10% per call until balance is negligible

### Scenario 2: Front-Running Breeding
1. Attacker monitors for breeding executions
2. Front-runs with `payBreedingFee` calls
3. Legitimate gene owners receive less/nothing

### Scenario 3: Automated Bot Attack
1. Bot scans all Aminals for ETH balance
2. Automatically drains any with balance > gas cost
3. Scales attack across entire protocol

## Recommended Fixes

### Immediate Actions (CRITICAL)

1. **Add Authorization to payBreedingFee**:
```solidity
// Option 1: Hardcode breeding vote contract
address public immutable breedingVoteContract;

// Option 2: Maintain whitelist
mapping(address => bool) public authorizedCallers;

// Option 3: Use factory for verification
modifier onlyAuthorizedBreeding() {
    require(
        factory.isAuthorizedBreedingContract(msg.sender),
        "Unauthorized"
    );
    _;
}
```

2. **Validate Breeding Involvement**:
```solidity
function payBreedingFee(
    address[] calldata recipients,
    uint256 breedingTicketId
) external onlyAuthorizedBreeding nonReentrant returns (uint256 totalPaid) {
    // Callback to breeding vote to verify involvement
    require(
        IAminalBreedingVote(msg.sender).isParentInTicket(
            breedingTicketId,
            address(this)
        ),
        "Not parent in breeding"
    );
    // ... rest of function
}
```

3. **Add Reentrancy Protection**:
```solidity
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

// Add nonReentrant modifier to payBreedingFee
```

### Medium Priority Fixes

1. **Remove tx.origin usage**
2. **Implement skill registry/whitelist**
3. **Increase gene proposal requirements**
4. **Add event monitoring for suspicious activity**

## Testing Recommendations

1. **Security Test Suite**: Add comprehensive security tests
2. **Fuzzing**: Fuzz test payment amounts and recipient arrays
3. **Invariant Testing**: Ensure ETH can only flow out during legitimate breeding
4. **Fork Testing**: Test on mainnet fork with real data

## Conclusion

The current implementation has critical vulnerabilities that allow complete theft of funds from any Aminal. These must be fixed immediately before any deployment. The main issue is the complete lack of authorization on the `payBreedingFee` function.

The recommended fix is straightforward: add proper authorization checks and validate breeding ticket involvement. With these fixes, the breeding fee payment system can work as intended without compromising security.

---

**Audited by**: Security Audit Assistant
**Date**: 2025-07-06
**Severity**: CRITICAL - Do not deploy without fixes