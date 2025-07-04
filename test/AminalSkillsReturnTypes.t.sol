// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {Aminal} from "src/Aminal.sol";
import {ITraits} from "src/interfaces/ITraits.sol";

// Contract that returns various weird data types
contract WeirdReturnSkills {
    // Returns a string (dynamic type)
    function returnString() external pure returns (string memory) {
        return "Hello, I'm a skill that returns a string!";
    }
    
    // Returns a long string
    function returnLongString() external pure returns (string memory) {
        return "This is a very long string that definitely exceeds 32 bytes and should not be interpreted as a reasonable energy cost when decoded as uint256";
    }
    
    // Returns an array
    function returnArray() external pure returns (uint256[] memory) {
        uint256[] memory arr = new uint256[](3);
        arr[0] = 100;
        arr[1] = 200;
        arr[2] = 300;
        return arr;
    }
    
    // Returns a struct
    struct SkillResult {
        bool success;
        string message;
        uint256 cost;
    }
    
    function returnStruct() external pure returns (SkillResult memory) {
        return SkillResult({
            success: true,
            message: "Skill executed successfully",
            cost: 75
        });
    }
    
    // Returns multiple values
    function returnMultiple() external pure returns (uint256, string memory, bool) {
        return (42, "The answer", true);
    }
    
    // Returns bytes
    function returnBytes() external pure returns (bytes memory) {
        return hex"deadbeef";
    }
    
    // Returns bytes32
    function returnBytes32() external pure returns (bytes32) {
        return bytes32(uint256(123));
    }
    
    // Returns address
    function returnAddress() external view returns (address) {
        return address(this);
    }
    
    // Returns bool
    function returnBool() external pure returns (bool) {
        return true;
    }
    
    // Returns int256 (signed)
    function returnNegativeInt() external pure returns (int256) {
        return -100;
    }
    
    // Returns very large uint256
    function returnHugeNumber() external pure returns (uint256) {
        return type(uint256).max;
    }
    
    // Returns empty/no data
    function returnNothing() external pure {
        // No return statement
    }
}

