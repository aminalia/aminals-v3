// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {Aminal} from "src/Aminal.sol";
import {ITraits} from "src/interfaces/ITraits.sol";

// Contract for testing boundary cases around 1,000,000 threshold
contract MockBoundarySkill {
    function return999999() external pure returns (uint256) {
        return 999999;
    }
    
    function return1000000() external pure returns (uint256) {
        return 1000000;
    }
    
    function return1000001() external pure returns (uint256) {
        return 1000001;
    }
}

// Contract for testing malformed return data
contract MockMalformedSkill {
    // Return 31 bytes (odd length)
    function return31Bytes() external pure {
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, 42)
            return(ptr, 31) // Return only 31 bytes
        }
    }
    
    // Return 32 bytes of 0xFF
    function returnAllFF() external pure returns (bytes32) {
        return bytes32(type(uint256).max);
    }
    
    // Return empty but with non-zero return size
    function returnZeroWithSize() external pure {
        assembly {
            let ptr := mload(0x40)
            return(ptr, 32) // Return 32 bytes from uninitialized memory
        }
    }
}

// Contract with assembly-level return manipulation
contract AssemblyReturnSkill {
    // Return data that looks like multiple return values but isn't
    function trickyReturn() external pure {
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, 0x40) // Looks like offset pointer
            mstore(add(ptr, 0x20), 100) // Actual cost
            return(ptr, 0x40)
        }
    }
    
    // Return data with garbage after valid uint256
    function returnWithGarbage() external pure {
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, 42) // Valid cost
            mstore(add(ptr, 0x20), 0xDEADBEEF) // Garbage
            mstore(add(ptr, 0x40), 0xCAFEBABE) // More garbage
            return(ptr, 0x60) // Return 96 bytes
        }
    }
    
    // Return that shifts data
    function shiftedReturn() external pure {
        assembly {
            let ptr := mload(0x40)
            // Skip first 16 bytes
            mstore(add(ptr, 0x10), 75) // Cost at weird offset
            return(ptr, 0x30)
        }
    }
}

// Proxy pattern contracts
contract MockImplementation {
    function getCost() external pure returns (uint256) {
        return 123;
    }
    
    function complexReturn() external pure returns (uint256, bool, string memory) {
        return (456, true, "delegated");
    }
}

contract MockProxy {
    address public implementation;
    
    function setImplementation(address _impl) external {
        implementation = _impl;
    }
    
    fallback() external payable {
        address impl = implementation;
        assembly {
            let ptr := mload(0x40)
            calldatacopy(ptr, 0, calldatasize())
            let result := delegatecall(gas(), impl, ptr, calldatasize(), 0, 0)
            let size := returndatasize()
            returndatacopy(ptr, 0, size)
            
            switch result
            case 0 { revert(ptr, size) }
            default { return(ptr, size) }
        }
    }
}

// Contract that returns arbitrary data
contract MockRawReturnSkill {
    bytes public returnData;
    
    constructor(bytes memory _data) {
        returnData = _data;
    }
    
    function execute() external view {
        bytes memory data = returnData;
        assembly {
            return(add(data, 0x20), mload(data))
        }
    }
}

// Contract with error-like returns
contract ErrorSelectorSkill {
    // Function selector that could be confused with error
    function Error() external pure returns (uint256) {
        return 50;
    }
    
    // Return data that looks like an error message
    function returnErrorLikeData() external pure returns (bytes32) {
        // First 4 bytes look like Error(string) selector
        return bytes32(abi.encodePacked(bytes4(0x08c379a0), uint256(0x20)));
    }
    
    // Return revert-like data structure
    function returnRevertStructure() external pure {
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, 0x08c379a0) // Error(string) selector
            mstore(add(ptr, 0x04), 0x20) // Offset to string
            mstore(add(ptr, 0x24), 0x0d) // String length
            mstore(add(ptr, 0x44), "Test message") // String data
            return(ptr, 0x64)
        }
    }
}

// Gas intensive operations
contract GasIntensiveSkill {
    uint256[] public hugeArray;
    
    function expensiveReturn() external returns (uint256) {
        // Do some expensive operations
        for (uint i = 0; i < 100; i++) {
            hugeArray.push(i);
        }
        return 88;
    }
    
    // Function that runs out of gas during return
    function almostOutOfGas() external view returns (uint256) {
        uint256 remaining = gasleft();
        // Burn most of the gas
        while (gasleft() > 5000) {
            remaining = remaining * 2 / 2;
        }
        return 77;
    }
}

