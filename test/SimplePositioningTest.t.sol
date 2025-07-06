// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {Aminal} from "../src/Aminal.sol";
import {AminalFactory} from "../src/AminalFactory.sol";
import {IGenes} from "../src/interfaces/IGenes.sol";

contract SimplePositioningTest is Test {
    AminalFactory public factory;
    
    function setUp() public {
        // Create parent data
        AminalFactory.ParentData memory firstParent = AminalFactory.ParentData({
            name: "Adam",
            symbol: "ADAM",
            description: "The first Aminal",
            tokenURI: "ipfs://adam",
            genes: IGenes.Genes({
                back: "Dragon Wings",
                arm: "Strong Arms",
                tail: "Dragon Tail",
                ears: "Dragon Ears",
                body: "Dragon Body",
                face: "Dragon Face",
                mouth: "Dragon Mouth",
                misc: ""
            })
        });
        
        AminalFactory.ParentData memory secondParent = AminalFactory.ParentData({
            name: "Eve",
            symbol: "EVE",
            description: "The second Aminal",
            tokenURI: "ipfs://eve",
            genes: IGenes.Genes({
                back: "Angel Wings",
                arm: "Gentle Arms",
                tail: "Fluffy Tail",
                ears: "Bunny Ears",
                body: "Soft Body",
                face: "Kind Face",
                mouth: "Sweet Mouth",
                misc: ""
            })
        });
        
        // Deploy factory
        factory = new AminalFactory(address(this), firstParent, secondParent);
    }
    
    function test_DefaultPositions() public {
        // Create Aminal directly with factory
        IGenes.Genes memory traits = IGenes.Genes({
            back: "Test Back",
            arm: "Test Arm",
            tail: "Test Tail",
            ears: "Test Ears",
            body: "Test Body",
            face: "Test Face",
            mouth: "Test Mouth",
            misc: ""
        });
        
        address aminalAddress = factory.createAminalWithGenes(
            "Test Aminal",
            "TEST",
            "A test aminal",
            "ipfs://test",
            traits
        );
        
        Aminal testAminal = Aminal(payable(aminalAddress));
        
        // Check all positions are set to defaults
        (int16 x, int16 y, uint16 width, uint16 height) = testAminal.genePositions(testAminal.GENE_BODY());
        assertEq(x, 50, "Body default X");
        assertEq(y, 50, "Body default Y");
        assertEq(width, 100, "Body default width");
        assertEq(height, 100, "Body default height");
        
        (x, y, width, height) = testAminal.genePositions(testAminal.GENE_EARS());
        assertEq(x, 50, "Ears default X");
        assertEq(y, 0, "Ears default Y");
        assertEq(width, 100, "Ears default width");
        assertEq(height, 60, "Ears default height");
        
        (x, y, width, height) = testAminal.genePositions(testAminal.GENE_BACK());
        assertEq(x, 0, "Back default X");
        assertEq(y, 0, "Back default Y");
        assertEq(width, 200, "Back default width");
        assertEq(height, 200, "Back default height");
        
        console.log("All default positions verified successfully!");
    }
}