// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IGenes
 * @dev Interface defining the common gene structure for Aminals
 * @dev This interface standardizes gene representation across the ecosystem
 */
interface IGenes {
    /// @dev Struct defining all possible genes for an Aminal
    /// @notice These genes define the unique characteristics of each Aminal
    struct Genes {
        string back;    // Back genes (wings, shell, etc.)
        string arm;     // Arm genes
        string tail;    // Tail genes
        string ears;    // Ear genes
        string body;    // Body genes
        string face;    // Face genes
        string mouth;   // Mouth genes
        string misc;    // Additional unique genes
    }
}