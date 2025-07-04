// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {AminalVRGDA} from "src/AminalVRGDA.sol";

contract DebugMultiplier is Script {
    function run() public {
        AminalVRGDA vrgda = new AminalVRGDA(
            int256(0.5 ether), 
            0.5e18,
            10000e18
        );
        
        console.log("VRGDA prices at different energy levels:");
        uint256[] memory energies = new uint256[](5);
        energies[0] = 10000;
        energies[1] = 50000;
        energies[2] = 100000;
        energies[3] = 200000;
        energies[4] = 500000;
        
        for (uint i = 0; i < energies.length; i++) {
            uint256 energy = energies[i];
            uint256 price = vrgda.getVRGDAPrice(vrgda.toWadUnsafe(energy), energy);
            uint256 multiplier = vrgda.getLoveMultiplier(energy);
            console.log("Energy:", energy);
            console.log("  VRGDA price:", price);
            console.log("  Love multiplier:", multiplier);
        }
    }
}