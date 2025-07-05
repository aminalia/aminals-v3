// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {AminalRenderer} from "src/AminalRenderer.sol";
import {GeneRenderer} from "src/GeneRenderer.sol";
import {Aminal} from "src/Aminal.sol";
import {LibString} from "solady/utils/LibString.sol";
import {Base64} from "solady/utils/Base64.sol";

/**
 * @title GenerateSampleCombinations
 * @dev Script to generate sample Aminal combinations and output as HTML
 * @notice Run with: forge script script/GenerateSampleCombinations.s.sol -vvv
 */
contract GenerateSampleCombinations is Script {
    using LibString for string;
    using LibString for uint256;

    AminalRenderer public renderer;

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

        // Start HTML
        console.log("<!DOCTYPE html>");
        console.log("<html lang='en'>");
        console.log("<head>");
        console.log("  <meta charset='UTF-8'>");
        console.log("  <meta name='viewport' content='width=device-width, initial-scale=1.0'>");
        console.log("  <title>Aminal Combinations</title>");
        console.log("  <style>");
        console.log("    body { font-family: Arial, sans-serif; background: #f0f0f0; padding: 20px; }");
        console.log("    .container { max-width: 1200px; margin: 0 auto; }");
        console.log("    .grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(300px, 1fr)); gap: 20px; }");
        console.log("    .aminal-card { background: white; border-radius: 8px; padding: 15px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }");
        console.log("    .aminal-svg { width: 100%; height: auto; border: 1px solid #ddd; border-radius: 4px; }");
        console.log("    .aminal-name { font-weight: bold; margin-top: 10px; text-align: center; }");
        console.log("    .traits { font-size: 12px; color: #666; margin-top: 5px; }");
        console.log("    h1 { text-align: center; color: #333; }");
        console.log("    .section { margin: 40px 0; }");
        console.log("    h2 { color: #555; border-bottom: 2px solid #ddd; padding-bottom: 10px; }");
        console.log("  </style>");
        console.log("</head>");
        console.log("<body>");
        console.log("  <div class='container'>");
        console.log("    <h1>Aminal Trait Combinations</h1>");

        // Generate different themed combinations
        generateBasicSet();
        generateFantasySet();
        generateCuteSet();
        generateMysticalSet();

        // Close HTML
        console.log("  </div>");
        console.log("</body>");
        console.log("</html>");
    }

    function generateBasicSet() private {
        console.log("    <div class='section'>");
        console.log("      <h2>Basic Aminals</h2>");
        console.log("      <div class='grid'>");

        // Plain Aminal
        createAminalCard(
            "Plain Aminal",
            ROUND_BODY,
            "", "", "", "", "", "", ""
        );

        // Simple combinations
        createAminalCard(
            "Bunny",
            CHUBBY_BODY,
            "", "", "", BUNNY_EARS, CUTE_FACE, "", ""
        );

        createAminalCard(
            "Cat",
            SLIM_BODY,
            "", "", FLUFFY_TAIL, CAT_EARS, SLEEPY_FACE, "", ""
        );

        console.log("      </div>");
        console.log("    </div>");
    }

    function generateFantasySet() private {
        console.log("    <div class='section'>");
        console.log("      <h2>Fantasy Aminals</h2>");
        console.log("      <div class='grid'>");

        // Dragon
        createAminalCard(
            "Fire Dragon",
            ROUND_BODY,
            DRAGON_WINGS, "", FIRE_TAIL, DEVIL_HORNS, COOL_FACE, "", ""
        );

        // Angel
        createAminalCard(
            "Angel Bunny",
            CHUBBY_BODY,
            ANGEL_WINGS, "", "", BUNNY_EARS, CUTE_FACE, "", SPARKLES
        );

        // Demon Cat
        createAminalCard(
            "Demon Cat",
            SLIM_BODY,
            BAT_WINGS, "", LIGHTNING_TAIL, DEVIL_HORNS, COOL_FACE, "", ""
        );

        console.log("      </div>");
        console.log("    </div>");
    }

    function generateCuteSet() private {
        console.log("    <div class='section'>");
        console.log("      <h2>Cute Aminals</h2>");
        console.log("      <div class='grid'>");

        // Sparkle Bunny
        createAminalCard(
            "Sparkle Bunny",
            CHUBBY_BODY,
            "", "", FLUFFY_TAIL, BUNNY_EARS, CUTE_FACE, "", SPARKLES
        );

        // Love Cat
        createAminalCard(
            "Love Cat",
            ROUND_BODY,
            "", "", FLUFFY_TAIL, CAT_EARS, CUTE_FACE, "", HEART_AURA
        );

        console.log("      </div>");
        console.log("    </div>");
    }

    function generateMysticalSet() private {
        console.log("    <div class='section'>");
        console.log("      <h2>Mystical Aminals</h2>");
        console.log("      <div class='grid'>");

        // Rainbow Dragon
        createAminalCard(
            "Rainbow Dragon",
            ROUND_BODY,
            DRAGON_WINGS, "", LIGHTNING_TAIL, DEVIL_HORNS, COOL_FACE, "", RAINBOW_AURA
        );

        // Celestial Angel
        createAminalCard(
            "Celestial Angel",
            SLIM_BODY,
            ANGEL_WINGS, "", "", BUNNY_EARS, SLEEPY_FACE, "", string.concat(SPARKLES, RAINBOW_AURA)
        );

        console.log("      </div>");
        console.log("    </div>");
    }

    function createAminalCard(
        string memory name,
        string memory body,
        string memory back,
        string memory arm,
        string memory tail,
        string memory ears,
        string memory face,
        string memory mouth,
        string memory misc
    ) private {
        // Create gene references (mock addresses for preview)
        Aminal.GeneReference[8] memory genes;
        
        // Compose the SVG
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
        
        string memory finalSvg = GeneRenderer.svg("0 0 200 200", composition);
        
        // Output card
        console.log("        <div class='aminal-card'>");
        console.log(string.concat("          ", finalSvg));
        console.log(string.concat("          <div class='aminal-name'>", name, "</div>"));
        
        // List traits
        string memory traits = "          <div class='traits'>";
        if (bytes(body).length > 0) traits = string.concat(traits, "Body ");
        if (bytes(back).length > 0) traits = string.concat(traits, "Back ");
        if (bytes(tail).length > 0) traits = string.concat(traits, "Tail ");
        if (bytes(ears).length > 0) traits = string.concat(traits, "Ears ");
        if (bytes(face).length > 0) traits = string.concat(traits, "Face ");
        if (bytes(mouth).length > 0) traits = string.concat(traits, "Mouth ");
        if (bytes(arm).length > 0) traits = string.concat(traits, "Arm ");
        if (bytes(misc).length > 0) traits = string.concat(traits, "Misc ");
        traits = string.concat(traits, "</div>");
        
        console.log(traits);
        console.log("        </div>");
    }
}