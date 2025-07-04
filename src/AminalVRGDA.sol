// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {LinearVRGDA} from "lib/VRGDAs/src/LinearVRGDA.sol";
import {toWadUnsafe, wadDiv} from "lib/VRGDAs/lib/solmate/src/utils/SignedWadMath.sol";

/**
 * @title AminalVRGDA
 * @notice LinearVRGDA implementation that modulates love received based on energy level
 * @dev Energy gain is fixed (10k per ETH), but love varies inversely with energy
 * @dev Thresholds prevent extreme VRGDA values: <1k energy (0.1 ETH) = 2x love, >50k (5 ETH) = 0.1x love
 * @dev Between thresholds, VRGDA calculates love based on energy as proxy for time/sold
 */
contract AminalVRGDA is LinearVRGDA {
    /// @notice Fixed rate of energy gained per ETH (not affected by VRGDA)
    uint256 public constant ENERGY_PER_ETH = 10000; // 1 ETH = 10,000 energy units
    
    /// @notice Maximum love multiplier (2x ETH sent)
    uint256 public constant MAX_LOVE_MULTIPLIER = 2 ether;
    
    /// @notice Minimum love multiplier (0.1x ETH sent)
    uint256 public constant MIN_LOVE_MULTIPLIER = 0.1 ether;
    
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
        
        uint256 loveMultiplier;
        
        // Special cases for energy thresholds
        if (currentEnergy < 1000) {
            // Very low energy - give maximum love
            loveMultiplier = MAX_LOVE_MULTIPLIER;
        } else if (currentEnergy > 50000) {
            // High energy - give minimum love
            loveMultiplier = MIN_LOVE_MULTIPLIER;
        } else {
            // Use VRGDA for normal energy levels
            uint256 currentPrice = getVRGDAPrice(toWadUnsafe(currentEnergy), currentEnergy);
            
            if (currentPrice == 0) {
                // If price is 0, use maximum multiplier
                loveMultiplier = MAX_LOVE_MULTIPLIER;
            } else {
                loveMultiplier = (uint256(targetPrice) * 1 ether) / currentPrice;
            }
            
            // Apply bounds to keep multiplier reasonable
            if (loveMultiplier > MAX_LOVE_MULTIPLIER) {
                loveMultiplier = MAX_LOVE_MULTIPLIER;
            } else if (loveMultiplier < MIN_LOVE_MULTIPLIER) {
                loveMultiplier = MIN_LOVE_MULTIPLIER;
            }
        }
        
        // Calculate love gained
        loveGained = (ethAmount * loveMultiplier) / 1 ether;
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