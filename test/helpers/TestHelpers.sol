// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {IGenes} from "src/interfaces/IGenes.sol";

/**
 * @title TestHelpers
 * @notice Common test utilities and data fixtures
 */
library TestHelpers {
    // Common trait combinations for testing
    function dragonTraits() internal pure returns (IGenes.Genes memory) {
        return IGenes.Genes({
            back: "Dragon Wings",
            arm: "Strong Arms",
            tail: "Fire Tail",
            ears: "Pointed Ears",
            body: "Scaled Body",
            face: "Fierce Face",
            mouth: "Sharp Teeth",
            misc: "Glowing Eyes"
        });
    }
    
    function bunnyTraits() internal pure returns (IGenes.Genes memory) {
        return IGenes.Genes({
            back: "Angel Wings",
            arm: "Gentle Arms",
            tail: "Fluffy Tail",
            ears: "Round Ears",
            body: "Soft Body",
            face: "Kind Face",
            mouth: "Sweet Smile",
            misc: "Sparkles"
        });
    }
    
    function butterflyTraits() internal pure returns (IGenes.Genes memory) {
        return IGenes.Genes({
            back: "Butterfly Wings",
            arm: "Delicate Arms",
            tail: "Ribbon Tail",
            ears: "Fairy Ears",
            body: "Ethereal Body",
            face: "Mystical Face",
            mouth: "Gentle Smile",
            misc: "Stardust"
        });
    }
    
    // Common test amounts
    uint256 constant SMALL_FEED = 0.01 ether;
    uint256 constant MEDIUM_FEED = 0.1 ether;
    uint256 constant LARGE_FEED = 1 ether;
    
    // Phase durations
    uint256 constant GENE_PROPOSAL_DURATION = 3 days;
    uint256 constant VOTING_DURATION = 4 days;
    
    // Energy/Love constants
    uint256 constant ENERGY_PER_ETH = 10000;
    uint256 constant MAX_LOVE_MULTIPLIER = 10;
    uint256 constant MIN_LOVE_MULTIPLIER = 0.1 ether; // Using ether as decimal representation
}

/**
 * @title TestAssertions
 * @notice Custom assertions for better test readability
 */
abstract contract TestAssertions is Test {
    function assertGenes(IGenes.Genes memory actual, IGenes.Genes memory expected, string memory message) internal {
        assertEq(actual.back, expected.back, string.concat(message, ": back mismatch"));
        assertEq(actual.arm, expected.arm, string.concat(message, ": arm mismatch"));
        assertEq(actual.tail, expected.tail, string.concat(message, ": tail mismatch"));
        assertEq(actual.ears, expected.ears, string.concat(message, ": ears mismatch"));
        assertEq(actual.body, expected.body, string.concat(message, ": body mismatch"));
        assertEq(actual.face, expected.face, string.concat(message, ": face mismatch"));
        assertEq(actual.mouth, expected.mouth, string.concat(message, ": mouth mismatch"));
        assertEq(actual.misc, expected.misc, string.concat(message, ": misc mismatch"));
    }
    
    function assertLoveInRange(uint256 actual, uint256 min, uint256 max, string memory message) internal {
        assertGe(actual, min, string.concat(message, ": love too low"));
        assertLe(actual, max, string.concat(message, ": love too high"));
    }
    
    function assertEnergyConsumed(uint256 before, uint256 after, uint256 expected, string memory message) internal {
        assertEq(before - after, expected, message);
    }
}