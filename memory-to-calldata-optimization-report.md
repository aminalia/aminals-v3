# Memory to Calldata Optimization Report

## Summary
This report identifies functions in the Aminals v3 codebase where `memory` parameters could be changed to `calldata` for gas optimization. The `calldata` keyword is more gas-efficient than `memory` for external/public function parameters that are read-only.

## Key Optimization Opportunities

### 1. **Aminal.sol**

#### `initialize(string memory uri)` - Line 211
- **Current**: `string memory uri`
- **Recommendation**: Change to `string calldata uri`
- **Reason**: External function, parameter is read-only

#### `initialize(string memory uri, GeneReference[8] memory geneRefs)` - Line 223
- **Current**: `string memory uri`, `GeneReference[8] memory geneRefs`
- **Recommendation**: Change to `string calldata uri`, `GeneReference[8] calldata geneRefs`
- **Reason**: Public function, parameters are read-only

#### `setBaseURI(string memory newBaseURI)` - Line 254
- **Current**: `string memory newBaseURI`
- **Recommendation**: Change to `string calldata newBaseURI`
- **Reason**: External function, parameter is read-only

### 2. **AminalFactory.sol**

#### Constructor parameters - Line 145-150
- **Current**: `string memory baseURI`, `ParentData memory firstParentData`, `ParentData memory secondParentData`
- **Recommendation**: Keep as `memory` (constructors require memory)
- **Reason**: Constructor parameters cannot use calldata

#### `createAminal()` - Line 196-202
- **Current**: Multiple `string memory` parameters, `IGenes.Genes memory traits`
- **Recommendation**: Change all to `calldata`
- **Reason**: External function (though it reverts), parameters are read-only

#### `batchCreateAminals()` - Line 295-301
- **Current**: Multiple `string[] memory` and `IGenes.Genes[] memory` parameters
- **Recommendation**: Change all to `calldata`
- **Reason**: External function (though it reverts), parameters are read-only

#### `createAminalWithGenes()` - Line 315-321
- **Current**: Multiple `string memory` parameters, `IGenes.Genes memory genes`
- **Recommendation**: Change all to `calldata`
- **Reason**: External function, parameters are read-only

#### `setBaseURI(string memory newBaseURI)` - Line 338
- **Current**: `string memory newBaseURI`
- **Recommendation**: Change to `string calldata newBaseURI`
- **Reason**: External function, parameter is read-only

#### `breed()` - Line 406-410
- **Current**: `string memory childDescription`, `string memory childTokenURI`
- **Recommendation**: Change to `string calldata childDescription`, `string calldata childTokenURI`
- **Reason**: External function, parameters are read-only

#### Internal `_createAminal()` - Line 233-239
- **Current**: Multiple `string memory` parameters, `IGenes.Genes memory genes`
- **Recommendation**: Keep as `memory`
- **Reason**: Internal functions should use memory for flexibility

### 3. **Gene.sol**

#### `mint()` - Line 77-83
- **Current**: Multiple `string memory` parameters
- **Recommendation**: Change all to `calldata`
- **Reason**: External function, parameters are read-only

#### `batchMint()` - Line 114-120
- **Current**: Multiple array `memory` parameters
- **Recommendation**: Change all to `calldata`
- **Reason**: External function, parameters are read-only

### 4. **BreedingSkill.sol**

#### `createProposal()` - Line 122-126
- **Current**: `string memory childDescription`, `string memory childTokenURI`
- **Recommendation**: Change to `string calldata childDescription`, `string calldata childTokenURI`
- **Reason**: External function, parameters are read-only

#### `acceptProposal()` - Line 173
- **Note**: No memory parameters, just noting for completeness

### 5. **AminalBreedingVote.sol**

#### `createBreedingTicket()` - Line 200-205
- **Current**: `string memory childDescription`, `string memory childTokenURI`
- **Recommendation**: Change to `string calldata childDescription`, `string calldata childTokenURI`
- **Reason**: External function, parameters are read-only

### 6. **GeneRenderer.sol (Library)**

#### Library functions with memory parameters
- **Note**: Library functions that are internal should keep `memory` parameters for flexibility
- **Reason**: Libraries are often used internally and need to work with both memory and calldata

### 7. **Interfaces**

#### `IAminalBreedingVote.createBreedingTicket()` - Line 18-23
- **Current**: `string memory childDescription`, `string memory childTokenURI`
- **Recommendation**: Change to `string calldata childDescription`, `string calldata childTokenURI`
- **Reason**: Interface should match the implementation's optimization

## Additional Findings

### View Functions That Could Be Optimized

While less critical than state-changing functions, view functions can also benefit from calldata:

1. **Gene.getTokensByTraitType()** - Line 203
   - **Current**: `string memory traitType`
   - **Recommendation**: Change to `string calldata traitType`
   - **Reason**: External view function, parameter is read-only

2. **Gene.getTokensByTraitValue()** - Line 228
   - **Current**: `string memory traitValue`
   - **Recommendation**: Change to `string calldata traitValue`
   - **Reason**: External view function, parameter is read-only

## Gas Savings Estimate

Changing from `memory` to `calldata` can save approximately:
- **String parameters**: ~200-500 gas per string depending on length
- **Array parameters**: ~1000+ gas for arrays depending on size
- **Struct parameters**: ~500-1000 gas per struct

## Implementation Priority

1. **High Priority** (Most gas savings):
   - `Gene.batchMint()` - Arrays of strings
   - `AminalFactory.batchCreateAminals()` - Arrays of strings and structs
   - `Aminal.initialize()` with GeneReference array

2. **Medium Priority** (Moderate gas savings):
   - `Gene.mint()` - Multiple string parameters
   - `AminalFactory.createAminalWithGenes()` - Multiple parameters
   - `AminalFactory.breed()` - Two string parameters
   - `BreedingSkill.createProposal()` - Two string parameters

3. **Low Priority** (Minor gas savings):
   - Single string parameter functions like `setBaseURI()`

## Testing Recommendations

After implementing these changes:
1. Run the full test suite to ensure no functionality is broken
2. Add specific gas benchmark tests to measure the improvements
3. Verify that all external integrations still work correctly

## Notes

- Constructor parameters must remain as `memory`
- Internal function parameters should generally remain as `memory` for flexibility
- View/pure functions can also benefit from `calldata` parameters
- These optimizations are most beneficial for functions that are called frequently

## Summary of Recommended Changes

Total functions identified for optimization: **15 functions**

By contract:
- **Aminal.sol**: 3 functions
- **AminalFactory.sol**: 5 functions
- **Gene.sol**: 4 functions
- **BreedingSkill.sol**: 1 function
- **AminalBreedingVote.sol**: 1 function
- **IAminalBreedingVote.sol**: 1 interface function

Estimated total gas savings: Approximately 3,000-10,000 gas per transaction depending on the function and parameter sizes.