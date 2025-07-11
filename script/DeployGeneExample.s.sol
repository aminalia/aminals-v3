// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {Gene} from "src/Gene.sol";

/**
 * @title DeployGeneExample
 * @dev Example deployment script showing how to create Gene collections and mint traits
 */
contract DeployGeneExample is Script {
    // Example SVG components for different traits - each is a complete self-contained SVG
    // These are simplified examples - real traits would be more detailed
    
    // Back traits (complete SVGs with viewBox)
    string constant DRAGON_WINGS = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="-100 -100 200 200"><g id="dragon-wings"><path d="M-50,-30 Q-80,-50 -90,-30 L-70,-10 Q-60,-20 -50,-30" fill="#8B4513" stroke="#000" stroke-width="2"/><path d="M50,-30 Q80,-50 90,-30 L70,-10 Q60,-20 50,-30" fill="#8B4513" stroke="#000" stroke-width="2"/></g></svg>';
    string constant ANGEL_WINGS = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="-100 -100 200 200"><g id="angel-wings"><ellipse cx="-40" cy="-20" rx="30" ry="50" fill="#FFFFFF" stroke="#FFD700" stroke-width="2" opacity="0.9"/><ellipse cx="40" cy="-20" rx="30" ry="50" fill="#FFFFFF" stroke="#FFD700" stroke-width="2" opacity="0.9"/></g></svg>';
    string constant BUTTERFLY_WINGS = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="-100 -100 200 200"><g id="butterfly-wings"><path d="M-30,-20 Q-50,-40 -40,-10 Q-30,-30 -30,-20" fill="#FF69B4" stroke="#FF1493" stroke-width="1.5"/><path d="M30,-20 Q50,-40 40,-10 Q30,-30 30,-20" fill="#FF69B4" stroke="#FF1493" stroke-width="1.5"/></g></svg>';
    
    // Tail traits (complete SVGs with viewBox)
    string constant FIRE_TAIL = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="-50 0 100 100"><g id="fire-tail"><path d="M0,30 Q-10,50 0,70 Q10,50 0,30" fill="#FF4500" stroke="#FF0000" stroke-width="2"/><path d="M0,40 Q-5,50 0,60 Q5,50 0,40" fill="#FFA500" stroke="#FF4500" stroke-width="1"/></g></svg>';
    string constant FLUFFY_TAIL = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="-50 0 100 100"><g id="fluffy-tail"><ellipse cx="0" cy="50" rx="20" ry="30" fill="#D2691E" stroke="#8B4513" stroke-width="2"/><ellipse cx="0" cy="50" rx="15" ry="25" fill="#DEB887" stroke="none"/></g></svg>';
    string constant LIGHTNING_TAIL = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="-50 0 100 100"><g id="lightning-tail"><path d="M0,30 L-10,50 L5,50 L-5,70 L15,45 L0,45 Z" fill="#FFFF00" stroke="#FFD700" stroke-width="2"/></g></svg>';
    
    // Ear traits (complete SVGs with viewBox)
    string constant BUNNY_EARS = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="-50 -100 100 100"><g id="bunny-ears"><ellipse cx="-20" cy="-60" rx="10" ry="30" fill="#FFC0CB" stroke="#000" stroke-width="2"/><ellipse cx="20" cy="-60" rx="10" ry="30" fill="#FFC0CB" stroke="#000" stroke-width="2"/></g></svg>';
    string constant CAT_EARS = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="-50 -100 100 100"><g id="cat-ears"><path d="M-30,-50 L-15,-30 L-40,-35 Z" fill="#FF8C00" stroke="#000" stroke-width="2"/><path d="M30,-50 L15,-30 L40,-35 Z" fill="#FF8C00" stroke="#000" stroke-width="2"/></g></svg>';
    string constant HORN_EARS = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="-50 -100 100 100"><g id="horn-ears"><path d="M-15,-50 L-10,-70 L-20,-50 Z" fill="#4B0082" stroke="#000" stroke-width="2"/><path d="M15,-50 L10,-70 L20,-50 Z" fill="#4B0082" stroke="#000" stroke-width="2"/></g></svg>';
    
    // Body traits (complete SVGs with viewBox)
    string constant STAR_PATTERN = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="-20 -20 40 40"><g id="star-pattern"><polygon points="0,-10 3,-3 10,-2 5,3 6,10 0,6 -6,10 -5,3 -10,-2 -3,-3" fill="#FFD700" stroke="#FFA500" stroke-width="1"/></g></svg>';
    string constant HEART_PATTERN = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="-20 -20 40 40"><g id="heart-pattern"><path d="M0,5 C0,0 -5,-5 -10,-5 C-15,-5 -15,0 -15,0 C-15,0 -15,-5 -20,-5 C-25,-5 -30,0 -30,5 C-30,10 -15,20 0,30 C15,20 30,10 30,5 C30,0 25,-5 20,-5 C15,-5 15,0 15,0 C15,0 15,-5 10,-5 C5,-5 0,0 0,5 Z" transform="scale(0.5)" fill="#FF1493" stroke="#C71585" stroke-width="1"/></g></svg>';
    
    // Misc traits (complete SVGs with viewBox)
    string constant SPARKLES = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="-50 -50 100 100"><g id="sparkles"><circle cx="-30" cy="-30" r="3" fill="#FFD700"><animate attributeName="opacity" values="1;0.3;1" dur="2s" repeatCount="indefinite"/></circle><circle cx="30" cy="-30" r="3" fill="#FFD700"><animate attributeName="opacity" values="0.3;1;0.3" dur="2s" repeatCount="indefinite"/></circle><circle cx="0" cy="-40" r="2" fill="#FFFFFF"><animate attributeName="opacity" values="0.5;1;0.5" dur="1.5s" repeatCount="indefinite"/></circle></g></svg>';
    string constant HALO = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="-50 -100 100 100"><g id="halo"><ellipse cx="0" cy="-70" rx="25" ry="5" fill="none" stroke="#FFD700" stroke-width="3" opacity="0.8"><animate attributeName="opacity" values="0.8;0.4;0.8" dur="3s" repeatCount="indefinite"/></ellipse></g></svg>';
    
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy a single Gene collection for all traits
        Gene gene = new Gene(deployer, "Aminal Genes", "GENE", "");
        console.log("Gene deployed at:", address(gene));
        
        // Mint example traits to demonstrate the system
        
        // Back traits
        gene.mint(
            deployer,
            "back",
            "Dragon Wings",
            DRAGON_WINGS,
            "Majestic dragon wings that grant the power of flight"
        );
        
        gene.mint(
            deployer,
            "back",
            "Angel Wings",
            ANGEL_WINGS,
            "Pure white angel wings that shimmer with divine light"
        );
        
        gene.mint(
            deployer,
            "back",
            "Butterfly Wings",
            BUTTERFLY_WINGS,
            "Delicate butterfly wings that flutter with grace"
        );
        
        // Tail traits
        gene.mint(
            deployer,
            "tail",
            "Fire Tail",
            FIRE_TAIL,
            "A tail made of pure fire that leaves a trail of embers"
        );
        
        gene.mint(
            deployer,
            "tail",
            "Fluffy Tail",
            FLUFFY_TAIL,
            "A soft, fluffy tail perfect for cuddles"
        );
        
        gene.mint(
            deployer,
            "tail",
            "Lightning Tail",
            LIGHTNING_TAIL,
            "A tail charged with electric energy"
        );
        
        // Ear traits
        gene.mint(
            deployer,
            "ears",
            "Bunny Ears",
            BUNNY_EARS,
            "Soft, fluffy bunny ears that twitch with emotion"
        );
        
        gene.mint(
            deployer,
            "ears",
            "Cat Ears",
            CAT_EARS,
            "Pointed cat ears that swivel to track sounds"
        );
        
        gene.mint(
            deployer,
            "ears",
            "Horns",
            HORN_EARS,
            "Small horns that give a mischievous appearance"
        );
        
        // Body patterns
        gene.mint(
            deployer,
            "body",
            "Star Pattern",
            STAR_PATTERN,
            "A glowing star pattern on the body"
        );
        
        gene.mint(
            deployer,
            "body",
            "Heart Pattern",
            HEART_PATTERN,
            "Cute heart patterns adorning the body"
        );
        
        // Misc traits
        gene.mint(
            deployer,
            "misc",
            "Sparkles",
            SPARKLES,
            "Magical sparkles that follow the Aminal wherever it goes"
        );
        
        gene.mint(
            deployer,
            "misc",
            "Halo",
            HALO,
            "A glowing halo that hovers above, marking this as a special Aminal"
        );
        
        console.log("Example traits minted successfully!");
        
        // Log some example token URIs
        string memory uri1 = gene.tokenURI(1);
        console.log("Dragon Wings token URI:", uri1);
        
        // Show how to get raw SVG for composability
        string memory rawSvg = gene.gene(1);
        console.log("Dragon Wings raw SVG:", rawSvg);
        
        vm.stopBroadcast();
    }
}