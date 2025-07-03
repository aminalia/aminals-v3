// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {AminalVRGDA} from "src/AminalVRGDA.sol";

contract DebugVRGDA is Script {
    function run() public {
        AminalVRGDA vrgda = new AminalVRGDA(
            int256(0.0001 ether), 
            0.1e18, 
            1000e18
        );
        
        uint256 price = vrgda.getVRGDAPrice(0, 0);
        console.log("VRGDA price at start:", price);
        console.log("0.0001 ether:", uint256(0.0001 ether));
        console.log("0.0001 ether in WAD:", uint256(0.0001 ether) * 1e18);
        
        // Calculate energy for 0.01 ETH
        uint256 energy = vrgda.getEnergyForETH(0, 0, 0.01 ether);
        console.log("Energy for 0.01 ETH:", energy);
    }
}