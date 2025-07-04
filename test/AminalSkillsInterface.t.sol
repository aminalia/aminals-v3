// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {Aminal} from "src/Aminal.sol";
import {ITraits} from "src/interfaces/ITraits.sol";
import {ISkill} from "src/interfaces/ISkill.sol";
import {IERC165} from "lib/openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";

// Skill that properly implements ISkill interface with EIP-165
contract ProperSkill is ISkill {
    uint256 public constant SIMPLE_ACTION_COST = 50;
    uint256 public constant COMPLEX_ACTION_COST = 200;
    uint256 public constant DYNAMIC_COST_BASE = 10;
    
    event ActionPerformed(address caller, string action);
    
    function simpleAction() external returns (string memory) {
        emit ActionPerformed(msg.sender, "simple");
        return "Simple action performed";
    }
    
    function complexAction(uint256 iterations) external returns (uint256) {
        emit ActionPerformed(msg.sender, "complex");
        // Do some computation
        uint256 result = 0;
        for (uint i = 0; i < iterations; i++) {
            result += i;
        }
        return result;
    }
    
    function dynamicCostAction(uint256 multiplier) external returns (bool) {
        emit ActionPerformed(msg.sender, "dynamic");
        return true;
    }
    
    // ISkill implementation
    function skillEnergyCost(bytes calldata data) external pure returns (uint256) {
        bytes4 selector = bytes4(data);
        
        if (selector == this.simpleAction.selector) {
            return SIMPLE_ACTION_COST;
        } else if (selector == this.complexAction.selector) {
            return COMPLEX_ACTION_COST;
        } else if (selector == this.dynamicCostAction.selector) {
            // Decode the multiplier parameter
            uint256 multiplier = abi.decode(data[4:], (uint256));
            return DYNAMIC_COST_BASE * multiplier;
        } else {
            // Unknown function, default cost
            return 1;
        }
    }
    
    // EIP-165 implementation
    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == type(ISkill).interfaceId || 
               interfaceId == type(IERC165).interfaceId;
    }
}

// Skill that returns wrong interface support
contract BadInterfaceSkill is ISkill {
    function doSomething() external pure returns (uint256) {
        return 75;
    }
    
    function skillEnergyCost(bytes calldata) external pure returns (uint256) {
        return 100;
    }
    
    // EIP-165 implementation that lies about interface support
    function supportsInterface(bytes4) external pure returns (bool) {
        return false; // Claims not to support ISkill even though it does
    }
}

// Skill that reverts on cost query
contract RevertingCostSkill is ISkill {
    function action() external pure returns (uint256) {
        return 42;
    }
    
    function skillEnergyCost(bytes calldata) external pure returns (uint256) {
        revert("Cost calculation failed");
    }
    
    // EIP-165 implementation
    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == type(ISkill).interfaceId || 
               interfaceId == type(IERC165).interfaceId;
    }
}

// Legacy skill without ISkill interface
contract LegacySkill {
    function oldStyleAction() external pure returns (uint256) {
        return 33; // Cost returned directly
    }
}

