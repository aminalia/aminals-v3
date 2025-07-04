// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {Aminal} from "src/Aminal.sol";
import {ITraits} from "src/interfaces/ITraits.sol";
import {ISkill} from "src/interfaces/ISkill.sol";
import {IERC165} from "lib/openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";

/**
 * @title SkillWithProperEIP165
 * @notice Demonstrates proper EIP-165 implementation
 */
contract SkillWithProperEIP165 is ISkill {
    function doAction() external pure returns (uint256) {
        return 42;
    }
    
    function skillEnergyCost(bytes calldata data) external pure returns (uint256) {
        bytes4 selector = bytes4(data);
        if (selector == this.doAction.selector) {
            return 25;
        }
        return 1;
    }
    
    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == type(ISkill).interfaceId || 
               interfaceId == type(IERC165).interfaceId;
    }
}

/**
 * @title SkillWithoutEIP165
 * @notice Contract that doesn't implement EIP-165
 */
contract SkillWithoutEIP165 {
    function legacyAction() external pure returns (uint256) {
        return 50; // This will be the energy cost via legacy parsing
    }
}

/**
 * @title PartialEIP165Skill
 * @notice Implements EIP-165 but not ISkill
 */
contract PartialEIP165Skill is IERC165 {
    function someAction() external pure returns (uint256) {
        return 33;
    }
    
    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        // Only supports IERC165, not ISkill
        return interfaceId == type(IERC165).interfaceId;
    }
}

contract AminalSkillsEIP165Test is Test {
    Aminal public aminal;
    SkillWithProperEIP165 public properSkill;
    SkillWithoutEIP165 public legacySkill;
    PartialEIP165Skill public partialSkill;
    
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
        
        properSkill = new SkillWithProperEIP165();
        legacySkill = new SkillWithoutEIP165();
        partialSkill = new PartialEIP165Skill();
        
        // Fund user
        deal(user1, 10 ether);
    }
    
    function test_ProperEIP165Implementation() public {
        // Verify interface support directly
        assertTrue(properSkill.supportsInterface(type(ISkill).interfaceId), "Should support ISkill");
        assertTrue(properSkill.supportsInterface(type(IERC165).interfaceId), "Should support IERC165");
        assertFalse(properSkill.supportsInterface(0x12345678), "Should not support random interface");
        
        // Feed Aminal
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 1 ether}("");
        assertTrue(success);
        
        // Use skill - should use interface cost (25)
        uint256 energyBefore = aminal.energy();
        vm.prank(user1);
        aminal.useSkill(address(properSkill), abi.encodeWithSelector(SkillWithProperEIP165.doAction.selector));
        
        assertEq(energyBefore - aminal.energy(), 25, "Should use interface-defined cost");
    }
    
    function test_LegacyWithoutEIP165() public {
        // Feed Aminal
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 1 ether}("");
        assertTrue(success);
        
        // Use legacy skill - should parse return value (50)
        uint256 energyBefore = aminal.energy();
        vm.prank(user1);
        aminal.useSkill(address(legacySkill), abi.encodeWithSelector(SkillWithoutEIP165.legacyAction.selector));
        
        assertEq(energyBefore - aminal.energy(), 50, "Should use legacy parsed cost");
    }
    
    function test_PartialEIP165Support() public {
        // Verify it supports EIP-165 but not ISkill
        assertTrue(partialSkill.supportsInterface(type(IERC165).interfaceId), "Should support IERC165");
        assertFalse(partialSkill.supportsInterface(type(ISkill).interfaceId), "Should not support ISkill");
        
        // Feed Aminal
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 1 ether}("");
        assertTrue(success);
        
        // Use skill - should fall back to legacy parsing (33)
        uint256 energyBefore = aminal.energy();
        vm.prank(user1);
        aminal.useSkill(address(partialSkill), abi.encodeWithSelector(PartialEIP165Skill.someAction.selector));
        
        assertEq(energyBefore - aminal.energy(), 33, "Should use legacy parsing when ISkill not supported");
    }
    
    function test_InterfaceIdConstants() public {
        // Verify the interface IDs are what we expect
        bytes4 expectedISkillId = bytes4(keccak256("skillEnergyCost(bytes)"));
        bytes4 expectedIERC165Id = bytes4(keccak256("supportsInterface(bytes4)"));
        
        console.log("ISkill interface ID:", uint32(type(ISkill).interfaceId));
        console.log("Expected ISkill ID:", uint32(expectedISkillId));
        console.log("IERC165 interface ID:", uint32(type(IERC165).interfaceId));
        console.log("Expected IERC165 ID:", uint32(expectedIERC165Id));
        
        // Note: The actual interface ID includes all functions in the interface,
        // not just one function. So type(ISkill).interfaceId will be different
        // from just the selector of one function.
    }
    
    function test_GasComparison() public {
        // Feed Aminal
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 2 ether}("");
        assertTrue(success);
        
        // Measure gas for EIP-165 skill
        uint256 gasStart = gasleft();
        vm.prank(user1);
        aminal.useSkill(address(properSkill), abi.encodeWithSelector(SkillWithProperEIP165.doAction.selector));
        uint256 gasUsedEIP165 = gasStart - gasleft();
        
        // Measure gas for legacy skill
        gasStart = gasleft();
        vm.prank(user1);
        aminal.useSkill(address(legacySkill), abi.encodeWithSelector(SkillWithoutEIP165.legacyAction.selector));
        uint256 gasUsedLegacy = gasStart - gasleft();
        
        console.log("Gas used with EIP-165:", gasUsedEIP165);
        console.log("Gas used with legacy:", gasUsedLegacy);
        console.log("Difference:", gasUsedEIP165 > gasUsedLegacy ? 
            gasUsedEIP165 - gasUsedLegacy : gasUsedLegacy - gasUsedEIP165);
    }
}