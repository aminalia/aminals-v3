// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AminalTestBase} from "../../base/AminalTestBase.sol";
import {Aminal} from "src/Aminal.sol";
import {IGenes} from "src/interfaces/IGenes.sol";
import {TestHelpers} from "../../helpers/TestHelpers.sol";

/**
 * @title AminalCoreTest
 * @notice Tests core Aminal functionality: creation, initialization, self-sovereignty
 */
contract AminalCoreTest is AminalTestBase {
    using TestHelpers for *;
    
    function test_Constructor() public {
        assertEq(aminal.name(), DEFAULT_NAME);
        assertEq(aminal.symbol(), DEFAULT_SYMBOL);
        assertEq(aminal.totalSupply(), 0);
        assertEq(aminal.TOKEN_ID(), 1);
        assertFalse(aminal.minted());
        assertFalse(aminal.initialized());
    }
    
    function test_Initialize() public {
        // Arrange
        string memory tokenURI = "test-aminal.json";
        
        // Act
        uint256 tokenId = _initializeAminal(aminal, tokenURI);
        
        // Assert
        assertEq(tokenId, 1);
        _assertSelfSovereign(aminal);
        assertTrue(bytes(aminal.tokenURI(tokenId)).length > 0);
        assertEq(aminal.totalSupply(), 1);
        assertTrue(aminal.exists(tokenId));
        assertTrue(aminal.minted());
        assertTrue(aminal.initialized());
    }
    
    function test_InitializeByAnyone() public {
        // Arrange
        address randomUser = makeAddr("random");
        string memory tokenURI = "random-init.json";
        
        // Act
        vm.prank(randomUser);
        uint256 tokenId = aminal.initialize(tokenURI);
        
        // Assert
        assertEq(tokenId, 1);
        _assertSelfSovereign(aminal);
        assertTrue(aminal.initialized());
    }
    
    function test_PermanentSelfOwnership() public {
        // Arrange
        _initializeAminal(aminal, "self-owned.json");
        
        // Assert
        _assertSelfSovereign(aminal);
        assertEq(aminal.balanceOf(user1), 0);
        assertEq(aminal.balanceOf(user2), 0);
        assertEq(aminal.getApproved(1), address(0));
        assertFalse(aminal.isApprovedForAll(address(aminal), user1));
    }
    
    function test_Genes() public {
        // Arrange
        IGenes.Genes memory expectedGenes = TestHelpers.dragonTraits();
        
        // Act
        IGenes.Genes memory actualGenes = aminal.getGenes();
        
        // Assert
        assertGenes(actualGenes, expectedGenes, "Aminal genes");
    }
    
    function test_SupportsInterface() public {
        // ERC721 interface
        assertTrue(aminal.supportsInterface(0x80ac58cd));
        // ERC721Metadata interface  
        assertTrue(aminal.supportsInterface(0x5b5e139f));
        // ERC165 interface
        assertTrue(aminal.supportsInterface(0x01ffc9a7));
    }
    
    // ========== Revert Tests ==========
    
    function test_RevertWhen_InitializeTwice() public {
        // Arrange
        _initializeAminal(aminal, "first.json");
        
        // Act & Assert
        vm.expectRevert(Aminal.AlreadyMinted.selector);
        aminal.initialize("second.json");
    }
    
    function test_RevertWhen_TransferAttempted() public {
        // Arrange
        uint256 tokenId = _initializeAminal(aminal, "no-transfer.json");
        
        // Act & Assert - transferFrom
        vm.prank(address(aminal));
        vm.expectRevert(Aminal.TransferNotAllowed.selector);
        aminal.transferFrom(address(aminal), user1, tokenId);
        
        // Act & Assert - safeTransferFrom
        vm.prank(address(aminal));
        vm.expectRevert(Aminal.TransferNotAllowed.selector);
        aminal.safeTransferFrom(address(aminal), user1, tokenId);
        
        // Act & Assert - safeTransferFrom with data
        vm.prank(address(aminal));
        vm.expectRevert(Aminal.TransferNotAllowed.selector);
        aminal.safeTransferFrom(address(aminal), user1, tokenId, "data");
        
        // Verify still self-owned
        _assertSelfSovereign(aminal);
    }
    
    function test_RevertWhen_ApprovalAttempted() public {
        // Arrange
        _initializeAminal(aminal, "no-approval.json");
        
        // Act & Assert - approve
        vm.prank(address(aminal));
        vm.expectRevert(Aminal.TransferNotAllowed.selector);
        aminal.approve(user1, 1);
        
        // Act & Assert - setApprovalForAll
        vm.prank(address(aminal));
        vm.expectRevert(Aminal.TransferNotAllowed.selector);
        aminal.setApprovalForAll(user1, true);
    }
    
    function test_RevertWhen_SetBaseURIByNonSelf() public {
        // Act & Assert
        vm.prank(user1);
        vm.expectRevert(Aminal.NotAuthorized.selector);
        aminal.setBaseURI("https://evil.com/");
    }
    
    // ========== Fuzz Tests ==========
    
    function testFuzz_Initialize(string memory tokenURI) public {
        // Assume
        vm.assume(bytes(tokenURI).length > 0);
        
        // Act
        uint256 tokenId = _initializeAminal(aminal, tokenURI);
        
        // Assert
        assertEq(tokenId, 1);
        _assertSelfSovereign(aminal);
        assertTrue(aminal.exists(tokenId));
        assertTrue(aminal.initialized());
    }
}