contract AminalSkillsInterfaceTest is Test {
    Aminal public aminal;
    ProperSkill public properSkill;
    BadInterfaceSkill public badSkill;
    RevertingCostSkill public revertingSkill;
    LegacySkill public legacySkill;
    
    address public user1 = makeAddr("user1");
    
    event SkillUsed(address indexed user, address indexed target, uint256 energyCost, bytes4 selector);
    
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
        
        properSkill = new ProperSkill();
        badSkill = new BadInterfaceSkill();
        revertingSkill = new RevertingCostSkill();
        legacySkill = new LegacySkill();
        
        // Fund user
        deal(user1, 10 ether);
    }
    
    function test_ProperSkillInterface() public {
        // Feed the Aminal
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 1 ether}("");
        assertTrue(success);
        
        uint256 energyBefore = aminal.energy();
        uint256 loveBefore = aminal.loveFromUser(user1);
        
        // Use simple action skill
        bytes memory skillData = abi.encodeWithSelector(ProperSkill.simpleAction.selector);
        
        vm.prank(user1);
        vm.expectEmit(true, true, false, true);
        emit SkillUsed(user1, address(properSkill), 50, ProperSkill.simpleAction.selector);
        
        aminal.useSkill(address(properSkill), skillData);
        
        // Should consume exact cost from interface
        assertEq(aminal.energy(), energyBefore - 50);
        assertEq(aminal.loveFromUser(user1), loveBefore - 50);
    }
    
    function test_DynamicCostFromInterface() public {
        // Feed the Aminal
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 1 ether}("");
        assertTrue(success);
        
        uint256 energyBefore = aminal.energy();
        
        // Use dynamic cost skill with multiplier 7
        bytes memory skillData = abi.encodeWithSelector(ProperSkill.dynamicCostAction.selector, 7);
        
        vm.prank(user1);
        aminal.useSkill(address(properSkill), skillData);
        
        // Should consume 10 * 7 = 70
        assertEq(aminal.energy(), energyBefore - 70);
    }
    
    function test_ComplexActionCost() public {
        // Feed the Aminal
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 1 ether}("");
        assertTrue(success);
        
        uint256 energyBefore = aminal.energy();
        
        // Use complex action
        bytes memory skillData = abi.encodeWithSelector(ProperSkill.complexAction.selector, 100);
        
        vm.prank(user1);
        aminal.useSkill(address(properSkill), skillData);
        
        // Should consume 200 as defined
        assertEq(aminal.energy(), energyBefore - 200);
    }
    
    function test_BadInterfaceSupportFallsBackToLegacy() public {
        // Feed the Aminal
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 1 ether}("");
        assertTrue(success);
        
        uint256 energyBefore = aminal.energy();
        
        // Use skill that claims not to support ISkill
        bytes memory skillData = abi.encodeWithSelector(BadInterfaceSkill.doSomething.selector);
        
        vm.prank(user1);
        aminal.useSkill(address(badSkill), skillData);
        
        // Should fall back to legacy parsing and use returned value (75)
        assertEq(aminal.energy(), energyBefore - 75);
    }
    
    function test_RevertingCostQueryDefaultsTo1() public {
        // Feed the Aminal
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 1 ether}("");
        assertTrue(success);
        
        uint256 energyBefore = aminal.energy();
        
        // Use skill that reverts on cost query
        bytes memory skillData = abi.encodeWithSelector(RevertingCostSkill.action.selector);
        
        vm.prank(user1);
        aminal.useSkill(address(revertingSkill), skillData);
        
        // Should default to 1 when cost query fails
        assertEq(aminal.energy(), energyBefore - 1);
    }
    
    function test_LegacySkillStillWorks() public {
        // Feed the Aminal
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 1 ether}("");
        assertTrue(success);
        
        uint256 energyBefore = aminal.energy();
        
        // Use legacy skill
        bytes memory skillData = abi.encodeWithSelector(LegacySkill.oldStyleAction.selector);
        
        vm.prank(user1);
        aminal.useSkill(address(legacySkill), skillData);
        
        // Should use legacy parsing (33)
        assertEq(aminal.energy(), energyBefore - 33);
    }
    
    function test_UnknownFunctionOnProperSkill() public {
        // Feed the Aminal
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 1 ether}("");
        assertTrue(success);
        
        uint256 energyBefore = aminal.energy();
        
        // Use unknown function selector
        bytes memory skillData = abi.encodeWithSelector(bytes4(0x12345678));
        
        vm.prank(user1);
        aminal.useSkill(address(properSkill), skillData);
        
        // ProperSkill returns 1 for unknown functions
        assertEq(aminal.energy(), energyBefore - 1);
    }
    
    function test_InterfaceGasEfficiency() public {
        // Feed the Aminal
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 10 ether}("");
        assertTrue(success);
        
        // Measure gas for interface-based skill
        bytes memory skillData = abi.encodeWithSelector(ProperSkill.simpleAction.selector);
        
        vm.prank(user1);
        uint256 gasStart = gasleft();
        aminal.useSkill(address(properSkill), skillData);
        uint256 gasUsedInterface = gasStart - gasleft();
        
        // Measure gas for legacy skill
        skillData = abi.encodeWithSelector(LegacySkill.oldStyleAction.selector);
        
        vm.prank(user1);
        gasStart = gasleft();
        aminal.useSkill(address(legacySkill), skillData);
        uint256 gasUsedLegacy = gasStart - gasleft();
        
        console.log("Gas used with interface:", gasUsedInterface);
        console.log("Gas used with legacy:", gasUsedLegacy);
        
        // Interface might use more gas due to extra calls, but provides better safety
    }
    
    function testFuzz_DynamicCostCalculation(uint8 multiplier) public {
        // Feed the Aminal with enough energy
        vm.deal(user1, 100 ether);
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 10 ether}("");
        assertTrue(success);
        
        uint256 energyBefore = aminal.energy();
        uint256 expectedCost = uint256(multiplier) * 10; // DYNAMIC_COST_BASE
        
        // Cap at 10000
        if (expectedCost > 10000) {
            expectedCost = 10000;
        }
        if (expectedCost == 0) {
            expectedCost = 1;
        }
        
        // Use dynamic cost skill
        bytes memory skillData = abi.encodeWithSelector(ProperSkill.dynamicCostAction.selector, uint256(multiplier));
        
        vm.prank(user1);
        aminal.useSkill(address(properSkill), skillData);
        
        // Verify cost calculation
        assertEq(aminal.energy(), energyBefore - expectedCost);
    }
}