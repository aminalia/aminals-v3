// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC721} from "lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import {ERC721URIStorage} from "lib/openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {ERC721Enumerable} from "lib/openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

/**
 * @title GeneNFT
 * @dev Regular ERC721 NFT contract for trait-based NFTs that represent genetic components
 * @dev GeneNFTs are regular NFTs with standard ID schemes (1, 2, 3, etc.)
 */
contract GeneNFT is ERC721, ERC721URIStorage, ERC721Enumerable, Ownable {
    /// @dev Base URI for token metadata
    string public baseTokenURI;

    /// @dev Current token ID counter
    uint256 public currentTokenId;

    /// @dev Mapping from token ID to trait type (e.g., "BACK", "ARM", "TAIL")
    mapping(uint256 => string) public tokenTraitType;

    /// @dev Mapping from token ID to trait value (e.g., "Dragon Wings", "Fire Tail")
    mapping(uint256 => string) public tokenTraitValue;

    /// @dev Event emitted when a GeneNFT is created
    event GeneNFTCreated(
        uint256 indexed tokenId, address indexed owner, string traitType, string traitValue, string tokenURI
    );

    /// @dev Event emitted when base URI is updated
    event BaseURIUpdated(string newBaseURI);

    /// @dev Error thrown when providing invalid parameters
    error InvalidParameters();

    /**
     * @dev Constructor sets the collection details
     * @param owner The address that will own the contract
     * @param name The name of this GeneNFT collection
     * @param symbol The symbol for this GeneNFT collection
     * @param baseURI The base URI for token metadata
     */
    constructor(address owner, string memory name, string memory symbol, string memory baseURI)
        ERC721(name, symbol)
        Ownable(owner)
    {
        if (owner == address(0)) revert InvalidParameters();
        baseTokenURI = baseURI;
    }

    /**
     * @dev Mint a GeneNFT to the specified address with trait information
     * @param to The address that will receive the NFT
     * @param traitType The trait type this NFT represents (e.g., "BACK", "ARM")
     * @param traitValue The specific trait value (e.g., "Dragon Wings", "Fire Tail")
     * @param uri The URI for the token's metadata
     * @return tokenId The ID of the newly minted token
     */
    function mint(address to, string memory traitType, string memory traitValue, string memory uri)
        external
        onlyOwner
        returns (uint256)
    {
        if (to == address(0)) revert InvalidParameters();
        if (bytes(traitType).length == 0) revert InvalidParameters();
        if (bytes(traitValue).length == 0) revert InvalidParameters();

        currentTokenId++;
        uint256 tokenId = currentTokenId;

        tokenTraitType[tokenId] = traitType;
        tokenTraitValue[tokenId] = traitValue;

        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);

        emit GeneNFTCreated(tokenId, to, traitType, traitValue, uri);

        return tokenId;
    }

    /**
     * @dev Batch mint multiple GeneNFTs to specified addresses
     * @param recipients Array of addresses that will receive the NFTs
     * @param traitTypes Array of trait types for each NFT
     * @param traitValues Array of trait values for each NFT
     * @param uris Array of URIs for the tokens' metadata
     * @return tokenIds Array of IDs of the newly minted tokens
     */
    function batchMint(
        address[] memory recipients,
        string[] memory traitTypes,
        string[] memory traitValues,
        string[] memory uris
    ) external onlyOwner returns (uint256[] memory) {
        if (
            recipients.length != traitTypes.length || recipients.length != traitValues.length
                || recipients.length != uris.length || recipients.length == 0
        ) {
            revert InvalidParameters();
        }

        uint256[] memory tokenIds = new uint256[](recipients.length);

        for (uint256 i = 0; i < recipients.length; i++) {
            if (recipients[i] == address(0)) revert InvalidParameters();
            if (bytes(traitTypes[i]).length == 0) revert InvalidParameters();
            if (bytes(traitValues[i]).length == 0) revert InvalidParameters();

            currentTokenId++;
            uint256 tokenId = currentTokenId;

            tokenTraitType[tokenId] = traitTypes[i];
            tokenTraitValue[tokenId] = traitValues[i];

            _safeMint(recipients[i], tokenId);
            _setTokenURI(tokenId, uris[i]);

            tokenIds[i] = tokenId;
            emit GeneNFTCreated(tokenId, recipients[i], traitTypes[i], traitValues[i], uris[i]);
        }

        return tokenIds;
    }

    /**
     * @dev Set the base URI for token metadata
     * @param newBaseURI The new base URI
     */
    function setBaseURI(string memory newBaseURI) external onlyOwner {
        baseTokenURI = newBaseURI;
        emit BaseURIUpdated(newBaseURI);
    }

    /**
     * @dev Get the trait information for a specific token
     * @param tokenId The token ID to query
     * @return traitType The trait type
     * @return traitValue The trait value
     */
    function getTokenTraits(uint256 tokenId)
        external
        view
        returns (string memory traitType, string memory traitValue)
    {
        if (!_exists(tokenId)) revert InvalidParameters();
        return (tokenTraitType[tokenId], tokenTraitValue[tokenId]);
    }

    /**
     * @dev Get all tokens with a specific trait type
     * @param traitType The trait type to search for
     * @return tokenIds Array of token IDs with the specified trait type
     */
    function getTokensByTraitType(string memory traitType) external view returns (uint256[] memory) {
        uint256[] memory matchingTokens = new uint256[](totalSupply());
        uint256 matchCount = 0;

        for (uint256 i = 1; i <= currentTokenId; i++) {
            if (_exists(i) && keccak256(abi.encodePacked(tokenTraitType[i])) == keccak256(abi.encodePacked(traitType)))
            {
                matchingTokens[matchCount] = i;
                matchCount++;
            }
        }

        // Create properly sized return array
        uint256[] memory result = new uint256[](matchCount);
        for (uint256 i = 0; i < matchCount; i++) {
            result[i] = matchingTokens[i];
        }

        return result;
    }

    /**
     * @dev Get all tokens with a specific trait value
     * @param traitValue The trait value to search for
     * @return tokenIds Array of token IDs with the specified trait value
     */
    function getTokensByTraitValue(string memory traitValue) external view returns (uint256[] memory) {
        uint256[] memory matchingTokens = new uint256[](totalSupply());
        uint256 matchCount = 0;

        for (uint256 i = 1; i <= currentTokenId; i++) {
            if (
                _exists(i) && keccak256(abi.encodePacked(tokenTraitValue[i])) == keccak256(abi.encodePacked(traitValue))
            ) {
                matchingTokens[matchCount] = i;
                matchCount++;
            }
        }

        // Create properly sized return array
        uint256[] memory result = new uint256[](matchCount);
        for (uint256 i = 0; i < matchCount; i++) {
            result[i] = matchingTokens[i];
        }

        return result;
    }

    /**
     * @dev Check if a token exists
     * @param tokenId The token ID to check
     * @return True if the token exists
     */
    function _exists(uint256 tokenId) internal view returns (bool) {
        return tokenId > 0 && tokenId <= currentTokenId && _ownerOf(tokenId) != address(0);
    }

    /**
     * @dev Override tokenURI to return the full URI for a token
     * @param tokenId The token ID to get the URI for
     * @return The complete URI for the token
     */
    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    /**
     * @dev Override _baseURI to return the base URI
     * @return The base URI for tokens
     */
    function _baseURI() internal view override returns (string memory) {
        return baseTokenURI;
    }

    /**
     * @dev Override _update to support both ERC721Enumerable and base ERC721
     * @param to The address receiving the token
     * @param tokenId The token ID being transferred
     * @param auth The authorized address
     * @return The previous owner
     */
    function _update(address to, uint256 tokenId, address auth)
        internal
        override(ERC721, ERC721Enumerable)
        returns (address)
    {
        return super._update(to, tokenId, auth);
    }

    /**
     * @dev Override _increaseBalance to support ERC721Enumerable
     * @param account The account whose balance is being increased
     * @param value The amount to increase
     */
    function _increaseBalance(address account, uint128 value) internal override(ERC721, ERC721Enumerable) {
        super._increaseBalance(account, value);
    }

    /**
     * @dev Override supportsInterface to support all implemented interfaces
     * @param interfaceId The interface ID to check
     * @return True if the interface is supported
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721URIStorage, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
