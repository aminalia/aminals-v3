// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {Aminal} from "src/Aminal.sol";
import {ITraits} from "src/interfaces/ITraits.sol";
import {ISkill} from "src/interfaces/ISkill.sol";
import {IERC165} from "lib/openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";

/**
 * @title SimpleSkillWithInterface
 * @notice Simple demonstration of ISkill interface benefits
 */
contract SimpleSkillWithInterface is ISkill {
    mapping(bytes4 => uint256) public functionCosts;
    
    event ActionExecuted(string action);
    
    constructor() {
        // Set up costs for each function
        functionCosts[this.dance.selector] = 10;
        functionCosts[this.sing.selector] = 20;
        functionCosts[this.paint.selector] = 30;
        functionCosts[this.complexAction.selector] = 0; // Dynamic cost
    }
    
    function dance() external {
        emit ActionExecuted("Dancing!");
    }
    
    function sing() external {
        emit ActionExecuted("Singing!");
    }
    
    function paint() external {
        emit ActionExecuted("Painting!");
    }
    
    function complexAction(uint256 complexity) external {
        emit ActionExecuted("Complex action executed");
    }
    
    // ISkill implementation
    function skillEnergyCost(bytes calldata data) external view returns (uint256) {
        bytes4 selector = bytes4(data);
        
        // Special handling for complex action
        if (selector == this.complexAction.selector) {
            uint256 complexity = abi.decode(data[4:], (uint256));
            return complexity * 5; // Cost scales with complexity
        }
        
        // Return predefined cost or default to 1
        uint256 cost = functionCosts[selector];
        return cost == 0 ? 1 : cost;
    }
    
    // EIP-165 implementation
    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == type(ISkill).interfaceId || 
               interfaceId == type(IERC165).interfaceId;
    }
}

contract AminalSkillsInterfaceSimpleTest is Test {
    Aminal public aminal;
    SimpleSkillWithInterface public skillContract;
    
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
        
        skillContract = new SimpleSkillWithInterface();
        
        // Fund user
        deal(user1, 10 ether);
    }
    
    function test_PredefinedCosts() public {
        // Feed the Aminal
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 1 ether}("");
        assertTrue(success);
        
        uint256 energyBefore;
        
        // Test dance (10 cost)
        energyBefore = aminal.energy();
        vm.prank(user1);
        aminal.useSkill(address(skillContract), abi.encodeWithSelector(SimpleSkillWithInterface.dance.selector));
        assertEq(energyBefore - aminal.energy(), 10, "Dance should cost 10");
        
        // Test sing (20 cost)
        energyBefore = aminal.energy();
        vm.prank(user1);
        aminal.useSkill(address(skillContract), abi.encodeWithSelector(SimpleSkillWithInterface.sing.selector));
        assertEq(energyBefore - aminal.energy(), 20, "Sing should cost 20");
        
        // Test paint (30 cost)
        energyBefore = aminal.energy();
        vm.prank(user1);
        aminal.useSkill(address(skillContract), abi.encodeWithSelector(SimpleSkillWithInterface.paint.selector));
        assertEq(energyBefore - aminal.energy(), 30, "Paint should cost 30");
    }
    
    function test_DynamicCostBasedOnParameters() public {
        // Feed the Aminal
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 1 ether}("");
        assertTrue(success);
        
        // Test with complexity 10 (should cost 50)
        uint256 energyBefore = aminal.energy();
        vm.prank(user1);
        aminal.useSkill(
            address(skillContract), 
            abi.encodeWithSelector(SimpleSkillWithInterface.complexAction.selector, 10)
        );
        assertEq(energyBefore - aminal.energy(), 50, "Complexity 10 should cost 50");
        
        // Test with complexity 3 (should cost 15)
        energyBefore = aminal.energy();
        vm.prank(user1);
        aminal.useSkill(
            address(skillContract), 
            abi.encodeWithSelector(SimpleSkillWithInterface.complexAction.selector, 3)
        );
        assertEq(energyBefore - aminal.energy(), 15, "Complexity 3 should cost 15");
    }
    
    function test_UnknownFunctionDefaultCost() public {
        // Feed the Aminal
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 1 ether}("");
        assertTrue(success);
        
        // Call with unknown selector
        uint256 energyBefore = aminal.energy();
        vm.prank(user1);
        aminal.useSkill(
            address(skillContract), 
            abi.encodeWithSelector(bytes4(keccak256("unknownFunction()")))
        );
        assertEq(energyBefore - aminal.energy(), 1, "Unknown function should default to 1");
    }
    
    function test_InterfacePreventsMaliciousCosts() public {
        // Create a skill that tries to return unreasonable costs
        MaliciousSkill malicious = new MaliciousSkill();
        
        // Feed the Aminal
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 1 ether}("");
        assertTrue(success);
        
        uint256 energyBefore = aminal.energy();
        
        // Even though the skill returns a huge number, it's capped at 10000
        vm.prank(user1);
        aminal.useSkill(
            address(malicious), 
            abi.encodeWithSelector(MaliciousSkill.drainAllEnergy.selector)
        );
        
        // Should be capped at 10000
        uint256 consumed = energyBefore - aminal.energy();
        assertEq(consumed, aminal.energy() == 0 ? energyBefore : 10000, "Cost should be capped");
    }
}

// Malicious skill that tries to drain all energy
contract MaliciousSkill is ISkill {
    function drainAllEnergy() external pure returns (bool) {
        return true;
    }
    
    function skillEnergyCost(bytes calldata) external pure returns (uint256) {
        return type(uint256).max; // Try to drain everything!
    }
    
    // EIP-165 implementation
    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == type(ISkill).interfaceId || 
               interfaceId == type(IERC165).interfaceId;
    }
}