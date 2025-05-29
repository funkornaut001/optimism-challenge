// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { SuperchainERC721 } from "src/L2/SuperchainERC721.sol";

/// @title SuperchainERC721Implementation Mock contract
/// @notice Mock contract just to create tests over an implementation of the SuperchainERC721 abstract contract.
contract MockSuperchainERC721Implementation is SuperchainERC721 {
    constructor(string memory name_, string memory symbol_) SuperchainERC721(name_, symbol_) {}

    /// @notice Mint function for testing purposes
    /// @param to Address to mint to
    /// @param tokenId Token ID to mint
    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }
}