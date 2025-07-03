// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {AminalVRGDA} from "src/AminalVRGDA.sol";
import {toWadUnsafe} from "lib/VRGDAs/lib/solmate/src/utils/SignedWadMath.sol";

contract DebugEnergy is Script {
    function run() public {
        AminalVRGDA vrgda = new AminalVRGDA(
            int256(0.0001 ether), // 0.0001 ETH per energy unit
            0.1e18,               // 10% decay
            1000e18               // 1000 units per "time"
        );
        
        // Test at 0 energy
        console.log("At 0 energy:");
        uint256 price0 = vrgda.getEnergyConversionRate(0);
        console.log("Price:", price0);
        console.log("Target sale time for 0:", uint256(vrgda.getTargetSaleTime(0)));
        
        // Test at 999 energy
        console.log("\nAt 999 energy:");
        uint256 price999 = vrgda.getEnergyConversionRate(999);
        console.log("Price:", price999);
        console.log("Target sale time for 999:", uint256(vrgda.getTargetSaleTime(toWadUnsafe(999))));
        console.log("Target sale time for 1000:", uint256(vrgda.getTargetSaleTime(toWadUnsafe(1000))));
        
        // Test getVRGDAPrice directly
        console.log("\nDirect VRGDA price test:");
        int256 energyAsTime = toWadUnsafe(999);
        console.log("Energy as time WAD:", uint256(energyAsTime));
        
        try vrgda.getVRGDAPrice(energyAsTime, 999) returns (uint256 p) {
            console.log("Direct price call succeeded:", p);
        } catch {
            console.log("Direct price call failed");
        }
    }
}