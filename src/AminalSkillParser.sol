// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title AminalSkillParser
 * @notice Library for parsing skill return data intelligently
 * @dev Detects common patterns and defaults non-uint256 values to 1
 */
library AminalSkillParser {
    /**
     * @notice Parse return data from a skill call to extract energy cost
     * @param returnData The raw return data from the skill call
     * @return energyCost The parsed energy cost (defaults to 1 for non-uint256)
     */
    function parseEnergyCost(bytes memory returnData) internal pure returns (uint256 energyCost) {
        // Default cost
        energyCost = 1;
        
        // Need at least 32 bytes to parse
        if (returnData.length < 32) {
            return energyCost;
        }
        
        // Read the first 32 bytes
        uint256 firstWord;
        assembly {
            firstWord := mload(add(returnData, 0x20))
        }
        
        // Check for common patterns that indicate non-uint256 returns
        
        // 1. Dynamic type check: offset pointer (usually 0x20 for single dynamic return)
        if (firstWord == 0x20 && returnData.length > 32) {
            // This is likely a dynamic type (string, bytes, array)
            return 1;
        }
        
        // 2. Multiple return values detection
        if (returnData.length >= 96) { // At least 3 words
            // Check if second word looks like it could be an offset (0x40 or 0x60)
            uint256 secondWord;
            assembly {
                secondWord := mload(add(returnData, 0x40))
            }
            if (secondWord == 0x40 || secondWord == 0x60) {
                // Likely has dynamic types in the return
                return 1;
            }
        }
        
        // 3. Boolean check: true (1) or false (0)
        if (firstWord == 0 || firstWord == 1) {
            return firstWord == 0 ? 1 : firstWord; // 0 becomes 1, 1 stays 1
        }
        
        // 4. Address check: addresses when cast to uint256 are very large
        // Addresses are 20 bytes, so when interpreted as uint256 they're huge
        // Check if the value looks like an address (large but within address range)
        if (firstWord > type(uint160).max && firstWord <= type(uint256).max) {
            // Likely an address or negative number
            return 1;
        }
        
        // 5. Reasonable cost check: assume costs should be under 1 million
        if (firstWord > 1000000) {
            // Unreasonably high, probably not a legitimate cost
            return 1;
        }
        
        
        // If we get here, treat it as a uint256 cost
        energyCost = firstWord;
        
        // Final safety check
        if (energyCost == 0) {
            energyCost = 1;
        }
        
        return energyCost;
    }
    
    /**
     * @notice Check if return data appears to be a simple uint256
     * @param returnData The raw return data
     * @return True if data appears to be a simple uint256
     */
    function looksLikeUint256(bytes memory returnData) internal pure returns (bool) {
        if (returnData.length != 32) {
            return false;
        }
        
        uint256 value;
        assembly {
            value := mload(add(returnData, 0x20))
        }
        
        // Check if it's a reasonable energy cost (1 to 1,000,000)
        return value >= 1 && value <= 1000000;
    }
}