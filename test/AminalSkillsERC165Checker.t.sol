// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {Aminal} from "src/Aminal.sol";
import {ITraits} from "src/interfaces/ITraits.sol";
import {ISkill} from "src/interfaces/ISkill.sol";
import {IERC165} from "lib/openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";
import {Skill} from "src/Skill.sol";
import {ERC165Checker} from "lib/openzeppelin-contracts/contracts/utils/introspection/ERC165Checker.sol";

/**
 * @title ERC165CheckerDemo
 * @notice Demonstrates the benefits of using OpenZeppelin's ERC165Checker
 */
contract ERC165CheckerDemo is Test {
    using ERC165Checker for address;
    
    SkillWithProperEIP165 public properSkill;
    MalformedEIP165Skill public malformedSkill;
    GasLimitSkill public gasLimitSkill;
    
    function setUp() public {
        properSkill = new SkillWithProperEIP165();
        malformedSkill = new MalformedEIP165Skill();
        gasLimitSkill = new GasLimitSkill();
    }
    
    function test_ERC165CheckerHandlesAllCases() public {
        // Proper implementation
        assertTrue(address(properSkill).supportsInterface(type(ISkill).interfaceId));
        assertTrue(address(properSkill).supportsInterface(type(IERC165).interfaceId));
        
        // Malformed implementation (returns wrong data)
        assertFalse(address(malformedSkill).supportsInterface(type(ISkill).interfaceId));
        
        // Gas limit implementation (runs out of gas)
        assertFalse(address(gasLimitSkill).supportsInterface(type(ISkill).interfaceId));
        
        // EOA (no code)
        assertFalse(address(0x1234).supportsInterface(type(ISkill).interfaceId));
        
        // Zero address
        assertFalse(address(0).supportsInterface(type(ISkill).interfaceId));
    }
    
    function test_SafeAgainstMaliciousContracts() public {
        // Even if the contract tries to be malicious, ERC165Checker handles it safely
        MaliciousEIP165 malicious = new MaliciousEIP165();
        
        // This would revert if called directly, but ERC165Checker handles it
        bool supported = address(malicious).supportsInterface(type(ISkill).interfaceId);
        assertFalse(supported);
    }
}

// Proper implementation
contract SkillWithProperEIP165 is Skill {
    function skillEnergyCost(bytes calldata) external pure returns (uint256) {
        return 50;
    }
}

// Returns wrong data type
contract MalformedEIP165Skill {
    function supportsInterface(bytes4) external pure returns (uint256) {
        return 12345; // Wrong return type!
    }
}

// Consumes too much gas
contract GasLimitSkill {
    function supportsInterface(bytes4) external pure returns (bool) {
        // Infinite loop
        while(true) {}
        return true;
    }
}

// Tries to revert or cause issues
contract MaliciousEIP165 {
    function supportsInterface(bytes4) external pure returns (bool) {
        revert("Ha ha!");
    }
}

contract AminalSkillsERC165CheckerTest is Test {
    Aminal public aminal;
    address public user1 = makeAddr("user1");
    
    // Various skill implementations
    ProperSkillWithERC165Checker public properSkill;
    SkillWithoutEIP165 public legacySkill;
    BrokenEIP165Skill public brokenSkill;
    
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
        
        properSkill = new ProperSkillWithERC165Checker();
        legacySkill = new SkillWithoutEIP165();
        brokenSkill = new BrokenEIP165Skill();
        
        // Fund user
        deal(user1, 10 ether);
    }
    
    function test_HandlesProperImplementation() public {
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 1 ether}("");
        assertTrue(success);
        
        uint256 energyBefore = aminal.energy();
        vm.prank(user1);
        aminal.useSkill(address(properSkill), abi.encodeWithSelector(ProperSkillWithERC165Checker.performAction.selector));
        
        assertEq(energyBefore - aminal.energy(), 75, "Should use interface cost");
    }
    
    function test_HandlesLegacyContracts() public {
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 1 ether}("");
        assertTrue(success);
        
        uint256 energyBefore = aminal.energy();
        vm.prank(user1);
        aminal.useSkill(address(legacySkill), abi.encodeWithSelector(SkillWithoutEIP165.doSomething.selector));
        
        assertEq(energyBefore - aminal.energy(), 100, "Should use legacy parsing");
    }
    
    function test_HandlesBrokenEIP165() public {
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 1 ether}("");
        assertTrue(success);
        
        uint256 energyBefore = aminal.energy();
        vm.prank(user1);
        aminal.useSkill(address(brokenSkill), abi.encodeWithSelector(BrokenEIP165Skill.action.selector));
        
        // Should fall back to legacy parsing (return value 42)
        assertEq(energyBefore - aminal.energy(), 42, "Should fall back to legacy when EIP165 is broken");
    }
    
    function test_GasEfficiencyWithERC165Checker() public {
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 2 ether}("");
        assertTrue(success);
        
        // Test with proper skill
        uint256 gasStart = gasleft();
        vm.prank(user1);
        aminal.useSkill(address(properSkill), abi.encodeWithSelector(ProperSkillWithERC165Checker.performAction.selector));
        uint256 gasWithChecker = gasStart - gasleft();
        
        // Test with legacy
        gasStart = gasleft();
        vm.prank(user1);
        aminal.useSkill(address(legacySkill), abi.encodeWithSelector(SkillWithoutEIP165.doSomething.selector));
        uint256 gasLegacy = gasStart - gasleft();
        
        console.log("Gas with ERC165Checker:", gasWithChecker);
        console.log("Gas with legacy parsing:", gasLegacy);
        console.log("Overhead:", gasWithChecker > gasLegacy ? gasWithChecker - gasLegacy : 0);
    }
}

// Skill implementations for testing
contract ProperSkillWithERC165Checker is Skill {
    function performAction() external pure returns (string memory) {
        return "Action performed!";
    }
    
    function skillEnergyCost(bytes calldata data) external pure returns (uint256) {
        bytes4 selector = bytes4(data);
        if (selector == this.performAction.selector) {
            return 75;
        }
        return 1;
    }
}

contract SkillWithoutEIP165 {
    function doSomething() external pure returns (uint256) {
        return 100; // Energy cost via legacy parsing
    }
}

contract BrokenEIP165Skill {
    function action() external pure returns (uint256) {
        return 42;
    }
    
    // Broken supportsInterface that returns garbage
    function supportsInterface(bytes4) external pure returns (string memory) {
        return "This is not a boolean!";
    }
}