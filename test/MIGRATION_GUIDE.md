# Test Migration Guide

## Overview

This guide helps migrate existing tests to the new organized structure using base contracts.

## Before Migration

```solidity
contract BreedingVetoTest is Test {
    // 120+ lines of duplicated setup
    BreedingSkill public breedingSkill;
    AminalBreedingVote public breedingVote;
    AminalFactory public factory;
    
    // Repeated parent data
    AminalFactory.ParentData memory firstParentData = AminalFactory.ParentData({
        name: "Adam",
        // ... 50+ lines
    });
    
    function setUp() public {
        // Complex deployment logic
        // User creation
        // Funding
    }
    
    function _createBreedingTicket() internal {
        // Duplicated helper
    }
}
```

## After Migration

```solidity
contract BreedingVetoTest is BreedingTestBase {
    // Only test-specific setup
    address public vetoVoter;
    
    function setUp() public override {
        super.setUp(); // Handles all common setup
        
        // Only test-specific additions
        vetoVoter = makeAddr("vetoVoter");
        vm.deal(vetoVoter, 10 ether);
    }
    
    // Tests use inherited helpers
    function test_VetoWinsOnTie() public {
        uint256 ticketId = _createBreedingTicket(); // Inherited
        _warpToVotingPhase(); // Inherited
        _feedAminal(vetoVoter, address(parent1), 0.1 ether); // Inherited
        // ...
    }
}
```

## Migration Steps

### 1. Identify Test Category

- **Breeding Tests** → Extend `BreedingTestBase`
- **Aminal Tests** → Extend `AminalTestBase`  
- **Skill Tests** → Extend `SkillTestBase`
- **Gene Tests** → Extend `GeneTestBase`

### 2. Remove Duplicated Code

Remove from your test:
- Contract deployments (handled by base)
- Standard user creation (use inherited users)
- Common helper functions
- Repeated test data

### 3. Update setUp()

```solidity
function setUp() public override {
    super.setUp(); // MUST call parent setUp
    
    // Only add test-specific setup here
}
```

### 4. Use Inherited Helpers

Replace manual operations with helpers:

| Before | After |
|--------|-------|
| `vm.prank(user); (bool s,) = aminal.call{value: amt}("");` | `_feedAminal(user, aminal, amt);` |
| `vm.warp(block.timestamp + 3 days + 1);` | `_warpToVotingPhase();` |
| Manual breeding ticket creation | `_createBreedingTicket();` |
| `getCurrentPhase(ticketId)` | `_getCurrentPhase(ticketId);` |

### 5. Update Test Names

Follow naming conventions:
- `test_DescriptiveName` for normal tests
- `test_RevertWhen_Condition` for revert tests
- `testFuzz_Name` for fuzz tests

### 6. Move to Correct Directory

```
test/
├── unit/
│   ├── aminal/     # Core Aminal tests
│   ├── breeding/   # Breeding mechanism tests
│   ├── genes/      # Gene NFT tests
│   └── skills/     # Skill tests
├── integration/    # Multi-contract tests
├── invariant/      # Property tests
└── gas/           # Performance tests
```

## Common Patterns

### Testing Phases

```solidity
function test_PhaseTransitions() public {
    uint256 ticketId = _createBreedingTicket();
    
    // Gene proposal phase
    _assertPhase(ticketId, Phase.GENE_PROPOSAL);
    
    // Voting phase
    _warpToVotingPhase();
    _assertPhase(ticketId, Phase.VOTING);
    
    // Execution phase
    _warpToExecutionPhase();
    _assertPhase(ticketId, Phase.EXECUTION);
}
```

### Testing with Multiple Users

```solidity
function test_MultiUserScenario() public {
    // Use inherited users: user1, user2, user3
    // Or create test-specific users
    address alice = makeAddr("alice");
    vm.deal(alice, 10 ether);
    
    // Use helpers for common operations
    _feedAminal(alice, parent1, 1 ether);
}
```

### Custom Assertions

```solidity
// Use TestAssertions helpers
assertGenes(actual, expected, "Child should have expected genes");
assertLoveInRange(love, min, max, "Love out of bounds");
assertEnergyConsumed(before, after, expected, "Wrong energy consumption");
```

## Benefits

1. **Reduced Code**: ~30-40% less test code
2. **Consistency**: All tests follow same patterns
3. **Maintainability**: Changes in one place
4. **Readability**: Focus on test logic, not setup
5. **Performance**: Reusable setup reduces redundancy