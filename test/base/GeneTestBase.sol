// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Gene} from "src/Gene.sol";
import {TestHelpers} from "../helpers/TestHelpers.sol";

/**
 * @title GeneTestBase
 * @notice Base contract for Gene NFT tests
 */
abstract contract GeneTestBase is Test {
    using TestHelpers for *;
    
    Gene public geneContract;
    
    // Common test users
    address public geneOwner;
    address public minter;
    address public holder1;
    address public holder2;
    
    // Constants
    string constant GENE_NAME = "Test Genes";
    string constant GENE_SYMBOL = "TGENE";
    string constant GENE_BASE_URI = "https://api.genes.com/";
    
    // Sample SVG data
    string constant DRAGON_WINGS_SVG = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="-100 -100 200 200"><path d="M-50,-30 Q-80,-50 -90,-30 L-70,-10 Q-60,-20 -50,-30" fill="#8B4513"/></svg>';
    string constant ANGEL_WINGS_SVG = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="-100 -100 200 200"><path d="M-50,-40 Q-70,-60 -80,-40 L-60,-20 Q-55,-30 -50,-40" fill="#FFFFFF"/></svg>';
    string constant LASER_ARMS_SVG = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="-50 -50 100 100"><rect x="-10" y="-40" width="20" height="40" fill="#FF0000"/></svg>';
    
    // Gene types
    string[8] geneTypes = ["back", "arm", "tail", "ears", "body", "face", "mouth", "misc"];
    
    function setUp() public virtual {
        // Setup users
        geneOwner = makeAddr("geneOwner");
        minter = makeAddr("minter");
        holder1 = makeAddr("holder1");
        holder2 = makeAddr("holder2");
        
        // Deploy contracts
        geneContract = new Gene(geneOwner, GENE_NAME, GENE_SYMBOL, GENE_BASE_URI);
    }
    
    function _mintGene(
        address to,
        string memory traitType,
        string memory traitValue,
        string memory svg,
        string memory description
    ) internal returns (uint256) {
        vm.prank(minter);
        return geneContract.mint(to, traitType, traitValue, svg, description);
    }
    
    function _mintStandardGenes() internal returns (uint256[] memory tokenIds) {
        tokenIds = new uint256[](3);
        tokenIds[0] = _mintGene(holder1, "back", "Dragon Wings", DRAGON_WINGS_SVG, "Majestic dragon wings");
        tokenIds[1] = _mintGene(holder1, "back", "Angel Wings", ANGEL_WINGS_SVG, "Heavenly angel wings");
        tokenIds[2] = _mintGene(holder2, "arm", "Laser Arms", LASER_ARMS_SVG, "Powerful laser arms");
    }
    
    function _assertGeneMetadata(
        uint256 tokenId,
        string memory expectedType,
        string memory expectedValue
    ) internal {
        assertEq(geneContract.tokenTraitType(tokenId), expectedType, "Trait type mismatch");
        assertEq(geneContract.tokenTraitValue(tokenId), expectedValue, "Trait value mismatch");
    }
    
    function _assertGeneOwnership(uint256 tokenId, address expectedOwner) internal {
        assertEq(geneContract.ownerOf(tokenId), expectedOwner, "Owner mismatch");
    }
    
    function _assertTokensByType(string memory traitType, uint256 expectedCount) internal {
        uint256[] memory tokens = geneContract.getTokensByTraitType(traitType);
        assertEq(tokens.length, expectedCount, "Token count by type mismatch");
    }
    
    function _assertTokensByValue(string memory traitValue, uint256 expectedCount) internal {
        uint256[] memory tokens = geneContract.getTokensByTraitValue(traitValue);
        assertEq(tokens.length, expectedCount, "Token count by value mismatch");
    }
}