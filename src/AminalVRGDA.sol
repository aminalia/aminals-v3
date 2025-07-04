// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {LogisticVRGDA} from "lib/VRGDAs/src/LogisticVRGDA.sol";
import {toWadUnsafe, wadDiv} from "lib/VRGDAs/lib/solmate/src/utils/SignedWadMath.sol";

/**
 * @title AminalVRGDA
 * @notice Logistic VRGDA implementation that modulates love received based on energy level
 * @dev Energy gain is fixed (10k per ETH), but love varies inversely with energy using a smooth S-curve
 * @dev Thresholds prevent extreme VRGDA values: <10 energy (0.001 ETH) = 10x love, >1M (100 ETH) = 0.1x love
 * @dev Between thresholds, VRGDA price increases with energy, which we invert to create decreasing love multipliers
 * @dev Uses moderate multiplier range (10x to 0.1x) to balance incentives without extreme values
 */
contract AminalVRGDA is LogisticVRGDA {
    /// @notice Fixed rate of energy gained per ETH (not affected by VRGDA)
    uint256 public constant ENERGY_PER_ETH = 10000; // 1 ETH = 10,000 energy units
    
    /// @notice Maximum love multiplier (10x ETH sent)
    uint256 public constant MAX_LOVE_MULTIPLIER = 10 ether;
    
    /// @notice Minimum love multiplier (0.1x ETH sent)
    uint256 public constant MIN_LOVE_MULTIPLIER = 0.1 ether;
    
    /// @notice Constructor to set up the VRGDA parameters for love calculation
    /// @dev Repurposes Logistic VRGDA where energy acts as both time and units sold
    /// @param _targetPrice The base ETH amount for pricing (in wei) - typically 1 ETH
    /// @param _priceDecayPercent Price decay when below target (scaled by 1e18) - affects curve steepness
    /// @param _logisticAsymptote Maximum units for S-curve (scaled by 1e18) - controls curve shape
    /// @param _timeScale Controls S-curve transition speed (scaled by 1e18) - affects smoothness
    constructor(
        int256 _targetPrice,
        int256 _priceDecayPercent,
        int256 _logisticAsymptote,
        int256 _timeScale
    ) LogisticVRGDA(_targetPrice, _priceDecayPercent, _logisticAsymptote, _timeScale) {}

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
        if (currentEnergy < 10) {
            // Very low energy - give maximum love
            loveMultiplier = MAX_LOVE_MULTIPLIER;
        } else if (currentEnergy > 1000000) {
            // High energy - give minimum love
            loveMultiplier = MIN_LOVE_MULTIPLIER;
        } else {
            // Use VRGDA for normal energy levels
            // Scale energy to work well with VRGDA
            uint256 scaledEnergy = currentEnergy / 10000; // 1 ETH = 1 unit
            
            // Get VRGDA price for current energy level
            // For Logistic VRGDA: price starts low and increases with "time" (energy)
            uint256 vrgdaPrice = getVRGDAPrice(toWadUnsafe(scaledEnergy), scaledEnergy);
            
            // Map VRGDA price to love multiplier with inverse relationship
            // As VRGDA price increases (energy increases), love multiplier decreases
            // This creates the desired diminishing returns for well-fed Aminals
            
            // VRGDA price DECREASES as energy increases (we're "ahead of schedule")
            // We want love multiplier to DECREASE as energy increases
            // So we need to invert the relationship
            
            if (vrgdaPrice == 0) {
                loveMultiplier = MIN_LOVE_MULTIPLIER; // Very high energy
            } else if (vrgdaPrice >= uint256(targetPrice)) {
                // Price at or above target = low energy = high multiplier
                loveMultiplier = MAX_LOVE_MULTIPLIER;
            } else {
                // Price below target = higher energy = lower multiplier
                // Map price range [0 to targetPrice] to multiplier range [MIN to MAX]
                // As price goes from targetPrice to 0, multiplier goes from MAX to MIN
                
                uint256 progress = (vrgdaPrice * 1 ether) / uint256(targetPrice);
                uint256 range = MAX_LOVE_MULTIPLIER - MIN_LOVE_MULTIPLIER;
                
                // Linear interpolation: high price (near target) = high multiplier
                loveMultiplier = MIN_LOVE_MULTIPLIER + (range * progress / 1 ether);
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