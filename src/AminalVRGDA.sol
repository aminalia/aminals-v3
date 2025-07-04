// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {LinearVRGDA} from "lib/VRGDAs/src/LinearVRGDA.sol";
import {toWadUnsafe, wadDiv} from "lib/VRGDAs/lib/solmate/src/utils/SignedWadMath.sol";

/**
 * @title AminalVRGDA
 * @notice A LinearVRGDA implementation for Aminal love mechanics
 * @dev Uses energy level to determine how much love is received per ETH
 * @dev More energy = less love per ETH (diminishing returns)
 * @dev Less energy = more love per ETH (increased efficiency)
 */
contract AminalVRGDA is LinearVRGDA {
    /// @notice Fixed rate of energy gained per ETH (not affected by VRGDA)
    uint256 public constant ENERGY_PER_ETH = 10000; // 1 ETH = 10,000 energy units
    
    /// @notice Constructor to set up the VRGDA parameters for love calculation
    /// @dev We repurpose the VRGDA to calculate love based on energy level
    /// @param _targetPrice The base ETH amount for pricing (in wei)
    /// @param _priceDecayPercent How much the price decays when below target (scaled by 1e18)
    /// @param _perTimeUnit Energy units per "time unit" - controls curve steepness (scaled by 1e18)
    constructor(
        int256 _targetPrice,
        int256 _priceDecayPercent,
        int256 _perTimeUnit
    ) LinearVRGDA(_targetPrice, _priceDecayPercent, _perTimeUnit) {}

    /**
     * @notice Calculate how much love is gained for a given ETH amount
     * @dev As current energy increases, the love gained per ETH decreases
     * @param currentEnergy Current energy level of the Aminal
     * @param ethAmount Amount of ETH being sent (in wei)
     * @return loveGained Amount of love that will be gained
     */
    function getLoveForETH(
        uint256 currentEnergy,
        uint256 ethAmount
    ) public view returns (uint256 loveGained) {
        if (ethAmount == 0) return 0;
        
        // For VRGDA to work properly, we need to pass consistent values
        // We'll use currentEnergy as both time and sold amount
        // This creates the effect where more energy = higher price = less love
        uint256 currentPrice = getVRGDAPrice(toWadUnsafe(currentEnergy), currentEnergy);
        
        // Simple formula: love = ethAmount * basePrice / currentPrice
        // When currentPrice is low (low energy), more love per ETH
        // When currentPrice is high (high energy), less love per ETH
        // Ensure currentPrice is never 0 to avoid division by zero
        if (currentPrice == 0) {
            currentPrice = 1; // Minimum price of 1 wei
        }
        loveGained = (ethAmount * uint256(targetPrice)) / currentPrice;
    }

    /**
     * @notice Get the current love multiplier based on energy level
     * @dev Returns how much love is gained per 1 ETH
     * @param currentEnergy Current energy level
     * @return The love amount gained per 1 ETH (in wei)
     */
    function getLoveMultiplier(uint256 currentEnergy) public view returns (uint256) {
        return getLoveForETH(currentEnergy, 1 ether);
    }
}