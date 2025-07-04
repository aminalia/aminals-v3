// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {LogisticVRGDA} from "lib/VRGDAs/src/LogisticVRGDA.sol";
import {toWadUnsafe, wadDiv} from "lib/VRGDAs/lib/solmate/src/utils/SignedWadMath.sol";

/**
 * @title AminalVRGDA
 * @notice Logistic VRGDA implementation that modulates love received based on energy level
 * @dev Energy gain is fixed (10k per ETH), but love varies inversely with energy using a smooth S-curve
 * @dev Thresholds prevent extreme VRGDA values: <10 energy (0.001 ETH) = 100x love, >10M (1000 ETH) = 0.001x love
 * @dev Between thresholds, Logistic VRGDA provides smooth diminishing returns as energy increases
 */
contract AminalVRGDA is LogisticVRGDA {
    /// @notice Fixed rate of energy gained per ETH (not affected by VRGDA)
    uint256 public constant ENERGY_PER_ETH = 10000; // 1 ETH = 10,000 energy units
    
    /// @notice Maximum love multiplier (100x ETH sent)
    uint256 public constant MAX_LOVE_MULTIPLIER = 100 ether;
    
    /// @notice Minimum love multiplier (0.001x ETH sent)
    uint256 public constant MIN_LOVE_MULTIPLIER = 0.001 ether;
    
    /// @notice Constructor to set up the VRGDA parameters for love calculation
    /// @dev We repurpose the Logistic VRGDA to calculate love based on energy level
    /// @param _targetPrice The base ETH amount for pricing (in wei)
    /// @param _priceDecayPercent How much the price decays when below target (scaled by 1e18)
    /// @param _logisticAsymptote The asymptotic maximum energy level (scaled by 1e18)
    /// @param _timeScale Controls how quickly the curve transitions (scaled by 1e18)
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
        } else if (currentEnergy > 10000000) {
            // High energy - give minimum love
            loveMultiplier = MIN_LOVE_MULTIPLIER;
        } else {
            // Use VRGDA for normal energy levels
            // Scale energy down to prevent overflow
            // Divide by 1000 to work with smaller numbers (1 = 0.001 ETH worth of energy)
            uint256 scaledEnergy = currentEnergy / 1000;
            
            // Ensure we have at least 1 unit to avoid issues with 0
            if (scaledEnergy == 0) scaledEnergy = 1;
            
            // For love calculation, we want the inverse relationship:
            // High energy should give low price (less love), low energy should give high price (more love)
            // So we use a large number minus the current energy to invert the curve
            uint256 invertedEnergy = 10000 > scaledEnergy ? 10000 - scaledEnergy : 1;
            
            uint256 currentPrice = getVRGDAPrice(toWadUnsafe(invertedEnergy), invertedEnergy);
            
            if (currentPrice == 0) {
                // If price is 0, use minimum multiplier
                loveMultiplier = MIN_LOVE_MULTIPLIER;
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