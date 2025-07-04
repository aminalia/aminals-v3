// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {GeneNFTWithPosition} from "src/GeneNFTWithPosition.sol";
import {GeneRenderer} from "src/GeneRenderer.sol";

contract GeneNFTWithPositionTest is Test {
    GeneNFTWithPosition public geneNFT;
    address public owner = address(0x1);
    address public user = address(0x2);
    
    function _createImage(uint256 tokenId) internal view returns (string memory) {
        (int256 x, int256 y, uint256 width, uint256 height,) = geneNFT.getPosition(tokenId);
        return GeneRenderer.svgImage(x, y, width, height, geneNFT.gene(tokenId));
    }

    function setUp() public {
        vm.startPrank(owner);
        geneNFT = new GeneNFTWithPosition(owner, "Positioned Genes", "PGENE", "");
        vm.stopPrank();
    }

    function test_MintWithPosition() public {
        vm.startPrank(user);
        
        // Complete SVG for a wing trait
        string memory wingSvg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="-100 -100 200 200"><path d="M-50,-30 Q-80,-50 -90,-30 L-70,-10 Q-60,-20 -50,-30" fill="#8B4513"/></svg>';
        
        uint256 tokenId = geneNFT.mintWithPosition(
            user,
            "back",
            "Dragon Wing",
            wingSvg,
            "A dragon wing",
            -50,    // x
            -50,    // y
            300,    // width
            300,    // height
            1       // zIndex (behind)
        );
        
        // Check position data
        (int256 x, int256 y, uint256 width, uint256 height, uint256 zIndex) = geneNFT.getPosition(tokenId);
        assertEq(x, -50);
        assertEq(y, -50);
        assertEq(width, 300);
        assertEq(height, 300);
        assertEq(zIndex, 1);
        
        vm.stopPrank();
    }

    function test_ComposeWithPositions() public {
        vm.startPrank(user);
        
        // Mint traits with specific positions
        uint256 bodyId = geneNFT.mintWithPosition(
            user,
            "body",
            "Base Body",
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="-50 -50 100 100"><circle cx="0" cy="0" r="40" fill="#FFE4B5"/></svg>',
            "Base body shape",
            50, 50, 100, 100, 10  // Center, mid z-index
        );
        
        uint256 backId = geneNFT.mintWithPosition(
            user,
            "back",
            "Wings",
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="-100 -100 200 200"><path d="M-50,0 Q-80,-30 -50,-60 L-20,-30 Q-35,-15 -50,0" fill="#FFF"/><path d="M50,0 Q80,-30 50,-60 L20,-30 Q35,-15 50,0" fill="#FFF"/></svg>',
            "Angel wings",
            0, 20, 200, 160, 5  // Behind body
        );
        
        uint256 eyesId = geneNFT.mintWithPosition(
            user,
            "face",
            "Eyes",
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="-30 -30 60 60"><circle cx="-10" cy="0" r="5" fill="#000"/><circle cx="10" cy="0" r="5" fill="#000"/></svg>',
            "Simple eyes",
            70, 70, 60, 60, 15  // In front of body
        );
        
        // Compose based on z-index order (lower first)
        string memory backImage = _createImage(backId);
        string memory bodyImage = _createImage(bodyId);
        string memory eyesImage = _createImage(eyesId);
        
        string memory composed = GeneRenderer.svg(
            "0 0 200 200",
            string.concat(backImage, bodyImage, eyesImage)
        );
        
        console.log("Composed with positions:");
        console.log(composed);
        
        vm.stopPrank();
    }

    function test_LayeringWithZIndex() public {
        vm.startPrank(user);
        
        // Create overlapping elements with different z-indices
        string memory redSquare = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100"><rect width="100" height="100" fill="#FF0000"/></svg>';
        string memory blueSquare = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100"><rect width="100" height="100" fill="#0000FF"/></svg>';
        string memory greenSquare = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100"><rect width="100" height="100" fill="#00FF00"/></svg>';
        
        // Mint with overlapping positions but different z-indices
        uint256 red = geneNFT.mintWithPosition(user, "layer", "Red", redSquare, "Red layer", 50, 50, 100, 100, 1);
        uint256 blue = geneNFT.mintWithPosition(user, "layer", "Blue", blueSquare, "Blue layer", 75, 75, 100, 100, 2);
        uint256 green = geneNFT.mintWithPosition(user, "layer", "Green", greenSquare, "Green layer", 100, 100, 100, 100, 3);
        
        // Verify z-indices
        (,,,,uint256 redZ) = geneNFT.getPosition(red);
        (,,,,uint256 blueZ) = geneNFT.getPosition(blue);
        (,,,,uint256 greenZ) = geneNFT.getPosition(green);
        
        assertEq(redZ, 1);
        assertEq(blueZ, 2);
        assertEq(greenZ, 3);
        
        vm.stopPrank();
    }
}