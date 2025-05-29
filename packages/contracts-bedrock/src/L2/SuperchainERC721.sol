// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Contracts
import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

// Libraries
import { Predeploys } from "src/libraries/Predeploys.sol";
import { Unauthorized } from "src/libraries/errors/CommonErrors.sol";

// Interfaces
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { ISemver } from "interfaces/universal/ISemver.sol";
import { IERC165 } from "@openzeppelin/contracts/interfaces/IERC165.sol";

/// @title SuperchainERC721
/// @notice A standard ERC721 extension implementing cross-chain functionality for NFT
///         interoperability across the Superchain. Gives the SuperchainERC721TokenBridge mint
///         and burn permissions.
abstract contract SuperchainERC721 is ERC721, ISemver {
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

    /// @param _name ERC721 name
    /// @param _symbol ERC721 symbol
    constructor(string memory _name, string memory _symbol) ERC721(_name, _symbol) {}

    /// @notice Semantic version.
    /// @custom:semver 1.0.0
    function version() external view virtual returns (string memory) {
        return "1.0.0";
    }

    /// @notice Allows the SuperchainERC721TokenBridge to mint tokens.
    /// @param _to Address to mint token to.
    /// @param _tokenId ID of the token to mint.
    function crosschainMint(address _to, uint256 _tokenId) external {
        if (msg.sender != Predeploys.SUPERCHAIN_ERC721_TOKEN_BRIDGE) revert Unauthorized();

        _mint(_to, _tokenId);

        emit CrosschainMint(_to, _tokenId, msg.sender);
    }

    /// @notice Allows the SuperchainERC721TokenBridge to burn tokens.
    /// @param _from Address to burn token from.
    /// @param _tokenId ID of the token to burn.
    function crosschainBurn(address _from, uint256 _tokenId) external {
        if (msg.sender != Predeploys.SUPERCHAIN_ERC721_TOKEN_BRIDGE) revert Unauthorized();

        _burn(_tokenId);

        emit CrosschainBurn(_from, _tokenId, msg.sender);
    }

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 _interfaceId) public view virtual override returns (bool) {
        return _interfaceId == type(IERC721).interfaceId || _interfaceId == type(IERC165).interfaceId
            || super.supportsInterface(_interfaceId);
    }
}