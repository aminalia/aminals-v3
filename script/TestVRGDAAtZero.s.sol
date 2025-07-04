// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {AminalVRGDA} from "src/AminalVRGDA.sol";
import {toWadUnsafe} from "lib/VRGDAs/lib/solmate/src/utils/SignedWadMath.sol";

contract TestVRGDAAtZero is Script {
    function run() public {
        AminalVRGDA vrgda = new AminalVRGDA(
            int256(0.5 ether), 
            0.5e18,
            10000e18
        );
        
        console.log("Target price:", uint256(vrgda.targetPrice()));
        
        // Test at 0 energy
        uint256 price0 = vrgda.getVRGDAPrice(toWadUnsafe(0), 0);
        console.log("VRGDA price at (0,0):", price0);
        
        // Test love multiplier
        uint256 love0 = vrgda.getLoveForETH(0, 0.1 ether);
        console.log("Love for 0.1 ETH at 0 energy:", love0);
        
        uint256 multiplier0 = vrgda.getLoveMultiplier(0);
        console.log("Love multiplier at 0 energy:", multiplier0);
    }
}