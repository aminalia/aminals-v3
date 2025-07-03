// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {LinearVRGDA} from "lib/VRGDAs/src/LinearVRGDA.sol";
import {wadMul, wadDiv, toWadUnsafe, unsafeWadDiv, unsafeWadMul} from "lib/VRGDAs/lib/solmate/src/utils/SignedWadMath.sol";

/**
 * @title AminalVRGDA
 * @notice A LinearVRGDA implementation for Aminal feeding mechanics
 * @dev As Aminals gain more energy, the amount of energy gained per ETH decreases
 * @dev This creates diminishing returns - early feeding gives more energy, later feeding gives less
 */
contract AminalVRGDA is LinearVRGDA {
    /// @notice Constructor to set up the VRGDA parameters for Aminal feeding
    /// @dev We use VRGDA inversely - price represents ETH needed per energy unit
    /// @param _targetPrice The target ETH amount needed for 1 energy unit when on schedule (in wei)
    /// @param _priceDecayPercent How much the ETH requirement decays when behind schedule (scaled by 1e18)
    /// @param _perTimeUnit Target energy units to gain per time unit (scaled by 1e18)
    constructor(
        int256 _targetPrice,
        int256 _priceDecayPercent,
        int256 _perTimeUnit
    ) LinearVRGDA(_targetPrice, _priceDecayPercent, _perTimeUnit) {}

    /**
     * @notice Calculate how much energy is gained for a given ETH amount
     * @dev As total energy increases, the energy gained per ETH decreases
     * @param timeSinceStart Time since the Aminal started feeding (scaled by 1e18)
     * @param currentEnergy Current total energy the Aminal has
     * @param ethAmount Amount of ETH being sent (in wei)
     * @return energyGained Amount of energy that will be gained
     */
    function getEnergyForETH(
        int256 timeSinceStart,
        uint256 currentEnergy,
        uint256 ethAmount
    ) public view returns (uint256 energyGained) {
        if (ethAmount == 0) return 0;
        
        // Get the current price (ETH per energy unit) based on VRGDA
        uint256 currentPrice = getVRGDAPrice(timeSinceStart, currentEnergy);
        
        // Calculate energy gained: ETH amount / price per unit
        energyGained = ethAmount / currentPrice;
        
        // Ensure at least 1 energy is gained if any ETH is sent
        if (energyGained == 0 && ethAmount > 0) {
            energyGained = 1;
        }
    }

    /**
     * @notice Get the current ETH to energy conversion rate
     * @dev Returns how much ETH is needed for 1 unit of energy
     * @param timeSinceStart Time since feeding started (scaled by 1e18)
     * @param currentEnergy Current total energy
     * @return The ETH amount needed for 1 energy unit (in wei)
     */
    function getEnergyConversionRate(
        int256 timeSinceStart,
        uint256 currentEnergy
    ) public view returns (uint256) {
        return getVRGDAPrice(timeSinceStart, currentEnergy);
    }
}