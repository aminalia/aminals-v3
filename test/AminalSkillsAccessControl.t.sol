// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Aminal} from "src/Aminal.sol";
import {ITraits} from "src/interfaces/ITraits.sol";
import {ISkill} from "src/interfaces/ISkill.sol";
import {Skill} from "src/Skill.sol";

/**
 * @title AminalSkillsAccessControlTest
 * @notice Tests access control patterns for skills
 * @dev Note: Some tests demonstrate using msg.sender (the Aminal) for access control,
 *      while others show patterns that would work with tx.origin (not recommended).
 *      In production, skills should avoid tx.origin and instead encode user info in calldata
 *      or use msg.sender (the Aminal) for access control.
 */
contract AminalSkillsAccessControlTest is Test {
    Aminal public aminal;
    address public owner = makeAddr("owner");
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");
    address public malicious = makeAddr("malicious");
    
    RestrictedSkill public restrictedSkill;
    
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
        
        // Deploy skills with owner
        vm.prank(owner);
        restrictedSkill = new RestrictedSkill();
        
        // Fund users
        deal(user1, 10 ether);
        deal(user2, 10 ether);
        deal(malicious, 10 ether);
    }
    
    function test_SkillCanRestrictBasedOnAminalCaller() public {
        // User feeds the Aminal
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 1 ether}("");
        assertTrue(success);
        
        // Add this specific Aminal to allowed list
        vm.prank(owner);
        restrictedSkill.allowAminal(address(aminal));
        
        // Should work for allowed Aminal
        vm.prank(user1);
        aminal.useSkill(address(restrictedSkill), abi.encodeWithSelector(RestrictedSkill.onlyAllowedAminals.selector));
        
        // Create another Aminal
        ITraits.Traits memory traits2 = ITraits.Traits({
            back: "scales",
            arm: "fins", 
            tail: "long",
            ears: "none",
            body: "smooth",
            face: "happy",
            mouth: "big",
            misc: "glitter"
        });
        
        Aminal aminal2 = new Aminal("TestAminal2", "TAMINAL2", "https://test2.com/", traits2);
        aminal2.initialize("test-uri-2");
        
        // Fund and try to use skill from non-allowed Aminal
        vm.prank(user1);
        (bool success2,) = address(aminal2).call{value: 1 ether}("");
        assertTrue(success2);
        
        vm.prank(user1);
        vm.expectRevert(Aminal.SkillCallFailed.selector);
        aminal2.useSkill(address(restrictedSkill), abi.encodeWithSelector(RestrictedSkill.onlyAllowedAminals.selector));
    }
    
    function test_SkillCanImplementCustomAccessControl() public {
        // Deploy a skill that uses encoded user data for access control
        vm.prank(owner);
        UserDataSkill userDataSkill = new UserDataSkill();
        
        // User feeds the Aminal
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 1 ether}("");
        assertTrue(success);
        
        // Add user1 to allowed list
        vm.prank(owner);
        userDataSkill.allowUser(user1);
        
        // User1 can call with their address encoded
        vm.prank(user1);
        aminal.useSkill(
            address(userDataSkill), 
            abi.encodeWithSelector(UserDataSkill.restrictedAction.selector, user1)
        );
        
        // User1 cannot call with user2's address (impersonation attempt)
        vm.prank(user1);
        vm.expectRevert(Aminal.SkillCallFailed.selector);
        aminal.useSkill(
            address(userDataSkill), 
            abi.encodeWithSelector(UserDataSkill.restrictedAction.selector, user2)
        );
        
        // User2 cannot call even with their own address (not allowed)
        vm.prank(user2);
        (bool success2,) = address(aminal).call{value: 1 ether}("");
        assertTrue(success2);
        
        vm.prank(user2);
        vm.expectRevert(Aminal.SkillCallFailed.selector);
        aminal.useSkill(
            address(userDataSkill), 
            abi.encodeWithSelector(UserDataSkill.restrictedAction.selector, user2)
        );
    }
}

// Skill contracts with various access control mechanisms
contract RestrictedSkill is Skill {
    mapping(address => bool) public allowedAminals;
    address public owner;
    
    constructor() {
        owner = msg.sender;
    }
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }
    
    function allowAminal(address aminal) external onlyOwner {
        allowedAminals[aminal] = true;
    }
    
    function onlyAllowedAminals() external view {
        require(allowedAminals[msg.sender], "Aminal not allowed");
    }
    
    function skillEnergyCost(bytes calldata) external pure returns (uint256) {
        return 25;
    }
}

// Skill that uses encoded user data for access control (recommended pattern)
contract UserDataSkill is Skill {
    mapping(address => bool) public allowedUsers;
    address public owner;
    
    constructor() {
        owner = msg.sender;
    }
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }
    
    function allowUser(address user) external onlyOwner {
        allowedUsers[user] = true;
    }
    
    function restrictedAction(address callingUser) external view {
        require(allowedUsers[callingUser], "User not allowed");
        // In production, you might also verify this matches some signature
        // or other proof that the user authorized this call
    }
    
    function skillEnergyCost(bytes calldata) external pure returns (uint256) {
        return 30;
    }
}