contract AminalSkillsReturnTypesTest is Test {
    Aminal public aminal;
    WeirdReturnSkills public weirdSkills;
    
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
        
        // Deploy contracts
        aminal = new Aminal("TestAminal", "TAMINAL", "https://test.com/", traits);
        aminal.initialize("test-uri");
        
        weirdSkills = new WeirdReturnSkills();
        
        // Fund user
        deal(user1, 10 ether);
    }
    
    function test_StringReturn() public {
        // Feed the Aminal
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 1 ether}("");
        assertTrue(success);
        
        // Call skill that returns string
        bytes memory skillData = abi.encodeWithSelector(WeirdReturnSkills.returnString.selector);
        
        uint256 energyBefore = aminal.energy();
        uint256 loveBefore = aminal.loveFromUser(user1);
        
        vm.prank(user1);
        aminal.useSkill(address(weirdSkills), skillData);
        
        // String return will have offset pointer as first 32 bytes
        // This will be interpreted as a large number
        uint256 consumed = energyBefore - aminal.energy();
        console.log("String return consumed:", consumed);
        
        // Should consume some amount based on the offset
        assertGt(consumed, 0);
        assertEq(aminal.loveFromUser(user1), loveBefore - consumed);
    }
    
    function test_LongStringReturn() public {
        // Feed the Aminal with lots of energy
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 10 ether}("");
        assertTrue(success);
        
        // Call skill that returns long string
        bytes memory skillData = abi.encodeWithSelector(WeirdReturnSkills.returnLongString.selector);
        
        uint256 energyBefore = aminal.energy();
        
        vm.prank(user1);
        aminal.useSkill(address(weirdSkills), skillData);
        
        // Should consume based on offset pointer
        uint256 consumed = energyBefore - aminal.energy();
        console.log("Long string return consumed:", consumed);
        assertGt(consumed, 0);
    }
    
    function test_ArrayReturn() public {
        // Feed the Aminal
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 1 ether}("");
        assertTrue(success);
        
        // Call skill that returns array
        bytes memory skillData = abi.encodeWithSelector(WeirdReturnSkills.returnArray.selector);
        
        uint256 energyBefore = aminal.energy();
        
        vm.prank(user1);
        aminal.useSkill(address(weirdSkills), skillData);
        
        // Array return will have offset pointer as first 32 bytes
        uint256 consumed = energyBefore - aminal.energy();
        console.log("Array return consumed:", consumed);
        assertGt(consumed, 0);
    }
    
    function test_StructReturn() public {
        // Feed the Aminal
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 1 ether}("");
        assertTrue(success);
        
        // Call skill that returns struct
        bytes memory skillData = abi.encodeWithSelector(WeirdReturnSkills.returnStruct.selector);
        
        uint256 energyBefore = aminal.energy();
        
        vm.prank(user1);
        aminal.useSkill(address(weirdSkills), skillData);
        
        // Struct return will have offset pointer as first 32 bytes
        uint256 consumed = energyBefore - aminal.energy();
        console.log("Struct return consumed:", consumed);
        assertGt(consumed, 0);
    }
    
    function test_MultipleReturn() public {
        // Feed the Aminal
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 1 ether}("");
        assertTrue(success);
        
        // Call skill that returns multiple values
        bytes memory skillData = abi.encodeWithSelector(WeirdReturnSkills.returnMultiple.selector);
        
        uint256 energyBefore = aminal.energy();
        
        vm.prank(user1);
        aminal.useSkill(address(weirdSkills), skillData);
        
        // First value is uint256(42)
        assertEq(aminal.energy(), energyBefore - 42);
    }
    
    function test_BytesReturn() public {
        // Feed the Aminal
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 1 ether}("");
        assertTrue(success);
        
        // Call skill that returns bytes
        bytes memory skillData = abi.encodeWithSelector(WeirdReturnSkills.returnBytes.selector);
        
        uint256 energyBefore = aminal.energy();
        
        vm.prank(user1);
        aminal.useSkill(address(weirdSkills), skillData);
        
        // Bytes return will have offset pointer
        uint256 consumed = energyBefore - aminal.energy();
        console.log("Bytes return consumed:", consumed);
        assertGt(consumed, 0);
    }
    
    function test_Bytes32Return() public {
        // Feed the Aminal
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 1 ether}("");
        assertTrue(success);
        
        // Call skill that returns bytes32
        bytes memory skillData = abi.encodeWithSelector(WeirdReturnSkills.returnBytes32.selector);
        
        uint256 energyBefore = aminal.energy();
        
        vm.prank(user1);
        aminal.useSkill(address(weirdSkills), skillData);
        
        // bytes32(uint256(123)) should consume 123
        assertEq(aminal.energy(), energyBefore - 123);
    }
    
    function test_AddressReturn() public {
        // Feed the Aminal
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 1 ether}("");
        assertTrue(success);
        
        // Call skill that returns address
        bytes memory skillData = abi.encodeWithSelector(WeirdReturnSkills.returnAddress.selector);
        
        uint256 energyBefore = aminal.energy();
        uint256 loveBefore = aminal.loveFromUser(user1);
        
        vm.prank(user1);
        aminal.useSkill(address(weirdSkills), skillData);
        
        // Address will be interpreted as uint256 but capped at 10000
        uint256 consumed = energyBefore - aminal.energy();
        console.log("Address return consumed:", consumed);
        console.log("Address as uint256:", uint256(uint160(address(weirdSkills))));
        
        // Should be capped at max reasonable cost (10000)
        assertEq(consumed, 10000);
        assertEq(aminal.loveFromUser(user1), loveBefore - consumed);
    }
    
    function test_BoolReturn() public {
        // Feed the Aminal
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 1 ether}("");
        assertTrue(success);
        
        // Call skill that returns bool
        bytes memory skillData = abi.encodeWithSelector(WeirdReturnSkills.returnBool.selector);
        
        uint256 energyBefore = aminal.energy();
        
        vm.prank(user1);
        aminal.useSkill(address(weirdSkills), skillData);
        
        // bool true is 1
        assertEq(aminal.energy(), energyBefore - 1);
    }
    
    function test_NegativeIntReturn() public {
        // Feed the Aminal
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 1 ether}("");
        assertTrue(success);
        
        // Call skill that returns negative int
        bytes memory skillData = abi.encodeWithSelector(WeirdReturnSkills.returnNegativeInt.selector);
        
        uint256 energyBefore = aminal.energy();
        uint256 loveBefore = aminal.loveFromUser(user1);
        
        vm.prank(user1);
        aminal.useSkill(address(weirdSkills), skillData);
        
        // -100 as uint256 will be a huge number but capped at 10000
        uint256 consumed = energyBefore - aminal.energy();
        console.log("Negative int consumed:", consumed);
        console.log("Negative int as uint256:", uint256(int256(-100)));
        
        // Should be capped at max reasonable cost (10000)
        assertEq(consumed, 10000);
        assertEq(aminal.loveFromUser(user1), loveBefore - consumed);
    }
    
    function test_HugeNumberReturn() public {
        // Feed the Aminal
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 1 ether}("");
        assertTrue(success);
        
        // Call skill that returns max uint256
        bytes memory skillData = abi.encodeWithSelector(WeirdReturnSkills.returnHugeNumber.selector);
        
        uint256 energyBefore = aminal.energy();
        uint256 loveBefore = aminal.loveFromUser(user1);
        
        // Should be capped at max reasonable cost
        vm.prank(user1);
        aminal.useSkill(address(weirdSkills), skillData);
        
        // Should be capped at 10000
        assertEq(aminal.energy(), energyBefore - 10000);
        assertEq(aminal.loveFromUser(user1), loveBefore - 10000);
    }
    
    function test_EmptyReturn() public {
        // Feed the Aminal
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 1 ether}("");
        assertTrue(success);
        
        // Call skill that returns nothing
        bytes memory skillData = abi.encodeWithSelector(WeirdReturnSkills.returnNothing.selector);
        
        uint256 energyBefore = aminal.energy();
        
        vm.prank(user1);
        aminal.useSkill(address(weirdSkills), skillData);
        
        // Should use default cost of 1
        assertEq(aminal.energy(), energyBefore - 1);
    }
    
    function test_ShortReturnData() public {
        // Feed the Aminal
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 1 ether}("");
        assertTrue(success);
        
        // Test with return data less than 32 bytes
        // Using inline assembly to create custom return data
        MockShortReturn shortReturn = new MockShortReturn();
        
        bytes memory skillData = abi.encodeWithSelector(MockShortReturn.returnShort.selector);
        
        uint256 energyBefore = aminal.energy();
        
        vm.prank(user1);
        aminal.useSkill(address(shortReturn), skillData);
        
        // Solidity pads return values to 32 bytes, so uint128(42) becomes 42
        assertEq(aminal.energy(), energyBefore - 42);
    }
}

// Helper contract for testing short return data
contract MockShortReturn {
    function returnShort() external pure returns (uint128) {
        return 42; // Only 16 bytes
    }
}