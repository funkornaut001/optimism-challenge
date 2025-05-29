// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title ISuperchainERC721
/// @notice Interface for SuperchainERC721 tokens that can be transferred across chains.
interface ISuperchainERC721 {
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

    /// @notice Returns the current owner of `tokenId` token.
    /// @param tokenId The token to query the owner of.
    /// @return owner The owner of the token.
    function ownerOf(uint256 tokenId) external view returns (address owner);

    /// @notice Mints a token to a given address. Only callable by the bridge.
    /// @param _to The address to mint the token to.
    /// @param _tokenId The token ID to mint.
    function crosschainMint(address _to, uint256 _tokenId) external;

    /// @notice Burns a token from a given address. Only callable by the bridge.
    /// @param _from The address to burn the token from.
    /// @param _tokenId The token ID to burn.
    function crosschainBurn(address _from, uint256 _tokenId) external;
}