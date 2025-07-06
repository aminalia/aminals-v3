// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {Aminal} from "src/Aminal.sol";
import {IGenes} from "src/interfaces/IGenes.sol";
import {TestHelpers} from "../helpers/TestHelpers.sol";
import {TestAssertions} from "../helpers/TestHelpers.sol";

/**
 * @title AminalTestBase
 * @notice Base contract for Aminal-specific tests (non-breeding)
 */
abstract contract AminalTestBase is Test, TestAssertions {
    using TestHelpers for *;
    
    // Standard test Aminal
    Aminal public aminal;
    
    // Common test users
    address public user1;
    address public user2;
    address public user3;
    
    // Constants
    string constant BASE_URI = "https://api.aminals.com/metadata/";
    string constant DEFAULT_NAME = "TestAminal";
    string constant DEFAULT_SYMBOL = "TEST";
    
    function setUp() public virtual {
        // Setup users
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");
        
        // Fund users
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
        vm.deal(user3, 10 ether);
        
        // Create default Aminal
        aminal = _createDefaultAminal();
    }
    
    function _createDefaultAminal() internal returns (Aminal) {
        return _createAminal(DEFAULT_NAME, DEFAULT_SYMBOL, TestHelpers.dragonTraits());
    }
    
    function _createAminal(
        string memory name,
        string memory symbol,
        IGenes.Genes memory traits
    ) internal returns (Aminal) {
        return new Aminal(name, symbol, BASE_URI, traits);
    }
    
    function _initializeAminal(Aminal targetAminal, string memory tokenURI) internal returns (uint256) {
        return targetAminal.initialize(tokenURI);
    }
    
    function _feedAminal(address user, Aminal targetAminal, uint256 amount) internal {
        vm.prank(user);
        (bool success,) = address(targetAminal).call{value: amount}("");
        assertTrue(success, "Failed to feed Aminal");
    }
    
    function _getLoveAndEnergy(address user, Aminal targetAminal) 
        internal 
        view 
        returns (uint256 love, uint256 energy) 
    {
        love = targetAminal.loveFromUser(user);
        energy = targetAminal.getEnergy();
    }
    
    function _assertLoveAndEnergy(
        Aminal targetAminal,
        address user,
        uint256 expectedLove,
        uint256 expectedEnergy,
        string memory message
    ) internal {
        assertEq(targetAminal.loveFromUser(user), expectedLove, string.concat(message, ": love mismatch"));
        assertEq(targetAminal.getEnergy(), expectedEnergy, string.concat(message, ": energy mismatch"));
    }
    
    function _calculateExpectedLove(uint256 ethAmount, uint256 currentEnergy) 
        internal 
        view 
        returns (uint256) 
    {
        // This would use the VRGDA calculation
        // Simplified for example
        return aminal.calculateLoveForETH(ethAmount);
    }
    
    function _assertSelfSovereign(Aminal targetAminal) internal {
        assertEq(targetAminal.ownerOf(1), address(targetAminal), "Aminal should own itself");
        assertEq(targetAminal.balanceOf(address(targetAminal)), 1, "Aminal should have balance of 1");
    }
}