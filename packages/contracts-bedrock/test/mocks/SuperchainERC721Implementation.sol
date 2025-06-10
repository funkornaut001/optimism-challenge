// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { SuperchainERC721 } from "src/L2/SuperchainERC721.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

/// @title SuperchainERC721Implementation Mock contract
/// @notice Mock contract just to create tests over an implementation of the SuperchainERC721 abstract contract.
contract MockSuperchainERC721Implementation is SuperchainERC721, Ownable {
    using Strings for uint256;

    /// @notice Base URI for token metadata
    string private _baseTokenURI = "https://example.com/token/";

    constructor(string memory name_, string memory symbol_, address owner_) ERC721(name_, symbol_) Ownable() {
        _transferOwnership(owner_);
    }

    /// @notice Mint function for testing purposes
    /// @param to Address to mint to
    /// @param tokenId Token ID to mint
    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }

    /// @notice Burn function for testing purposes
    /// @param tokenId Token ID to burn
    function burn(uint256 tokenId) external {
        _burn(tokenId);
    }

    /// @notice Set base URI for testing purposes
    /// @param baseURI Base URI to set
    function setBaseURI(string memory baseURI) external onlyOwner {
        _baseTokenURI = baseURI;
    }

    /// @notice Get base URI
    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    /// @notice Token URI implementation compatible with OZ v4.7.3
    /// @param tokenId Token ID to get URI for
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721: URI query for nonexistent token");

        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString())) : "";
    }
}