// ABI encoding edge cases
contract ABIEdgeCaseSkill {
    struct ComplexStruct {
        uint256[] values;
        string message;
        bytes data;
    }
    
    // No parameters but complex return
    function noParamsComplexReturn() external pure returns (ComplexStruct memory) {
        uint256[] memory vals = new uint256[](2);
        vals[0] = 111;
        vals[1] = 222;
        
        return ComplexStruct({
            values: vals,
            message: "complex",
            data: hex"deadbeef"
        });
    }
    
    // Function that should be called with packed encoding
    function packedReturn() external pure returns (uint128, uint128) {
        return (uint128(33), uint128(44));
    }
    
    // Nested dynamic types
    function nestedDynamic() external pure returns (string[] memory) {
        string[] memory strings = new string[](3);
        strings[0] = "first";
        strings[1] = "second";
        strings[2] = "third";
        return strings;
    }
    
    // Fixed size array return
    function fixedArray() external pure returns (uint256[3] memory) {
        return [uint256(10), 20, 30];
    }
}

// Main test contract
contract AminalSkillsParsingEdgeCasesTest is Test {
    Aminal public aminal;
    address public user1 = makeAddr("user1");
    
    function setUp() public {
        // Create test traits
        ITraits.Traits memory traits = ITraits.Traits({
            back: "wings",
            arm: "claws", 
            tail: "fluffy",
            ears: "pointy",
            body: "furry",
            face: "cute",
            mouth: "smile",
            misc: "sparkles"
        });
        
        // Deploy Aminal
        aminal = new Aminal("TestAminal", "TAMINAL", "https://test.com/", traits);
        aminal.initialize("test-uri");
        
        // Fund user
        deal(user1, 100 ether);
    }
    
    function test_ThresholdBoundaryCases() public {
        MockBoundarySkill boundarySkill = new MockBoundarySkill();
        
        // Feed the Aminal with lots of energy
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 10 ether}("");
        assertTrue(success);
        
        uint256 energyBefore;
        uint256 loveBefore;
        
        // Test 999,999 (should pass through)
        energyBefore = aminal.energy();
        loveBefore = aminal.loveFromUser(user1);
        vm.prank(user1);
        aminal.useSkill(address(boundarySkill), abi.encodeWithSelector(MockBoundarySkill.return999999.selector));
        
        // Cap at 10,000 due to Aminal's cap logic
        uint256 consumed = energyBefore - aminal.energy();
        assertEq(consumed, 10000, "999,999 should be capped at 10,000");
        assertEq(loveBefore - aminal.loveFromUser(user1), consumed);
        
        // Test 1,000,000 (should pass through but capped)
        energyBefore = aminal.energy();
        loveBefore = aminal.loveFromUser(user1);
        vm.prank(user1);
        aminal.useSkill(address(boundarySkill), abi.encodeWithSelector(MockBoundarySkill.return1000000.selector));
        consumed = energyBefore - aminal.energy();
        assertEq(consumed, 10000, "1,000,000 should be capped at 10,000");
        
        // Test 1,000,001 (should default to 1 in parser)
        energyBefore = aminal.energy();
        loveBefore = aminal.loveFromUser(user1);
        vm.prank(user1);
        aminal.useSkill(address(boundarySkill), abi.encodeWithSelector(MockBoundarySkill.return1000001.selector));
        consumed = energyBefore - aminal.energy();
        assertEq(consumed, 1, "1,000,001 should default to 1");
        assertEq(loveBefore - aminal.loveFromUser(user1), consumed);
    }
    
    function test_MalformedReturnData() public {
        MockMalformedSkill malformed = new MockMalformedSkill();
        
        // Feed the Aminal
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 1 ether}("");
        assertTrue(success);
        
        uint256 energyBefore;
        
        // Test with odd-length return data (31 bytes)
        energyBefore = aminal.energy();
        vm.prank(user1);
        aminal.useSkill(address(malformed), abi.encodeWithSelector(MockMalformedSkill.return31Bytes.selector));
        assertEq(energyBefore - aminal.energy(), 1, "31 bytes should default to 1");
        
        // Test with exactly 32 bytes of 0xFF
        energyBefore = aminal.energy();
        vm.prank(user1);
        aminal.useSkill(address(malformed), abi.encodeWithSelector(MockMalformedSkill.returnAllFF.selector));
        assertEq(energyBefore - aminal.energy(), 1, "Max uint256 should default to 1");
        
        // Test with zero from uninitialized memory
        energyBefore = aminal.energy();
        vm.prank(user1);
        aminal.useSkill(address(malformed), abi.encodeWithSelector(MockMalformedSkill.returnZeroWithSize.selector));
        // Might be 0 or garbage, but should consume at least 1
        assertGe(energyBefore - aminal.energy(), 1);
    }
    
    function test_AssemblyLevelReturnManipulation() public {
        AssemblyReturnSkill asmSkill = new AssemblyReturnSkill();
        
        // Feed the Aminal
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 1 ether}("");
        assertTrue(success);
        
        uint256 energyBefore;
        
        // Test tricky return that looks like multiple values
        energyBefore = aminal.energy();
        vm.prank(user1);
        aminal.useSkill(address(asmSkill), abi.encodeWithSelector(AssemblyReturnSkill.trickyReturn.selector));
        // First word is 0x40 (64), which should be interpreted as cost
        assertEq(energyBefore - aminal.energy(), 64);
        
        // Test return with garbage after valid data
        energyBefore = aminal.energy();
        vm.prank(user1);
        aminal.useSkill(address(asmSkill), abi.encodeWithSelector(AssemblyReturnSkill.returnWithGarbage.selector));
        assertEq(energyBefore - aminal.energy(), 42, "Should use first 32 bytes only");
        
        // Test shifted return data
        energyBefore = aminal.energy();
        vm.prank(user1);
        aminal.useSkill(address(asmSkill), abi.encodeWithSelector(AssemblyReturnSkill.shiftedReturn.selector));
        // Parser reads first 32 bytes which contains partial data
        uint256 consumed = energyBefore - aminal.energy();
        console.log("Shifted return consumed:", consumed);
    }
    
    function test_ProxyContractReturns() public {
        MockProxy proxy = new MockProxy();
        MockImplementation impl = new MockImplementation();
        proxy.setImplementation(address(impl));
        
        // Feed the Aminal
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 1 ether}("");
        assertTrue(success);
        
        uint256 energyBefore;
        
        // Call simple cost function through proxy
        energyBefore = aminal.energy();
        bytes memory skillData = abi.encodeWithSelector(MockImplementation.getCost.selector);
        vm.prank(user1);
        aminal.useSkill(address(proxy), skillData);
        assertEq(energyBefore - aminal.energy(), 123, "Proxy should return 123");
        
        // Call complex return through proxy
        energyBefore = aminal.energy();
        skillData = abi.encodeWithSelector(MockImplementation.complexReturn.selector);
        vm.prank(user1);
        aminal.useSkill(address(proxy), skillData);
        // Multiple returns: first uint256 is 456
        assertEq(energyBefore - aminal.energy(), 456, "Complex proxy return should use first uint256");
    }
    
    function testFuzz_RandomReturnDataParsing(bytes memory randomData) public {
        // Limit random data to reasonable size
        if (randomData.length > 1000) {
            bytes memory truncated = new bytes(1000);
            for (uint i = 0; i < 1000; i++) {
                truncated[i] = randomData[i];
            }
            randomData = truncated;
        }
        
        MockRawReturnSkill rawSkill = new MockRawReturnSkill(randomData);
        
        // Feed the Aminal
        vm.deal(user1, 10 ether);
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 1 ether}("");
        assertTrue(success);
        
        uint256 energyBefore = aminal.energy();
        uint256 loveBefore = aminal.loveFromUser(user1);
        
        // Use skill with random return data
        vm.prank(user1);
        aminal.useSkill(address(rawSkill), abi.encodeWithSelector(MockRawReturnSkill.execute.selector));
        
        // Should always consume between 1 and min(10000, available energy)
        uint256 consumed = energyBefore - aminal.energy();
        assertGe(consumed, 1, "Should consume at least 1");
        assertLe(consumed, 10000, "Should not exceed cap of 10000");
        assertEq(loveBefore - aminal.loveFromUser(user1), consumed, "Love and energy consumed should match");
    }
    
    function test_ErrorSelectorCollisions() public {
        ErrorSelectorSkill errorSkill = new ErrorSelectorSkill();
        
        // Feed the Aminal
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 1 ether}("");
        assertTrue(success);
        
        uint256 energyBefore;
        
        // Test function named Error()
        energyBefore = aminal.energy();
        vm.prank(user1);
        aminal.useSkill(address(errorSkill), abi.encodeWithSelector(ErrorSelectorSkill.Error.selector));
        assertEq(energyBefore - aminal.energy(), 50, "Error() function should return 50");
        
        // Test return that looks like error data
        energyBefore = aminal.energy();
        vm.prank(user1);
        aminal.useSkill(address(errorSkill), abi.encodeWithSelector(ErrorSelectorSkill.returnErrorLikeData.selector));
        // bytes32 with error selector pattern - parser should handle it
        uint256 consumed = energyBefore - aminal.energy();
        console.log("Error-like data consumed:", consumed);
        
        // Test full revert structure return
        energyBefore = aminal.energy();
        vm.prank(user1);
        aminal.useSkill(address(errorSkill), abi.encodeWithSelector(ErrorSelectorSkill.returnRevertStructure.selector));
        // Should detect as dynamic type (offset at 0x20) and default to 1
        assertEq(energyBefore - aminal.energy(), 1, "Revert structure should default to 1");
    }
    
    function test_GasLimitEdgeCases() public {
        GasIntensiveSkill gasSkill = new GasIntensiveSkill();
        
        // Feed the Aminal
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 1 ether}("");
        assertTrue(success);
        
        uint256 energyBefore;
        
        // Test expensive operation
        energyBefore = aminal.energy();
        vm.prank(user1);
        aminal.useSkill(address(gasSkill), abi.encodeWithSelector(GasIntensiveSkill.expensiveReturn.selector));
        assertEq(energyBefore - aminal.energy(), 88, "Should return 88 despite gas usage");
        
        // Test near gas limit - use more reasonable gas limit
        energyBefore = aminal.energy();
        vm.prank(user1);
        aminal.useSkill{gas: 500000}(address(gasSkill), abi.encodeWithSelector(GasIntensiveSkill.almostOutOfGas.selector));
        assertEq(energyBefore - aminal.energy(), 77, "Should handle low gas gracefully");
    }
    
    function test_ABIEncodingEdgeCases() public {
        ABIEdgeCaseSkill edgeSkill = new ABIEdgeCaseSkill();
        
        // Feed the Aminal
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 1 ether}("");
        assertTrue(success);
        
        uint256 energyBefore;
        
        // Test complex struct return
        energyBefore = aminal.energy();
        vm.prank(user1);
        aminal.useSkill(address(edgeSkill), abi.encodeWithSelector(ABIEdgeCaseSkill.noParamsComplexReturn.selector));
        assertEq(energyBefore - aminal.energy(), 1, "Complex struct should default to 1");
        
        // Test packed return (two uint128s)
        energyBefore = aminal.energy();
        vm.prank(user1);
        aminal.useSkill(address(edgeSkill), abi.encodeWithSelector(ABIEdgeCaseSkill.packedReturn.selector));
        // First uint128 is 33, padded to uint256
        assertEq(energyBefore - aminal.energy(), 33, "Should read first uint128 as uint256");
        
        // Test nested dynamic array
        energyBefore = aminal.energy();
        vm.prank(user1);
        aminal.useSkill(address(edgeSkill), abi.encodeWithSelector(ABIEdgeCaseSkill.nestedDynamic.selector));
        assertEq(energyBefore - aminal.energy(), 1, "Nested dynamic should default to 1");
        
        // Test fixed array
        energyBefore = aminal.energy();
        vm.prank(user1);
        aminal.useSkill(address(edgeSkill), abi.encodeWithSelector(ABIEdgeCaseSkill.fixedArray.selector));
        // Fixed array starts with first element directly
        assertEq(energyBefore - aminal.energy(), 10, "Fixed array should use first element");
    }
    
    function test_ZeroAddressSkill() public {
        // Feed the Aminal
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 1 ether}("");
        assertTrue(success);
        
        // Try to call skill on zero address
        uint256 energyBefore = aminal.energy();
        vm.prank(user1);
        aminal.useSkill(address(0), abi.encodeWithSelector(bytes4(0x12345678)));
        
        // Zero address returns empty data, so should consume default of 1
        assertEq(energyBefore - aminal.energy(), 1, "Zero address should consume 1 energy");
    }
    
    function test_SelfCallSkill() public {
        // Feed the Aminal
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 1 ether}("");
        assertTrue(success);
        
        // Try to call a function on the Aminal itself
        bytes memory skillData = abi.encodeWithSelector(Aminal.getEnergy.selector);
        
        uint256 energyBefore = aminal.energy();
        vm.prank(user1);
        aminal.useSkill(address(aminal), skillData);
        
        // getEnergy returns current energy value, which should be interpreted as cost
        // But capped at 10,000
        uint256 consumed = energyBefore - aminal.energy();
        assertEq(consumed, 10000, "Self-call should be capped at 10,000");
    }
}