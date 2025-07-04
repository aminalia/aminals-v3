// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {Aminal} from "src/Aminal.sol";
import {ITraits} from "src/interfaces/ITraits.sol";
import {ISkill} from "src/interfaces/ISkill.sol";
import {IERC165} from "lib/openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";

/**
 * @title AdvancedSkill
 * @notice Demonstrates advanced use cases for the ISkill interface
 */
contract AdvancedSkill is ISkill {
    mapping(address => uint256) public userDiscounts;
    mapping(bytes4 => uint256) public baseCosts;
    mapping(address => mapping(bytes4 => uint256)) public usageCount;
    
    uint256 public constant DEFAULT_COST = 25;
    
    event SkillExecuted(address user, bytes4 selector, uint256 finalCost);
    
    constructor() {
        // Set up base costs for different functions
        baseCosts[this.trainStrength.selector] = 100;
        baseCosts[this.learnMagic.selector] = 200;
        baseCosts[this.craftItem.selector] = 50;
    }
    
    // Skills with different complexities
    function trainStrength() external returns (string memory) {
        usageCount[msg.sender][this.trainStrength.selector]++;
        emit SkillExecuted(msg.sender, this.trainStrength.selector, _calculateCost(msg.sender, this.trainStrength.selector));
        return "Strength increased!";
    }
    
    function learnMagic(string memory spellName) external returns (bool) {
        usageCount[msg.sender][this.learnMagic.selector]++;
        emit SkillExecuted(msg.sender, this.learnMagic.selector, _calculateCost(msg.sender, this.learnMagic.selector));
        return true;
    }
    
    function craftItem(uint256 itemId, uint256 quantity) external returns (uint256) {
        usageCount[msg.sender][this.craftItem.selector]++;
        uint256 cost = _calculateCost(msg.sender, this.craftItem.selector) * quantity;
        emit SkillExecuted(msg.sender, this.craftItem.selector, cost);
        return itemId * 1000 + quantity; // Return crafted item ID
    }
    
    // Admin functions
    function setUserDiscount(address user, uint256 discountPercent) external {
        require(discountPercent <= 90, "Discount too high");
        userDiscounts[user] = discountPercent;
    }
    
    function setBaseCost(bytes4 selector, uint256 cost) external {
        baseCosts[selector] = cost;
    }
    
    // ISkill implementation
    function skillEnergyCost(bytes calldata data) external view returns (uint256) {
        bytes4 selector = bytes4(data);
        
        // Get the actual user from the Aminal contract (msg.sender is the Aminal)
        address user = tx.origin; // In a real implementation, you'd want a better way to identify the user
        
        // For craftItem, parse quantity to calculate total cost
        if (selector == this.craftItem.selector) {
            (, uint256 quantity) = abi.decode(data[4:], (uint256, uint256));
            return _calculateCost(user, selector) * quantity;
        }
        
        return _calculateCost(user, selector);
    }
    
    // EIP-165 implementation
    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == type(ISkill).interfaceId || 
               interfaceId == type(IERC165).interfaceId;
    }
    
    // Internal cost calculation with discounts and usage-based pricing
    function _calculateCost(address user, bytes4 selector) internal view returns (uint256) {
        uint256 baseCost = baseCosts[selector];
        if (baseCost == 0) {
            baseCost = DEFAULT_COST;
        }
        
        // Apply user discount
        uint256 discount = userDiscounts[user];
        if (discount > 0) {
            baseCost = baseCost * (100 - discount) / 100;
        }
        
        // Apply usage-based discount (bulk discount)
        uint256 uses = usageCount[user][selector];
        if (uses >= 10) {
            baseCost = baseCost * 80 / 100; // 20% off after 10 uses
        } else if (uses >= 5) {
            baseCost = baseCost * 90 / 100; // 10% off after 5 uses
        }
        
        // Minimum cost of 1
        return baseCost == 0 ? 1 : baseCost;
    }
}

/**
 * @title ConditionalSkill
 * @notice Skill that has different costs based on Aminal's state
 */
contract ConditionalSkill is ISkill {
    function healAminal() external view returns (string memory) {
        uint256 currentEnergy = Aminal(payable(msg.sender)).energy();
        
        if (currentEnergy < 100) {
            return "Healed to full health!";
        } else {
            return "Already healthy!";
        }
    }
    
    function powerBoost() external pure returns (uint256) {
        return 9999; // Massive power boost
    }
    
    // ISkill implementation
    function skillEnergyCost(bytes calldata data) external view returns (uint256) {
        bytes4 selector = bytes4(data);
        
        if (selector == this.healAminal.selector) {
            // Healing is cheaper when Aminal has low energy
            uint256 currentEnergy = Aminal(payable(tx.origin)).energy();
            if (currentEnergy < 100) {
                return 10; // Cheap healing for weak Aminals
            } else {
                return 100; // Expensive for healthy Aminals
            }
        } else if (selector == this.powerBoost.selector) {
            // Power boost cost scales with current energy
            uint256 currentEnergy = Aminal(payable(tx.origin)).energy();
            return currentEnergy / 10 + 50; // More expensive for stronger Aminals
        }
        
        return 1;
    }
    
    // EIP-165 implementation
    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == type(ISkill).interfaceId || 
               interfaceId == type(IERC165).interfaceId;
    }
}

