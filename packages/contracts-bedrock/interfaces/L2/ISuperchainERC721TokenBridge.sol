// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title ISuperchainERC721TokenBridge
/// @notice Interface for the SuperchainERC721TokenBridge predeploy.
interface ISuperchainERC721TokenBridge {
    /// @notice Thrown when attempting to relay a message and the cross domain message sender is not the
    /// SuperchainERC721TokenBridge.
    error InvalidCrossDomainSender();

    /// @notice Thrown when attempting to use a token that does not implement the ERC7802 interface.
    error InvalidERC7802();

    /// @notice Thrown when attempting to send a token that doesn't exist or isn't owned by sender.
    error InvalidTokenOwnership();

    /// @notice Emitted when a token is sent from one chain to another.
    /// @param token Address of the token sent.
    /// @param from Address of the sender.
    /// @param to Address of the recipient.
    /// @param tokenId ID of the token sent.
    /// @param destination Chain ID of the destination chain.
    event SendERC721(
        address indexed token, address indexed from, address indexed to, uint256 tokenId, uint256 destination
    );

    /// @notice Emitted whenever a token is successfully relayed on this chain.
    /// @param token Address of the token relayed.
    /// @param from Address of the msg.sender of sendERC721 on the source chain.
    /// @param to Address of the recipient.
    /// @param tokenId ID of the token relayed.
    /// @param source Chain ID of the source chain.
    event RelayERC721(
        address indexed token, address indexed from, address indexed to, uint256 tokenId, uint256 source
    );

    /// @notice Sends a token to a target address on another chain.
    /// @param _token Token contract address.
    /// @param _to Address to send token to.
    /// @param _tokenId ID of the token to send.
    /// @param _chainId Chain ID of the destination chain.
    /// @return msgHash_ Hash of the message sent.
    function sendERC721(
        address _token,
        address _to,
        uint256 _tokenId,
        uint256 _chainId
    )
        external
        returns (bytes32 msgHash_);

    /// @notice Relays a token received from another chain.
    /// @param _token Token contract address.
    /// @param _from Address of the msg.sender of sendERC721 on the source chain.
    /// @param _to Address to relay token to.
    /// @param _tokenId ID of the token to relay.
    function relayERC721(address _token, address _from, address _to, uint256 _tokenId) external;
}