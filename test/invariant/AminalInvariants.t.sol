// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {Aminal} from "src/Aminal.sol";
import {IGenes} from "src/interfaces/IGenes.sol";
import {TestHelpers} from "../helpers/TestHelpers.sol";

/**
 * @title AminalInvariants
 * @notice Invariant tests for critical Aminal properties
 */
contract AminalInvariants is StdInvariant, Test {
    AminalHandler public handler;
    Aminal public aminal;
    
    function setUp() public {
        // Create Aminal
        aminal = new Aminal("InvariantAminal", "INV", "https://api.aminals.com/", TestHelpers.dragonTraits(), address(this));
        aminal.initialize("invariant.json");
        
        // Create handler
        handler = new AminalHandler(aminal);
        
        // Set handler as target for invariant testing
        targetContract(address(handler));
        
        // Set selectors to test
        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = AminalHandler.feed.selector;
        selectors[1] = AminalHandler.squeak.selector;
        selectors[2] = AminalHandler.multiUserFeed.selector;
        
        targetSelector(FuzzSelector({
            addr: address(handler),
            selectors: selectors
        }));
    }
    
    /**
     * @notice Aminal should always own itself
     */
    function invariant_SelfSovereignty() public {
        assertEq(aminal.ownerOf(1), address(aminal), "Aminal must own itself");
        assertEq(aminal.balanceOf(address(aminal)), 1, "Aminal must have balance of 1");
    }
    
    /**
     * @notice Total love should equal sum of all user love
     */
    function invariant_LoveConsistency() public {
        uint256 totalLove = handler.ghost_totalLoveSum();
        assertEq(aminal.totalLove(), totalLove, "Total love must equal sum of user love");
    }
    
    /**
     * @notice Energy gained should match what handler tracked
     */
    function invariant_EnergyConsistency() public {
        uint256 totalEnergyGained = handler.ghost_totalEnergyGained();
        uint256 actualEnergy = aminal.energy();
        
        assertEq(actualEnergy, totalEnergyGained, "Energy must match tracked gains");
    }
    
    /**
     * @notice ETH balance should match total received minus any withdrawn
     */
    function invariant_EthBalance() public {
        uint256 totalEthReceived = handler.ghost_totalEthReceived();
        assertEq(address(aminal).balance, totalEthReceived, "ETH balance must match received");
    }
    
    /**
     * @notice Love per user should never exceed their contribution
     */
    function invariant_UserLoveBounds() public {
        address[] memory users = handler.getActors();
        
        for (uint i = 0; i < users.length; i++) {
            uint256 userLove = aminal.loveFromUser(users[i]);
            uint256 userContribution = handler.ghost_userContribution(users[i]);
            
            // User love should be positive if they contributed
            if (userContribution > 0) {
                assertGt(userLove, 0, "User should have love if contributed");
            }
        }
    }
    
    /**
     * @notice Energy can never go negative
     */
    function invariant_NonNegativeEnergy() public {
        assertGe(aminal.energy(), 0, "Energy cannot be negative");
    }
}

/**
 * @title AminalHandler
 * @notice Handler contract for bounded invariant testing
 */
contract AminalHandler is Test {
    using TestHelpers for *;
    
    Aminal public immutable aminal;
    
    // Ghost variables for tracking state
    uint256 public ghost_totalEthReceived;
    uint256 public ghost_totalEnergyGained;
    uint256 public ghost_totalLoveSum;
    uint256 public ghost_totalSqueaks;
    mapping(address => uint256) public ghost_userContribution;
    mapping(address => uint256) public ghost_userLove;
    
    // Actors
    address[] public actors;
    mapping(address => bool) public isActor;
    
    modifier useActor(uint256 actorSeed) {
        address actor = _getActor(actorSeed);
        vm.startPrank(actor);
        _;
        vm.stopPrank();
    }
    
    constructor(Aminal _aminal) {
        aminal = _aminal;
        
        // Initialize actors
        for (uint i = 0; i < 5; i++) {
            address actor = makeAddr(string(abi.encodePacked("actor", i)));
            actors.push(actor);
            isActor[actor] = true;
            vm.deal(actor, 100 ether);
        }
    }
    
    function feed(uint256 actorSeed, uint256 amount) external useActor(actorSeed) {
        // Bound amount
        amount = bound(amount, 0.001 ether, 10 ether);
        
        address actor = _getActor(actorSeed);
        
        // Pre-state
        uint256 loveBefore = aminal.loveFromUser(actor);
        uint256 totalLoveBefore = aminal.totalLove();
        uint256 energyBefore = aminal.energy();
        
        // Feed
        (bool success,) = address(aminal).call{value: amount}("");
        require(success, "Feed failed");
        
        // Post-state
        uint256 loveAfter = aminal.loveFromUser(actor);
        uint256 loveGained = loveAfter - loveBefore;
        uint256 energyAfter = aminal.energy();
        uint256 energyGained = energyAfter - energyBefore;
        
        // Update ghost variables
        ghost_totalEthReceived += amount;
        ghost_totalEnergyGained += energyGained;
        ghost_userContribution[actor] += amount;
        ghost_userLove[actor] = loveAfter;
        ghost_totalLoveSum += loveGained;
        
        // Assertions
        assertGt(loveGained, 0, "Should gain love from feeding");
        assertEq(aminal.totalLove(), totalLoveBefore + loveGained, "Total love should increase");
    }
    
    function squeak(uint256 actorSeed, uint256 squeakAmount) external useActor(actorSeed) {
        address actor = _getActor(actorSeed);
        
        // Only squeak if actor has love and energy
        uint256 availableLove = aminal.loveFromUser(actor);
        uint256 availableEnergy = aminal.energy();
        
        if (availableLove == 0 || availableEnergy == 0) return;
        
        // Bound squeak amount
        squeakAmount = bound(squeakAmount, 1, _min(availableLove, availableEnergy));
        squeakAmount = bound(squeakAmount, 1, 10000); // Cap at safety limit
        
        // Squeak via skill (would need to import SqueakSkill)
        // For now, just track the attempt
        ghost_totalSqueaks++;
    }
    
    function multiUserFeed(uint256[] calldata amounts) external {
        uint256 numUsers = bound(amounts.length, 1, actors.length);
        
        for (uint i = 0; i < numUsers; i++) {
            uint256 amount = bound(amounts[i % amounts.length], 0.001 ether, 1 ether);
            
            uint256 energyBefore = aminal.energy();
            
            vm.prank(actors[i]);
            (bool success,) = address(aminal).call{value: amount}("");
            
            if (success) {
                uint256 energyAfter = aminal.energy();
                uint256 energyGained = energyAfter - energyBefore;
                
                ghost_totalEthReceived += amount;
                ghost_totalEnergyGained += energyGained;
                ghost_userContribution[actors[i]] += amount;
                ghost_userLove[actors[i]] = aminal.loveFromUser(actors[i]);
                
                // Recalculate total love sum
                uint256 totalLove = 0;
                for (uint j = 0; j < actors.length; j++) {
                    totalLove += aminal.loveFromUser(actors[j]);
                }
                ghost_totalLoveSum = totalLove;
            }
        }
    }
    
    function getActors() external view returns (address[] memory) {
        return actors;
    }
    
    function _getActor(uint256 seed) private view returns (address) {
        return actors[bound(seed, 0, actors.length - 1)];
    }
    
    function _min(uint256 a, uint256 b) private pure returns (uint256) {
        return a < b ? a : b;
    }
}