contract AminalSkillsInterfaceAdvancedTest is Test {
    Aminal public aminal;
    AdvancedSkill public advancedSkill;
    ConditionalSkill public conditionalSkill;
    
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");
    
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
        
        advancedSkill = new AdvancedSkill();
        conditionalSkill = new ConditionalSkill();
        
        // Fund users
        deal(user1, 10 ether);
        deal(user2, 10 ether);
    }
    
    function test_UserDiscounts() public {
        // Set discount for user1
        advancedSkill.setUserDiscount(user1, 50); // 50% off
        
        // Feed Aminals for both users
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 1 ether}("");
        assertTrue(success);
        
        vm.prank(user2);
        (success,) = address(aminal).call{value: 1 ether}("");
        assertTrue(success);
        
        // User1 trains with discount
        uint256 energy1Before = aminal.energy();
        bytes memory skillData = abi.encodeWithSelector(AdvancedSkill.trainStrength.selector);
        
        vm.prank(user1);
        aminal.useSkill(address(advancedSkill), skillData);
        
        // Should pay 50 (50% off from 100)
        assertEq(energy1Before - aminal.energy(), 50);
        
        // User2 trains without discount
        uint256 energy2Before = aminal.energy();
        
        vm.prank(user2);
        aminal.useSkill(address(advancedSkill), skillData);
        
        // Should pay full 100
        assertEq(energy2Before - aminal.energy(), 100);
    }
    
    function test_UsageBasedDiscounts() public {
        // Feed the Aminal
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 5 ether}("");
        assertTrue(success);
        
        bytes memory skillData = abi.encodeWithSelector(AdvancedSkill.craftItem.selector, 1, 1);
        
        // First 5 uses at full price (50 each)
        for (uint i = 0; i < 5; i++) {
            uint256 energyBeforeUse = aminal.energy();
            vm.prank(user1);
            aminal.useSkill(address(advancedSkill), skillData);
            assertEq(energyBeforeUse - aminal.energy(), 50, "First 5 uses should be full price");
        }
        
        // Next 5 uses at 10% discount (45 each)
        for (uint i = 0; i < 5; i++) {
            uint256 energyBeforeUse = aminal.energy();
            vm.prank(user1);
            aminal.useSkill(address(advancedSkill), skillData);
            assertEq(energyBeforeUse - aminal.energy(), 45, "Uses 6-10 should have 10% discount");
        }
        
        // After 10 uses, 20% discount (40 each)
        uint256 energyBefore = aminal.energy();
        vm.prank(user1);
        aminal.useSkill(address(advancedSkill), skillData);
        assertEq(energyBefore - aminal.energy(), 40, "After 10 uses should have 20% discount");
    }
    
    function test_QuantityBasedCost() public {
        // Feed the Aminal
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 1 ether}("");
        assertTrue(success);
        
        // Craft 3 items
        bytes memory skillData = abi.encodeWithSelector(AdvancedSkill.craftItem.selector, 42, 3);
        
        uint256 energyBefore = aminal.energy();
        vm.prank(user1);
        aminal.useSkill(address(advancedSkill), skillData);
        
        // Should cost 50 * 3 = 150
        assertEq(energyBefore - aminal.energy(), 150);
    }
    
    function test_ConditionalCostBasedOnAminalState() public {
        // Test healing when low energy
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 0.005 ether}(""); // Get 50 energy
        assertTrue(success);
        
        bytes memory healData = abi.encodeWithSelector(ConditionalSkill.healAminal.selector);
        
        uint256 energyBefore = aminal.energy();
        vm.prank(user1);
        aminal.useSkill(address(conditionalSkill), healData);
        
        // Should cost only 10 when energy < 100
        assertEq(energyBefore - aminal.energy(), 10);
        
        // Feed more to get above 100 energy
        vm.prank(user1);
        (success,) = address(aminal).call{value: 1 ether}("");
        assertTrue(success);
        
        energyBefore = aminal.energy();
        vm.prank(user1);
        aminal.useSkill(address(conditionalSkill), healData);
        
        // Should cost 100 when energy >= 100
        assertEq(energyBefore - aminal.energy(), 100);
    }
    
    function test_PowerBoostScalingCost() public {
        // Test with different energy levels
        bytes memory boostData = abi.encodeWithSelector(ConditionalSkill.powerBoost.selector);
        
        // Low energy test
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 0.01 ether}(""); // 100 energy
        assertTrue(success);
        
        uint256 energyBefore = aminal.energy();
        uint256 expectedCost = energyBefore / 10 + 50; // Should be 10 + 50 = 60
        
        vm.prank(user1);
        aminal.useSkill(address(conditionalSkill), boostData);
        
        assertEq(energyBefore - aminal.energy(), expectedCost);
        
        // High energy test
        vm.prank(user1);
        (success,) = address(aminal).call{value: 1 ether}(""); // +10000 energy
        assertTrue(success);
        
        energyBefore = aminal.energy();
        expectedCost = energyBefore / 10 + 50;
        
        // Cap check
        if (expectedCost > 10000) {
            expectedCost = aminal.energy() > 10000 ? 10000 : aminal.energy();
        }
        
        vm.prank(user1);
        aminal.useSkill(address(conditionalSkill), boostData);
        
        assertEq(energyBefore - aminal.energy(), expectedCost);
    }
    
    function test_CombinedDiscounts() public {
        // Set user discount AND use enough times for usage discount
        advancedSkill.setUserDiscount(user1, 30); // 30% off
        
        // Feed the Aminal
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 2 ether}("");
        assertTrue(success);
        
        bytes memory skillData = abi.encodeWithSelector(AdvancedSkill.trainStrength.selector);
        
        // Use 10 times to get usage discount
        for (uint i = 0; i < 10; i++) {
            vm.prank(user1);
            aminal.useSkill(address(advancedSkill), skillData);
        }
        
        // 11th use should have both discounts
        // Base: 100
        // User discount: 100 * 0.7 = 70
        // Usage discount: 70 * 0.8 = 56
        uint256 energyBefore = aminal.energy();
        vm.prank(user1);
        aminal.useSkill(address(advancedSkill), skillData);
        
        assertEq(energyBefore - aminal.energy(), 56);
    }
}