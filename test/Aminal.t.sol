// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "lib/forge-std/src/Test.sol";
import {Aminal} from "src/Aminal.sol";
import {ITraits} from "src/interfaces/ITraits.sol";

contract AminalTest is Test {
    Aminal public aminal;
    address public user1;
    address public user2;
    string public constant BASE_URI = "https://api.aminals.com/metadata/";
    string public constant NAME = "Fire Dragon";
    string public constant SYMBOL = "FDRAGON";

    event AminalCreated(uint256 indexed tokenId, address indexed owner, string tokenURI);
    event BaseURIUpdated(string newBaseURI);
    event LoveReceived(address indexed from, uint256 amount, uint256 totalLove);
    event EnergyGained(address indexed from, uint256 amount, uint256 newEnergy);
    event EnergyLost(address indexed squeaker, uint256 amount, uint256 newEnergy);

    function setUp() external {
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        
        // Create sample traits
        ITraits.Traits memory traits = ITraits.Traits({
            back: "Dragon Wings",
            arm: "Scaled Arms",
            tail: "Fire Tail",
            ears: "Pointed Ears",
            body: "Dragon Body",
            face: "Fierce Face",
            mouth: "Fire Breath",
            misc: "Golden Scales"
        });
        
        // Deploy self-sovereign Aminal
        aminal = new Aminal(NAME, SYMBOL, BASE_URI, traits);
    }

    function test_Constructor() external {
        assertEq(aminal.name(), NAME);
        assertEq(aminal.symbol(), SYMBOL);
        assertEq(aminal.totalSupply(), 0);
        assertEq(aminal.TOKEN_ID(), 1);
        assertFalse(aminal.minted());
        assertFalse(aminal.initialized());
    }

    function test_ConstructorSelfSovereign() external {
        ITraits.Traits memory traits = ITraits.Traits({
            back: "Dragon Wings",
            arm: "Scaled Arms",
            tail: "Fire Tail",
            ears: "Pointed Ears",
            body: "Dragon Body",
            face: "Fierce Face",
            mouth: "Fire Breath",
            misc: "Golden Scales"
        });
        
        // Self-sovereign Aminal should deploy successfully
        Aminal selfSovereignAminal = new Aminal(NAME, SYMBOL, BASE_URI, traits);
        
        assertEq(selfSovereignAminal.name(), NAME);
        assertEq(selfSovereignAminal.symbol(), SYMBOL);
        assertFalse(selfSovereignAminal.initialized());
    }

    function test_Initialize() external {
        string memory tokenURI = "firedragon.json";
        
        vm.expectEmit(true, true, false, true);
        emit AminalCreated(1, address(aminal), tokenURI);
        
        uint256 tokenId = aminal.initialize(tokenURI);
        
        assertEq(tokenId, 1);
        assertEq(aminal.ownerOf(tokenId), address(aminal)); // Aminal owns itself!
        assertEq(aminal.tokenURI(tokenId), string(abi.encodePacked(BASE_URI, tokenURI)));
        assertEq(aminal.totalSupply(), 1);
        assertTrue(aminal.exists(tokenId));
        assertTrue(aminal.minted());
        assertTrue(aminal.initialized());
    }

    function test_RevertWhen_InitializeTwice() external {
        string memory tokenURI = "firedragon.json";
        
        // First initialization should succeed
        aminal.initialize(tokenURI);
        
        // Second initialization should fail due to already minted
        vm.expectRevert(Aminal.AlreadyMinted.selector);
        aminal.initialize("firedragon2.json");
    }

    function test_InitializeByAnyoneSucceeds() external {
        string memory tokenURI = "firedragon.json";
        
        // Anyone can initialize the Aminal
        vm.prank(user1);
        uint256 tokenId = aminal.initialize(tokenURI);
        
        assertEq(tokenId, 1);
        assertEq(aminal.ownerOf(tokenId), address(aminal));
        assertTrue(aminal.initialized());
    }

    function test_RevertWhen_InitializeAfterMinted() external {
        string memory tokenURI = "firedragon.json";
        
        // Initialize (mints token)
        aminal.initialize(tokenURI);
        
        // Cannot initialize again due to minted flag
        vm.expectRevert(Aminal.AlreadyMinted.selector);
        aminal.initialize("firedragon2.json");
    }

    function test_SetBaseURI() external {
        string memory newBaseURI = "https://newapi.aminals.com/metadata/";
        
        // Only the contract itself can set base URI
        vm.prank(address(aminal));
        vm.expectEmit(false, false, false, true);
        emit BaseURIUpdated(newBaseURI);
        
        aminal.setBaseURI(newBaseURI);
        
        // Initialize with new base URI
        uint256 tokenId = aminal.initialize("firedragon.json");
        
        assertEq(aminal.tokenURI(tokenId), string(abi.encodePacked(newBaseURI, "firedragon.json")));
    }

    function test_RevertWhen_SetBaseURICalledByNonSelf() external {
        vm.prank(user1);
        vm.expectRevert(Aminal.NotAuthorized.selector);
        aminal.setBaseURI("https://newapi.aminals.com/metadata/");
    }

    function test_TokenTransfer() external {
        uint256 tokenId = aminal.initialize("firedragon.json");
        
        // Aminal owns itself initially
        assertEq(aminal.ownerOf(tokenId), address(aminal));
        
        // Transfer from the Aminal to user1
        vm.prank(address(aminal));
        aminal.transferFrom(address(aminal), user1, tokenId);
        
        assertEq(aminal.ownerOf(tokenId), user1);
        assertEq(aminal.balanceOf(address(aminal)), 0);
        assertEq(aminal.balanceOf(user1), 1);
        
        // Transfer from user1 to user2
        vm.prank(user1);
        aminal.transferFrom(user1, user2, tokenId);
        
        assertEq(aminal.ownerOf(tokenId), user2);
        assertEq(aminal.balanceOf(user1), 0);
        assertEq(aminal.balanceOf(user2), 1);
    }

    function test_Exists() external {
        assertFalse(aminal.exists(1));
        assertFalse(aminal.exists(2));
        
        uint256 tokenId = aminal.initialize("firedragon.json");
        
        assertTrue(aminal.exists(tokenId));
        assertFalse(aminal.exists(2));
    }

    function test_IsMinted() external {
        assertFalse(aminal.minted());
        
        aminal.initialize("firedragon.json");
        
        assertTrue(aminal.minted());
    }

    function test_TotalSupply() external {
        assertEq(aminal.totalSupply(), 0);
        
        aminal.initialize("firedragon.json");
        
        assertEq(aminal.totalSupply(), 1);
    }

    function test_PublicVariableAccess() external {
        // Test direct access to public variables
        assertFalse(aminal.minted());
        assertFalse(aminal.initialized());
        assertEq(aminal.baseTokenURI(), BASE_URI);
        assertEq(aminal.TOKEN_ID(), 1);
        
        aminal.initialize("firedragon.json");
        
        // Verify public variables updated
        assertTrue(aminal.minted());
        assertTrue(aminal.initialized());
    }

    function test_Traits() external {
        // Test getTraits function
        ITraits.Traits memory traits = aminal.getTraits();
        assertEq(traits.back, "Dragon Wings");
        assertEq(traits.arm, "Scaled Arms");
        assertEq(traits.tail, "Fire Tail");
        assertEq(traits.ears, "Pointed Ears");
        assertEq(traits.body, "Dragon Body");
        assertEq(traits.face, "Fierce Face");
        assertEq(traits.mouth, "Fire Breath");
        assertEq(traits.misc, "Golden Scales");
    }

    function test_SupportsInterface() external {
        // ERC721 interface
        assertTrue(aminal.supportsInterface(0x80ac58cd));
        // ERC721Metadata interface
        assertTrue(aminal.supportsInterface(0x5b5e139f));
        // ERC165 interface
        assertTrue(aminal.supportsInterface(0x01ffc9a7));
    }

    function testFuzz_Initialize(string memory tokenURI) external {
        vm.assume(bytes(tokenURI).length > 0);
        
        uint256 tokenId = aminal.initialize(tokenURI);
        
        assertEq(tokenId, 1);
        assertEq(aminal.ownerOf(tokenId), address(aminal)); // Self-owned
        assertTrue(aminal.exists(tokenId));
        assertTrue(aminal.minted());
        assertTrue(aminal.initialized());
    }

    function testFuzz_SetBaseURI(string memory newBaseURI) external {
        // Only the contract itself can set base URI
        vm.prank(address(aminal));
        aminal.setBaseURI(newBaseURI);
        
        uint256 tokenId = aminal.initialize("test.json");
        
        assertEq(aminal.tokenURI(tokenId), string(abi.encodePacked(newBaseURI, "test.json")));
    }

    function test_ReceiveLove() external {
        uint256 loveAmount = 1 ether;
        
        // Check initial state
        assertEq(aminal.totalLove(), 0);
        assertEq(aminal.loveFromUser(user1), 0);
        assertEq(aminal.energy(), 0);
        assertEq(address(aminal).balance, 0);
        
        // Send love and expect events
        vm.prank(user1);
        vm.expectEmit(true, false, false, true);
        emit LoveReceived(user1, loveAmount, loveAmount);
        vm.expectEmit(true, false, false, true);
        emit EnergyGained(user1, loveAmount, loveAmount);
        
        vm.deal(user1, loveAmount);
        (bool success,) = address(aminal).call{value: loveAmount}("");
        assertTrue(success);
        
        // Verify love and energy tracking
        assertEq(aminal.totalLove(), loveAmount);
        assertEq(aminal.loveFromUser(user1), loveAmount);
        assertEq(aminal.energy(), loveAmount);
        assertEq(aminal.getTotalLove(), loveAmount);
        assertEq(aminal.getLoveFromUser(user1), loveAmount);
        assertEq(aminal.getEnergy(), loveAmount);
        assertEq(address(aminal).balance, loveAmount);
    }

    function test_MultipleLoveTransactions() external {
        uint256 firstLove = 0.5 ether;
        uint256 secondLove = 0.3 ether;
        uint256 totalExpected = firstLove + secondLove;
        
        vm.deal(user1, totalExpected);
        vm.deal(user2, 1 ether);
        
        // First love from user1
        vm.prank(user1);
        vm.expectEmit(true, false, false, true);
        emit LoveReceived(user1, firstLove, firstLove);
        (bool success,) = address(aminal).call{value: firstLove}("");
        assertTrue(success);
        
        // Second love from user1
        vm.prank(user1);
        vm.expectEmit(true, false, false, true);
        emit LoveReceived(user1, secondLove, totalExpected);
        (success,) = address(aminal).call{value: secondLove}("");
        assertTrue(success);
        
        // Love from user2
        uint256 user2Love = 0.7 ether;
        vm.prank(user2);
        vm.expectEmit(true, false, false, true);
        emit LoveReceived(user2, user2Love, totalExpected + user2Love);
        (success,) = address(aminal).call{value: user2Love}("");
        assertTrue(success);
        
        // Verify final state
        assertEq(aminal.totalLove(), totalExpected + user2Love);
        assertEq(aminal.loveFromUser(user1), totalExpected);
        assertEq(aminal.loveFromUser(user2), user2Love);
        assertEq(address(aminal).balance, totalExpected + user2Love);
    }

    function test_ZeroValueLove() external {
        // Sending 0 ETH should not emit event or update state
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: 0}("");
        assertTrue(success);
        
        assertEq(aminal.totalLove(), 0);
        assertEq(aminal.loveFromUser(user1), 0);
        assertEq(address(aminal).balance, 0);
    }

    function testFuzz_ReceiveLove(uint96 amount) external {
        vm.assume(amount > 0);
        
        vm.deal(user1, amount);
        vm.prank(user1);
        
        vm.expectEmit(true, false, false, true);
        emit LoveReceived(user1, amount, amount);
        
        (bool success,) = address(aminal).call{value: amount}("");
        assertTrue(success);
        
        assertEq(aminal.totalLove(), amount);
        assertEq(aminal.loveFromUser(user1), amount);
        assertEq(address(aminal).balance, amount);
    }

    function test_LoveQueryFunctions() external {
        uint256 loveAmount = 2 ether;
        
        vm.deal(user1, loveAmount);
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: loveAmount}("");
        assertTrue(success);
        
        // Test getter functions
        assertEq(aminal.getTotalLove(), loveAmount);
        assertEq(aminal.getLoveFromUser(user1), loveAmount);
        assertEq(aminal.getLoveFromUser(user2), 0);
        
        // Test public variables
        assertEq(aminal.totalLove(), loveAmount);
        assertEq(aminal.loveFromUser(user1), loveAmount);
        assertEq(aminal.loveFromUser(user2), 0);
    }

    function test_EnergySystem() external {
        uint256 feedAmount = 2 ether;
        uint256 squeakAmount = 0.5 ether;
        
        // Check initial energy
        assertEq(aminal.energy(), 0);
        assertEq(aminal.getEnergy(), 0);
        
        // Feed the Aminal (send ETH)
        vm.deal(user1, feedAmount);
        vm.prank(user1);
        vm.expectEmit(true, false, false, true);
        emit EnergyGained(user1, feedAmount, feedAmount);
        (bool success,) = address(aminal).call{value: feedAmount}("");
        assertTrue(success);
        
        // Verify energy increased
        assertEq(aminal.energy(), feedAmount);
        assertEq(aminal.getEnergy(), feedAmount);
        
        // Make the Aminal squeak
        vm.prank(user2);
        vm.expectEmit(true, false, false, true);
        emit EnergyLost(user2, squeakAmount, feedAmount - squeakAmount);
        aminal.squeak(squeakAmount);
        
        // Verify energy decreased
        assertEq(aminal.energy(), feedAmount - squeakAmount);
        assertEq(aminal.getEnergy(), feedAmount - squeakAmount);
    }

    function test_RevertWhen_InsufficientEnergy() external {
        uint256 feedAmount = 1 ether;
        uint256 squeakAmount = 2 ether; // More than available
        
        // Feed the Aminal
        vm.deal(user1, feedAmount);
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: feedAmount}("");
        assertTrue(success);
        
        // Try to squeak more than available energy
        vm.prank(user2);
        vm.expectRevert(Aminal.InsufficientEnergy.selector);
        aminal.squeak(squeakAmount);
        
        // Energy should remain unchanged
        assertEq(aminal.energy(), feedAmount);
    }

    function test_SqueakWithZeroEnergy() external {
        // Try to squeak with no energy
        vm.prank(user1);
        vm.expectRevert(Aminal.InsufficientEnergy.selector);
        aminal.squeak(1);
        
        assertEq(aminal.energy(), 0);
    }

    function test_SqueakExactEnergyAmount() external {
        uint256 feedAmount = 1 ether;
        
        // Feed the Aminal
        vm.deal(user1, feedAmount);
        vm.prank(user1);
        (bool success,) = address(aminal).call{value: feedAmount}("");
        assertTrue(success);
        
        // Squeak exact amount of energy available
        vm.prank(user2);
        vm.expectEmit(true, false, false, true);
        emit EnergyLost(user2, feedAmount, 0);
        aminal.squeak(feedAmount);
        
        // Energy should be zero
        assertEq(aminal.energy(), 0);
    }

    function test_MultipleFeedings() external {
        uint256 firstFeed = 1 ether;
        uint256 secondFeed = 0.5 ether;
        uint256 totalEnergy = firstFeed + secondFeed;
        
        vm.deal(user1, firstFeed);
        vm.deal(user2, secondFeed);
        
        // First feeding
        vm.prank(user1);
        vm.expectEmit(true, false, false, true);
        emit EnergyGained(user1, firstFeed, firstFeed);
        (bool success,) = address(aminal).call{value: firstFeed}("");
        assertTrue(success);
        
        // Second feeding
        vm.prank(user2);
        vm.expectEmit(true, false, false, true);
        emit EnergyGained(user2, secondFeed, totalEnergy);
        (success,) = address(aminal).call{value: secondFeed}("");
        assertTrue(success);
        
        // Verify total energy
        assertEq(aminal.energy(), totalEnergy);
    }

    function testFuzz_EnergySystem(uint96 feedAmount, uint96 squeakAmount) external {
        vm.assume(feedAmount > 0);
        vm.assume(squeakAmount <= feedAmount); // Only test valid squeak amounts
        
        // Feed the Aminal
        vm.deal(user1, feedAmount);
        vm.prank(user1);
        vm.expectEmit(true, false, false, true);
        emit EnergyGained(user1, feedAmount, feedAmount);
        (bool success,) = address(aminal).call{value: feedAmount}("");
        assertTrue(success);
        
        assertEq(aminal.energy(), feedAmount);
        
        // Squeak
        vm.prank(user2);
        vm.expectEmit(true, false, false, true);
        emit EnergyLost(user2, squeakAmount, feedAmount - squeakAmount);
        aminal.squeak(squeakAmount);
        
        assertEq(aminal.energy(), feedAmount - squeakAmount);
    }
}