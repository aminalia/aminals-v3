// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {VRGDA} from "lib/VRGDAs/src/VRGDA.sol";
import {wadMul} from "lib/VRGDAs/lib/solmate/src/utils/SignedWadMath.sol";

/**
 * @title Square Root Variable Rate Gradual Dutch Auction
 * @notice VRGDA with a square root issuance curve: f(t) = √t
 * @dev At time 1 we've sold 1 unit, at time 4 we've sold 2 units, at time 9 we've sold 3 units, etc.
 * @dev The inverse function is f^(-1)(n) = n², which gives us the target sale time
 */
abstract contract SquareRootVRGDA is VRGDA {
    /**
     * @notice Sets pricing parameters for the VRGDA
     * @param _targetPrice The target price for a token if sold on pace, scaled by 1e18
     * @param _priceDecayPercent The percent price decays per unit of time with no sales, scaled by 1e18
     */
    constructor(
        int256 _targetPrice,
        int256 _priceDecayPercent
    ) VRGDA(_targetPrice, _priceDecayPercent) {}

    /**
     * @dev Given a number of tokens sold, return the target time that number of tokens should be sold by
     * @dev For square root VRGDA: target time = n² (since f(t) = √t, so f^(-1)(n) = n²)
     * @param sold A number of tokens sold, scaled by 1e18, to get the corresponding target sale time for
     * @return The target time the tokens should be sold by, scaled by 1e18
     */
    function getTargetSaleTime(int256 sold) public view virtual override returns (int256) {
        // Square the number of tokens sold to get the target time
        // To prevent overflow, we scale down before squaring
        // Since sold is in WAD format (1e18), we divide by 1e9 before multiplying
        // This gives us (sold/1e9)² * 1e18 = sold² / 1e18
        int256 scaledSold = sold / 1e9;
        return scaledSold * scaledSold * 1e18;
    }
}