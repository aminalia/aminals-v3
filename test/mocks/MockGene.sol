// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC721} from "lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import {IGene} from "src/interfaces/IGene.sol";

/**
 * @title MockGene
 * @notice Mock Gene contract for testing breeding with gene proposals
 */
contract MockGene is ERC721, IGene {
    mapping(uint256 => string) public gene;
    mapping(uint256 => string) public traitType;
    mapping(uint256 => string) public traitValue;
    
    uint256 public nextTokenId = 1;
    
    constructor() ERC721("MockGene", "MGENE") {}
    
    /**
     * @notice Mint a new gene with specific properties
     */
    function mint(
        address to,
        string memory svg,
        string memory _traitType,
        string memory _traitValue
    ) external returns (uint256 tokenId) {
        tokenId = nextTokenId++;
        _mint(to, tokenId);
        
        gene[tokenId] = svg;
        traitType[tokenId] = _traitType;
        traitValue[tokenId] = _traitValue;
    }
    
    /**
     * @notice Helper to create genes for testing
     */
    function createTestGenes() external {
        // Create various trait genes
        this.mint(msg.sender, "<svg>Rainbow Wings</svg>", "back", "Rainbow Wings");
        this.mint(msg.sender, "<svg>Crystal Wings</svg>", "back", "Crystal Wings");
        this.mint(msg.sender, "<svg>Laser Arms</svg>", "arm", "Laser Arms");
        this.mint(msg.sender, "<svg>Diamond Tail</svg>", "tail", "Diamond Tail");
        this.mint(msg.sender, "<svg>Antenna Ears</svg>", "ears", "Antenna Ears");
        this.mint(msg.sender, "<svg>Holographic Body</svg>", "body", "Holographic Body");
        this.mint(msg.sender, "<svg>Vampire Face</svg>", "face", "Vampire Face");
        this.mint(msg.sender, "<svg>Golden Mouth</svg>", "mouth", "Golden Mouth");
        this.mint(msg.sender, "<svg>Aura Glow</svg>", "misc", "Aura Glow");
    }
}