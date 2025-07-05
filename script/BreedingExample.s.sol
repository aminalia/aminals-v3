// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {AminalFactory} from "src/AminalFactory.sol";
import {Aminal} from "src/Aminal.sol";
import {IGenes} from "src/interfaces/IGenes.sol";

/**
 * @title BreedingExample
 * @notice Example script demonstrating Aminal breeding
 * @dev Run with: forge script script/BreedingExample.s.sol -vvv
 */
contract BreedingExample is Script {
    function run() public {
        // Deploy factory
        address deployer = makeAddr("deployer");
        vm.startPrank(deployer);
        
        // Create parent data for Adam and Eve
        AminalFactory.ParentData memory firstParentData = AminalFactory.ParentData({
            name: "Adam",
            symbol: "ADAM",
            description: "The first Aminal",
            tokenURI: "ipfs://adam",
            traits: IGenes.Genes({
                back: "Original Wings",
                arm: "First Arms",
                tail: "Genesis Tail",
                ears: "Prime Ears",
                body: "Alpha Body",
                face: "Beginning Face",
                mouth: "Initial Mouth",
                misc: "Creation Spark"
            })
        });
        
        AminalFactory.ParentData memory secondParentData = AminalFactory.ParentData({
            name: "Eve",
            symbol: "EVE",
            description: "The second Aminal",
            tokenURI: "ipfs://eve",
            traits: IGenes.Genes({
                back: "Life Wings",
                arm: "Gentle Arms",
                tail: "Harmony Tail",
                ears: "Listening Ears",
                body: "Nurturing Body",
                face: "Wisdom Face",
                mouth: "Speaking Mouth",
                misc: "Life Force"
            })
        });
        
        AminalFactory factory = new AminalFactory(
            deployer,
            "https://api.aminals.com/metadata/",
            firstParentData,
            secondParentData
        );
        vm.stopPrank();
        
        console.log("Factory deployed at:", address(factory));
        
        // Create first parent Aminal
        IGenes.Genes memory dragonTraits = IGenes.Genes({
            back: "Dragon Wings",
            arm: "Clawed Arms",
            tail: "Fire Tail",
            ears: "Horned Ears",
            body: "Scaled Body",
            face: "Fierce Face",
            mouth: "Sharp Teeth",
            misc: "Glowing Eyes"
        });
        
        address dragon = factory.createAminal(
            "FireDragon",
            "FIRE",
            "A powerful fire dragon",
            "fire-dragon.json",
            dragonTraits
        );
        
        console.log("First parent (Dragon) created at:", dragon);
        
        // Create second parent Aminal
        IGenes.Genes memory bunnyTraits = IGenes.Genes({
            back: "Angel Wings",
            arm: "Soft Arms",
            tail: "Cotton Tail",
            ears: "Bunny Ears",
            body: "Fluffy Body",
            face: "Cute Face",
            mouth: "Sweet Smile",
            misc: "Sparkles"
        });
        
        address bunny = factory.createAminal(
            "AngelBunny",
            "ANGEL",
            "A gentle angel bunny",
            "angel-bunny.json",
            bunnyTraits
        );
        
        console.log("Second parent (Bunny) created at:", bunny);
        
        // Now the Dragon will breed with the Bunny
        console.log("\n--- BREEDING TIME! ---");
        console.log("Dragon is breeding with Bunny...");
        
        // We need to call breed from the Dragon's perspective
        // In a real scenario, this would be done by the Aminal's skill system
        vm.prank(dragon);
        address child = factory.breed(
            bunny,
            "A magical hybrid of dragon and bunny",
            "dragon-bunny-hybrid.json"
        );
        
        console.log("Child born at:", child);
        
        // Display child information
        Aminal childAminal = Aminal(payable(child));
        console.log("\n--- CHILD DETAILS ---");
        console.log("Name:", childAminal.name());
        console.log("Symbol:", childAminal.symbol());
        console.log("Owner:", childAminal.ownerOf(1));
        
        // Display child traits
        IGenes.Genes memory childTraits = childAminal.getTraits();
        console.log("\n--- CHILD TRAITS (Alternating from parents) ---");
        console.log("Back:", childTraits.back, "(from Dragon)");
        console.log("Arm:", childTraits.arm, "(from Bunny)");
        console.log("Tail:", childTraits.tail, "(from Dragon)");
        console.log("Ears:", childTraits.ears, "(from Bunny)");
        console.log("Body:", childTraits.body, "(from Dragon)");
        console.log("Face:", childTraits.face, "(from Bunny)");
        console.log("Mouth:", childTraits.mouth, "(from Dragon)");
        console.log("Misc:", childTraits.misc, "(from Bunny)");
        
        console.log("\nTotal Aminals in existence:", factory.totalAminals());
    }
}