// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {AminalRenderer} from "src/AminalRenderer.sol";
import {GeneRenderer} from "src/GeneRenderer.sol";
import {Aminal} from "src/Aminal.sol";
import {GeneNFT} from "src/GeneNFT.sol";
import {ITraits} from "src/interfaces/ITraits.sol";
import {LibString} from "solady/utils/LibString.sol";
import {Base64} from "solady/utils/Base64.sol";

/**
 * @title OutputAminalRenderings
 * @dev Script to output Aminal renderings as files in the script directory
 * @notice Run with: forge script script/OutputAminalRenderings.s.sol -vvv > /dev/null
 */
contract OutputAminalRenderings is Script {
    using LibString for string;
    using LibString for uint256;

    AminalRenderer public renderer;
    GeneNFT public geneNFT;
    
    // Sample trait SVGs
    string constant DRAGON_WINGS = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="-100 -100 200 200"><path d="M-50,-30 Q-80,-50 -90,-30 L-70,-10 Q-60,-20 -50,-30" fill="#8B4513"/><path d="M50,-30 Q80,-50 90,-30 L70,-10 Q60,-20 50,-30" fill="#8B4513"/></svg>';
    string constant ANGEL_WINGS = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="-100 -100 200 200"><path d="M-50,0 Q-80,-30 -50,-60 L-20,-30 Q-35,-15 -50,0" fill="#FFF" stroke="#DDD"/><path d="M50,0 Q80,-30 50,-60 L20,-30 Q35,-15 50,0" fill="#FFF" stroke="#DDD"/></svg>';
    string constant BAT_WINGS = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="-100 -100 200 200"><path d="M-50,-20 Q-70,-40 -80,-20 L-60,0 Q-55,-10 -50,-20 M-60,0 Q-65,-5 -70,0" fill="#333"/><path d="M50,-20 Q70,-40 80,-20 L60,0 Q55,-10 50,-20 M60,0 Q65,-5 70,0" fill="#333"/></svg>';
    
    string constant FIRE_TAIL = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="-50 0 100 100"><path d="M0,30 Q-10,50 0,70 Q10,50 0,30" fill="#FF4500"/><path d="M0,40 Q-5,50 0,60 Q5,50 0,40" fill="#FFD700"/></svg>';
    string constant LIGHTNING_TAIL = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="-50 0 100 100"><path d="M-10,20 L10,20 L0,40 L15,40 L-15,80 L5,50 L-10,50 Z" fill="#FFFF00" stroke="#FFD700"/></svg>';
    string constant FLUFFY_TAIL = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="-50 0 100 100"><circle cx="0" cy="30" r="15" fill="#FFF"/><circle cx="-5" cy="45" r="12" fill="#FFF"/><circle cx="5" cy="45" r="12" fill="#FFF"/><circle cx="0" cy="55" r="10" fill="#FFF"/></svg>';
    
    string constant BUNNY_EARS = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="-50 -100 100 100"><ellipse cx="-20" cy="-60" rx="10" ry="30" fill="#FFC0CB"/><ellipse cx="20" cy="-60" rx="10" ry="30" fill="#FFC0CB"/></svg>';
    string constant CAT_EARS = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="-50 -100 100 100"><path d="M-30,-80 L-15,-50 L-45,-50 Z" fill="#FFB366"/><path d="M30,-80 L15,-50 L45,-50 Z" fill="#FFB366"/></svg>';
    string constant DEVIL_HORNS = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="-50 -100 100 100"><path d="M-25,-80 Q-20,-50 -15,-60" fill="none" stroke="#8B0000" stroke-width="5"/><path d="M25,-80 Q20,-50 15,-60" fill="none" stroke="#8B0000" stroke-width="5"/></svg>';
    
    string constant CUTE_FACE = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="-50 -50 100 100"><circle cx="-15" cy="-10" r="5" fill="#000"/><circle cx="15" cy="-10" r="5" fill="#000"/><path d="M-10,10 Q0,20 10,10" fill="none" stroke="#000" stroke-width="2"/></svg>';
    string constant COOL_FACE = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="-50 -50 100 100"><rect x="-25" y="-15" width="20" height="10" rx="2" fill="#000"/><rect x="5" y="-15" width="20" height="10" rx="2" fill="#000"/><line x1="-5" y1="-10" x2="5" y2="-10" stroke="#000" stroke-width="2"/></svg>';
    string constant SLEEPY_FACE = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="-50 -50 100 100"><path d="M-20,-10 Q-15,-15 -10,-10" fill="none" stroke="#000" stroke-width="2"/><path d="M10,-10 Q15,-15 20,-10" fill="none" stroke="#000" stroke-width="2"/><circle cx="0" cy="15" r="3" fill="#000"/></svg>';
    
    string constant SPARKLES = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="-50 -50 100 100"><circle cx="-30" cy="-30" r="3" fill="#FFD700"><animate attributeName="opacity" values="1;0.3;1" dur="2s" repeatCount="indefinite"/></circle><circle cx="30" cy="-30" r="3" fill="#FFD700"><animate attributeName="opacity" values="0.3;1;0.3" dur="2s" repeatCount="indefinite"/></circle><circle cx="0" cy="30" r="3" fill="#FFD700"><animate attributeName="opacity" values="1;0.3;1" dur="1.5s" repeatCount="indefinite"/></circle></svg>';
    string constant HEART_AURA = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="-50 -50 100 100"><path d="M-20,-30 C-20,-40 -10,-45 0,-35 C10,-45 20,-40 20,-30 C20,-20 0,0 0,0 C0,0 -20,-20 -20,-30" fill="#FF69B4" opacity="0.3"><animate attributeName="opacity" values="0.3;0.6;0.3" dur="3s" repeatCount="indefinite"/></path></svg>';
    string constant RAINBOW_AURA = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="-50 -50 100 100"><circle cx="0" cy="0" r="45" fill="none" stroke="url(#rainbow)" stroke-width="3" opacity="0.5"><animate attributeName="r" values="45;50;45" dur="4s" repeatCount="indefinite"/></circle><defs><linearGradient id="rainbow"><stop offset="0%" stop-color="#FF0000"/><stop offset="16.66%" stop-color="#FF7F00"/><stop offset="33.33%" stop-color="#FFFF00"/><stop offset="50%" stop-color="#00FF00"/><stop offset="66.66%" stop-color="#0000FF"/><stop offset="83.33%" stop-color="#4B0082"/><stop offset="100%" stop-color="#9400D3"/></linearGradient></defs></svg>';

    // Body types
    string constant ROUND_BODY = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="-50 -50 100 100"><circle cx="0" cy="0" r="40" fill="#FFE4B5" stroke="#000" stroke-width="2"/></svg>';
    string constant CHUBBY_BODY = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="-50 -50 100 100"><ellipse cx="0" cy="5" rx="35" ry="40" fill="#FFDAB9" stroke="#000" stroke-width="2"/></svg>';
    string constant SLIM_BODY = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="-50 -50 100 100"><ellipse cx="0" cy="0" rx="25" ry="40" fill="#F5DEB3" stroke="#000" stroke-width="2"/></svg>';

    function run() public {
        // Deploy renderer
        renderer = new AminalRenderer();
        
        // Deploy a mock GeneNFT for testing
        address owner = address(0x1234567890123456789012345678901234567890);
        geneNFT = new GeneNFT(owner, "Test Genes", "GENE", "");
        
        // Generate individual SVG files
        generateIndividualSVGs();
        
        // Generate composed Aminals
        generateComposedAminals();
        
        // Generate HTML gallery
        generateHTMLGallery();
    }

    function generateIndividualSVGs() private {
        // Output individual trait SVGs
        vm.writeFile("script/output/traits/dragon_wings.svg", DRAGON_WINGS);
        vm.writeFile("script/output/traits/angel_wings.svg", ANGEL_WINGS);
        vm.writeFile("script/output/traits/bat_wings.svg", BAT_WINGS);
        
        vm.writeFile("script/output/traits/fire_tail.svg", FIRE_TAIL);
        vm.writeFile("script/output/traits/lightning_tail.svg", LIGHTNING_TAIL);
        vm.writeFile("script/output/traits/fluffy_tail.svg", FLUFFY_TAIL);
        
        vm.writeFile("script/output/traits/bunny_ears.svg", BUNNY_EARS);
        vm.writeFile("script/output/traits/cat_ears.svg", CAT_EARS);
        vm.writeFile("script/output/traits/devil_horns.svg", DEVIL_HORNS);
        
        vm.writeFile("script/output/traits/cute_face.svg", CUTE_FACE);
        vm.writeFile("script/output/traits/cool_face.svg", COOL_FACE);
        vm.writeFile("script/output/traits/sleepy_face.svg", SLEEPY_FACE);
        
        vm.writeFile("script/output/traits/sparkles.svg", SPARKLES);
        vm.writeFile("script/output/traits/heart_aura.svg", HEART_AURA);
        vm.writeFile("script/output/traits/rainbow_aura.svg", RAINBOW_AURA);
        
        vm.writeFile("script/output/traits/round_body.svg", ROUND_BODY);
        vm.writeFile("script/output/traits/chubby_body.svg", CHUBBY_BODY);
        vm.writeFile("script/output/traits/slim_body.svg", SLIM_BODY);
    }

    function generateComposedAminals() private {
        // Generate and save composed Aminals
        
        // Plain Aminal
        string memory plainAminal = composeAminal(
            ROUND_BODY, "", "", "", "", "", "", ""
        );
        vm.writeFile("script/output/aminals/plain_aminal.svg", plainAminal);
        
        // Bunny
        string memory bunny = composeAminal(
            CHUBBY_BODY, "", "", "", BUNNY_EARS, CUTE_FACE, "", ""
        );
        vm.writeFile("script/output/aminals/bunny.svg", bunny);
        
        // Cat
        string memory cat = composeAminal(
            SLIM_BODY, "", "", FLUFFY_TAIL, CAT_EARS, SLEEPY_FACE, "", ""
        );
        vm.writeFile("script/output/aminals/cat.svg", cat);
        
        // Fire Dragon
        string memory fireDragon = composeAminal(
            ROUND_BODY, DRAGON_WINGS, "", FIRE_TAIL, DEVIL_HORNS, COOL_FACE, "", ""
        );
        vm.writeFile("script/output/aminals/fire_dragon.svg", fireDragon);
        
        // Angel Bunny
        string memory angelBunny = composeAminal(
            CHUBBY_BODY, ANGEL_WINGS, "", "", BUNNY_EARS, CUTE_FACE, "", SPARKLES
        );
        vm.writeFile("script/output/aminals/angel_bunny.svg", angelBunny);
        
        // Demon Cat
        string memory demonCat = composeAminal(
            SLIM_BODY, BAT_WINGS, "", LIGHTNING_TAIL, DEVIL_HORNS, COOL_FACE, "", ""
        );
        vm.writeFile("script/output/aminals/demon_cat.svg", demonCat);
        
        // Sparkle Bunny
        string memory sparkleBunny = composeAminal(
            CHUBBY_BODY, "", "", FLUFFY_TAIL, BUNNY_EARS, CUTE_FACE, "", SPARKLES
        );
        vm.writeFile("script/output/aminals/sparkle_bunny.svg", sparkleBunny);
        
        // Love Cat
        string memory loveCat = composeAminal(
            ROUND_BODY, "", "", FLUFFY_TAIL, CAT_EARS, CUTE_FACE, "", HEART_AURA
        );
        vm.writeFile("script/output/aminals/love_cat.svg", loveCat);
        
        // Rainbow Dragon
        string memory rainbowDragon = composeAminal(
            ROUND_BODY, DRAGON_WINGS, "", LIGHTNING_TAIL, DEVIL_HORNS, COOL_FACE, "", RAINBOW_AURA
        );
        vm.writeFile("script/output/aminals/rainbow_dragon.svg", rainbowDragon);
        
        // Celestial Angel
        string memory celestialAngel = composeAminal(
            SLIM_BODY, ANGEL_WINGS, "", "", BUNNY_EARS, SLEEPY_FACE, "", string.concat(SPARKLES, RAINBOW_AURA)
        );
        vm.writeFile("script/output/aminals/celestial_angel.svg", celestialAngel);
    }

    function composeAminal(
        string memory body,
        string memory back,
        string memory arm,
        string memory tail,
        string memory ears,
        string memory face,
        string memory mouth,
        string memory misc
    ) private view returns (string memory) {
        string memory composition = "";
        
        // Add body base layer
        if (bytes(body).length > 0) {
            composition = string.concat(
                composition,
                GeneRenderer.svgImage(50, 50, 100, 100, body)
            );
        } else {
            // Default body
            composition = GeneRenderer.svgImage(
                50, 50, 100, 100,
                '<svg xmlns="http://www.w3.org/2000/svg" viewBox="-50 -50 100 100"><circle cx="0" cy="0" r="40" fill="#FFE4B5" stroke="#000" stroke-width="2"/></svg>'
            );
        }
        
        // Layer other traits
        if (bytes(back).length > 0) {
            composition = string.concat(composition, GeneRenderer.svgImage(0, 0, 200, 200, back));
        }
        if (bytes(tail).length > 0) {
            composition = string.concat(composition, GeneRenderer.svgImage(100, 100, 60, 80, tail));
        }
        if (bytes(ears).length > 0) {
            composition = string.concat(composition, GeneRenderer.svgImage(50, 0, 100, 60, ears));
        }
        if (bytes(face).length > 0) {
            composition = string.concat(composition, GeneRenderer.svgImage(60, 60, 80, 80, face));
        }
        if (bytes(mouth).length > 0) {
            composition = string.concat(composition, GeneRenderer.svgImage(70, 90, 60, 40, mouth));
        }
        if (bytes(arm).length > 0) {
            composition = string.concat(composition, GeneRenderer.svgImage(20, 70, 160, 60, arm));
        }
        if (bytes(misc).length > 0) {
            composition = string.concat(composition, GeneRenderer.svgImage(0, 0, 200, 200, misc));
        }
        
        return GeneRenderer.svg("0 0 200 200", composition);
    }

    function generateHTMLGallery() private {
        string memory html = string.concat(
            '<!DOCTYPE html>\n',
            '<html lang="en">\n',
            '<head>\n',
            '  <meta charset="UTF-8">\n',
            '  <meta name="viewport" content="width=device-width, initial-scale=1.0">\n',
            '  <title>Aminal Renderings Gallery</title>\n',
            '  <style>\n',
            '    body { font-family: Arial, sans-serif; background: #f0f0f0; padding: 20px; }\n',
            '    .container { max-width: 1200px; margin: 0 auto; }\n',
            '    h1, h2 { text-align: center; color: #333; }\n',
            '    .grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(200px, 1fr)); gap: 20px; margin: 40px 0; }\n',
            '    .item { background: white; border-radius: 8px; padding: 15px; text-align: center; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }\n',
            '    .item img { width: 100%; height: auto; }\n',
            '    .item h3 { margin: 10px 0 5px; font-size: 16px; }\n',
            '    .section { margin: 60px 0; }\n',
            '  </style>\n',
            '</head>\n',
            '<body>\n',
            '  <div class="container">\n',
            '    <h1>Aminal Renderings Gallery</h1>\n'
        );

        // Traits section
        html = string.concat(html,
            '    <div class="section">\n',
            '      <h2>Individual Traits</h2>\n',
            '      <div class="grid">\n',
            '        <div class="item"><img src="traits/dragon_wings.svg" alt="Dragon Wings"><h3>Dragon Wings</h3></div>\n',
            '        <div class="item"><img src="traits/angel_wings.svg" alt="Angel Wings"><h3>Angel Wings</h3></div>\n',
            '        <div class="item"><img src="traits/bat_wings.svg" alt="Bat Wings"><h3>Bat Wings</h3></div>\n',
            '        <div class="item"><img src="traits/fire_tail.svg" alt="Fire Tail"><h3>Fire Tail</h3></div>\n',
            '        <div class="item"><img src="traits/lightning_tail.svg" alt="Lightning Tail"><h3>Lightning Tail</h3></div>\n',
            '        <div class="item"><img src="traits/fluffy_tail.svg" alt="Fluffy Tail"><h3>Fluffy Tail</h3></div>\n',
            '        <div class="item"><img src="traits/bunny_ears.svg" alt="Bunny Ears"><h3>Bunny Ears</h3></div>\n',
            '        <div class="item"><img src="traits/cat_ears.svg" alt="Cat Ears"><h3>Cat Ears</h3></div>\n',
            '        <div class="item"><img src="traits/devil_horns.svg" alt="Devil Horns"><h3>Devil Horns</h3></div>\n',
            '        <div class="item"><img src="traits/cute_face.svg" alt="Cute Face"><h3>Cute Face</h3></div>\n',
            '        <div class="item"><img src="traits/cool_face.svg" alt="Cool Face"><h3>Cool Face</h3></div>\n',
            '        <div class="item"><img src="traits/sleepy_face.svg" alt="Sleepy Face"><h3>Sleepy Face</h3></div>\n',
            '        <div class="item"><img src="traits/sparkles.svg" alt="Sparkles"><h3>Sparkles</h3></div>\n',
            '        <div class="item"><img src="traits/heart_aura.svg" alt="Heart Aura"><h3>Heart Aura</h3></div>\n',
            '        <div class="item"><img src="traits/rainbow_aura.svg" alt="Rainbow Aura"><h3>Rainbow Aura</h3></div>\n',
            '      </div>\n',
            '    </div>\n'
        );

        // Composed Aminals section
        html = string.concat(html,
            '    <div class="section">\n',
            '      <h2>Composed Aminals</h2>\n',
            '      <div class="grid">\n',
            '        <div class="item"><img src="aminals/plain_aminal.svg" alt="Plain Aminal"><h3>Plain Aminal</h3></div>\n',
            '        <div class="item"><img src="aminals/bunny.svg" alt="Bunny"><h3>Bunny</h3></div>\n',
            '        <div class="item"><img src="aminals/cat.svg" alt="Cat"><h3>Cat</h3></div>\n',
            '        <div class="item"><img src="aminals/fire_dragon.svg" alt="Fire Dragon"><h3>Fire Dragon</h3></div>\n',
            '        <div class="item"><img src="aminals/angel_bunny.svg" alt="Angel Bunny"><h3>Angel Bunny</h3></div>\n',
            '        <div class="item"><img src="aminals/demon_cat.svg" alt="Demon Cat"><h3>Demon Cat</h3></div>\n',
            '        <div class="item"><img src="aminals/sparkle_bunny.svg" alt="Sparkle Bunny"><h3>Sparkle Bunny</h3></div>\n',
            '        <div class="item"><img src="aminals/love_cat.svg" alt="Love Cat"><h3>Love Cat</h3></div>\n',
            '        <div class="item"><img src="aminals/rainbow_dragon.svg" alt="Rainbow Dragon"><h3>Rainbow Dragon</h3></div>\n',
            '        <div class="item"><img src="aminals/celestial_angel.svg" alt="Celestial Angel"><h3>Celestial Angel</h3></div>\n',
            '      </div>\n',
            '    </div>\n'
        );

        html = string.concat(html,
            '  </div>\n',
            '</body>\n',
            '</html>\n'
        );

        vm.writeFile("script/output/gallery.html", html);
    }
}