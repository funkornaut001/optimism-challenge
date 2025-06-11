// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/// @title ISuperchainERC721
/// @notice Interface for SuperchainERC721 tokens that can be transferred across chains.
interface ISuperchainERC721 is IERC721 {
    /// @notice Emitted when a token is minted via cross-chain transfer.
    /// @param to Address receiving the token.
    /// @param tokenId ID of the token minted.
    /// @param caller Address that initiated the cross-chain mint (should be bridge).
    event CrosschainMint(address indexed to, uint256 indexed tokenId, address indexed caller);

    /// @notice Emitted when a token is burned for cross-chain transfer.
    /// @param from Address that owned the token.
    /// @param tokenId ID of the token burned.
    /// @param caller Address that initiated the cross-chain burn (should be bridge).
    event CrosschainBurn(address indexed from, uint256 indexed tokenId, address indexed caller);

    error Unauthorized();

    /// @notice Semantic version.
    /// @custom:semver 1.0.0
    function version() external view returns (string memory);

    /// @notice The name of the token.
    function name() external view returns (string memory);

    /// @notice The symbol of the token.
    function symbol() external view returns (string memory);

    /// @notice The URI for a given token
    function tokenURI(uint256 tokenId) external view returns (string memory);

    /// @inheritdoc IERC721
    function setApprovalForAll(address operator, bool approved) external;

    /// @inheritdoc IERC721
    function getApproved(uint256 tokenId) external view returns (address);

    /// @inheritdoc IERC721
    function balanceOf(address owner) external view returns (uint256);

    /// @inheritdoc IERC721
    function ownerOf(uint256 tokenId) external view returns (address);

    /// @notice Mints a token to a given address. Only callable by the bridge.
    /// @param _to The address to mint the token to.
    /// @param _tokenId The token ID to mint.
    function crosschainMint(address _to, uint256 _tokenId) external;

    /// @notice Burns a token from a given address. Only callable by the bridge.
    /// @param _from The address to burn the token from.
    /// @param _tokenId The token ID to burn.
    function crosschainBurn(address _from, uint256 _tokenId) external;
}