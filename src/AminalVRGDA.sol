// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {LinearVRGDA} from "lib/VRGDAs/src/LinearVRGDA.sol";
import {toWadUnsafe, wadDiv} from "lib/VRGDAs/lib/solmate/src/utils/SignedWadMath.sol";

/**
 * @title AminalVRGDA
 * @notice A LinearVRGDA implementation for Aminal feeding mechanics
 * @dev Uses energy level as a proxy for both time and units sold
 * @dev More energy = less love gained per ETH (diminishing returns)
 * @dev Less energy = more love gained per ETH (increased efficiency)
 */
contract AminalVRGDA is LinearVRGDA {
    /// @notice Constructor to set up the VRGDA parameters for Aminal feeding
    /// @dev We repurpose the VRGDA to use energy as both time and sold units
    /// @param _targetPrice The target ETH amount needed for 1 energy unit (in wei)
    /// @param _priceDecayPercent How much the price decays when below target (scaled by 1e18)
    /// @param _perTimeUnit Energy units per "time unit" - controls price curve steepness (scaled by 1e18)
    constructor(
        int256 _targetPrice,
        int256 _priceDecayPercent,
        int256 _perTimeUnit
    ) LinearVRGDA(_targetPrice, _priceDecayPercent, _perTimeUnit) {}

    /**
     * @notice Calculate how much energy is gained for a given ETH amount
     * @dev As current energy increases, the energy gained per ETH decreases
     * @param currentEnergy Current energy level of the Aminal
     * @param ethAmount Amount of ETH being sent (in wei)
     * @return energyGained Amount of energy that will be gained
     */
    function getEnergyForETH(
        uint256 currentEnergy,
        uint256 ethAmount
    ) public view returns (uint256 energyGained) {
        if (ethAmount == 0) return 0;
        
        // We use energy as a proxy for both time elapsed and units sold
        // For the VRGDA formula to work properly:
        // - We pass energy/perTimeUnit as "time" (how far along we are)
        // - We pass currentEnergy as "sold" (units already sold)
        // This creates the desired effect: more energy = higher price = less energy per ETH
        
        // Calculate effective "time" based on energy level
        // If perTimeUnit = 1000, then 1000 energy = 1 time unit
        int256 effectiveTime = wadDiv(toWadUnsafe(currentEnergy), perTimeUnit);
        
        // Get the current price based on energy level
        uint256 currentPrice = getVRGDAPrice(effectiveTime, currentEnergy);
        
        // Calculate energy gained: ETH amount / price per unit
        energyGained = ethAmount / currentPrice;
        
        // Ensure at least 1 energy is gained if any ETH is sent
        if (energyGained == 0 && ethAmount > 0) {
            energyGained = 1;
        }
    }

    /**
     * @notice Get the current ETH to energy conversion rate based on energy level
     * @dev Returns how much ETH is needed for 1 unit of energy
     * @param currentEnergy Current energy level
     * @return The ETH amount needed for 1 energy unit (in wei)
     */
    function getEnergyConversionRate(uint256 currentEnergy) public view returns (uint256) {
        int256 effectiveTime = wadDiv(toWadUnsafe(currentEnergy), perTimeUnit);
        return getVRGDAPrice(effectiveTime, currentEnergy);
    }
}