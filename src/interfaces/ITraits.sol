// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ITraits
 * @dev Interface defining the common trait structure for Aminals and GeneNFTs
 * @dev This interface standardizes trait representation across the ecosystem
 */
interface ITraits {
    /// @dev Struct defining all possible traits for an Aminal
    /// @notice These traits define the unique characteristics of each Aminal
    struct Traits {
        string back;    // Back features (wings, shell, etc.)
        string arm;     // Arm characteristics
        string tail;    // Tail type and features
        string ears;    // Ear shape and style
        string body;    // Body type and characteristics
        string face;    // Facial features
        string mouth;   // Mouth and expression
        string misc;    // Additional unique features
    }
}