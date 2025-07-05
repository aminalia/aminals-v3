# Aminals Test Style Guide

## Test Naming Conventions

### Basic Tests
```solidity
function test_DescriptiveNameInPascalCase() public {
    // Tests normal behavior
}
```

### Revert Tests
```solidity
function test_RevertWhen_ConditionDescription() public {
    // Tests expected reverts
    vm.expectRevert(Error.selector);
}

function test_RevertIf_ConditionDescription() public {
    // Alternative for conditional reverts
}
```

### Fuzz Tests
```solidity
function testFuzz_FunctionName(uint256 param) public {
    // Property-based testing
}
```

### Fork Tests
```solidity
function testFork_ScenarioDescription() public {
    // Tests against forked state
}
```

### Invariant Tests
```solidity
function invariant_PropertyDescription() public {
    // Invariant that should always hold
}
```

## Test Organization

### 1. Use Base Test Contracts
- Extend `BreedingTestBase` for breeding tests
- Create domain-specific base contracts to reduce duplication

### 2. Group Related Tests
```solidity
// Group by functionality
contract AminalEnergyTest is Test { }
contract AminalLoveTest is Test { }
contract AminalSkillsTest is Test { }
```

### 3. Test Structure (AAA Pattern)
```solidity
function test_Example() public {
    // Arrange - Set up test data
    uint256 amount = 1 ether;
    address user = makeAddr("user");
    
    // Act - Perform the action
    vm.prank(user);
    contract.doSomething(amount);
    
    // Assert - Check the results
    assertEq(contract.value(), amount);
}
```

## Common Patterns

### 1. Use Helper Functions
```solidity
// Good
_feedAminal(user, aminal, 1 ether);
_warpToVotingPhase();

// Bad
vm.prank(user);
(bool success,) = aminal.call{value: 1 ether}("");
assertTrue(success);
vm.warp(block.timestamp + 3 days + 1);
```

### 2. Descriptive Assertions
```solidity
// Good
assertEq(result, expected, "Breeding should create child with parent1 traits");

// Bad
assertEq(result, expected);
```

### 3. Constants Over Magic Numbers
```solidity
// Good
uint256 constant VOTING_DURATION = 4 days;
vm.warp(block.timestamp + VOTING_DURATION);

// Bad
vm.warp(block.timestamp + 345600); // 4 days in seconds
```

### 4. Explicit Test Phases
```solidity
function test_ComplexScenario() public {
    // === Setup Phase ===
    address user = makeAddr("user");
    
    // === Execution Phase ===
    vm.prank(user);
    contract.action();
    
    // === Verification Phase ===
    assertEq(contract.state(), expected);
}
```

## Edge Cases to Test

1. **Boundary Values**
   - Zero amounts
   - Maximum values
   - One wei differences

2. **State Transitions**
   - Before/after phase changes
   - Exact deadline moments

3. **Access Control**
   - Unauthorized callers
   - Self-restricted functions

4. **Reentrancy**
   - Callbacks during execution
   - State consistency

## Test Data Management

### 1. Use Fixtures
```solidity
function dragonTraits() internal pure returns (IGenes.Genes memory) {
    return IGenes.Genes({
        back: "Dragon Wings",
        // ... complete struct
    });
}
```

### 2. Parameterized Helpers
```solidity
function _createAminalWithTraits(
    string memory name,
    IGenes.Genes memory traits
) internal returns (address) {
    // Reusable creation logic
}
```

## Performance Considerations

1. **Minimize Storage Reads**
   - Cache values in memory
   - Batch related operations

2. **Efficient Fuzzing**
   - Use `bound()` for constrained inputs
   - Avoid `vm.assume()` when possible

3. **Skip Expensive Tests**
   ```solidity
   function test_ExpensiveOperation() public {
       if (!vm.envBool("RUN_EXPENSIVE_TESTS")) {
           vm.skip(true);
           return;
       }
       // Expensive test logic
   }
   ```

## Documentation

### Test Comments
```solidity
/**
 * @notice Tests that veto wins when votes are tied
 * @dev This ensures the conservative approach where ties prevent breeding
 */
function test_VetoWinsOnTie() public {
    // Implementation
}
```

### Scenario Documentation
```solidity
function test_ComplexBreedingScenario() public {
    // Scenario: Two users propose breeding, multiple voters participate,
    // some change their votes, and a gene is proposed mid-voting
    
    // Step 1: Create breeding proposal
    // Step 2: Initial votes cast
    // Step 3: Gene proposal added
    // Step 4: Votes changed
    // Step 5: Execute breeding
}
```