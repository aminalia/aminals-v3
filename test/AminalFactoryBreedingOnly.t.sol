// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {AminalFactory} from "src/AminalFactory.sol";
import {AminalBreedingVote} from "src/AminalBreedingVote.sol";
import {Aminal} from "src/Aminal.sol";
import {IGenes} from "src/interfaces/IGenes.sol";

contract AminalFactoryBreedingOnlyTest is Test {
    AminalFactory public factory;
    AminalBreedingVote public breedingVote;
    
    address public owner;
    address public user;
    
    // First parent traits (Adam)
    IGenes.Genes public adamTraits = IGenes.Genes({
        back: "Original Wings",
        arm: "Strong Arms",
        tail: "Lion Tail",
        ears: "Alert Ears",
        body: "Muscular Body",
        face: "Wise Face",
        mouth: "Confident Smile",
        misc: "Divine Aura"
    });
    
    // Second parent traits (Eve)
    IGenes.Genes public eveTraits = IGenes.Genes({
        back: "Graceful Wings",
        arm: "Gentle Arms",
        tail: "Flowing Tail",
        ears: "Delicate Ears",
        body: "Elegant Body",
        face: "Beautiful Face",
        mouth: "Warm Smile",
        misc: "Radiant Glow"
    });
    
    function setUp() public {
        owner = makeAddr("owner");
        user = makeAddr("user");
        
        // Create parent data structs
        AminalFactory.ParentData memory adamData = AminalFactory.ParentData({
            name: "Adam",
            symbol: "ADAM",
            description: "The first Aminal",
            tokenURI: "adam.json",
            genes: adamTraits
        });
        
        AminalFactory.ParentData memory eveData = AminalFactory.ParentData({
            name: "Eve",
            symbol: "EVE",
            description: "The second Aminal",
            tokenURI: "eve.json",
            genes: eveTraits
        });
        
        vm.prank(owner);
        factory = new AminalFactory(
            owner,
            adamData,
            eveData
        );
        
        breedingVote = new AminalBreedingVote(address(factory), address(0x123));
    }
}