// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Testing utilities
import { Test } from "forge-std/Test.sol";

// Libraries
import { Predeploys } from "src/libraries/Predeploys.sol";
import { Unauthorized } from "src/libraries/errors/CommonErrors.sol";

// Target contract
import { SuperchainERC721 } from "src/L2/SuperchainERC721.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IERC165 } from "@openzeppelin/contracts/interfaces/IERC165.sol";
import { MockSuperchainERC721Implementation } from "test/mocks/SuperchainERC721Implementation.sol";

/// @title SuperchainERC721Test
/// @notice Contract for testing the SuperchainERC721 contract.
contract SuperchainERC721Test is Test {
    address internal constant ZERO_ADDRESS = address(0);
    address internal constant SUPERCHAIN_ERC721_TOKEN_BRIDGE = Predeploys.SUPERCHAIN_ERC721_TOKEN_BRIDGE;

    SuperchainERC721 public superchainERC721;
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    /// @notice Sets up the test suite.
    function setUp() public {
        superchainERC721 = new MockSuperchainERC721Implementation("SuperchainERC721", "SCE721", alice);
    }

    /// @notice Helper function to setup a mock and expect a call to it.
    function _mockAndExpect(address _receiver, bytes memory _calldata, bytes memory _returned) internal {
        vm.mockCall(_receiver, _calldata, _returned);
        vm.expectCall(_receiver, _calldata);
    }

    /// @notice Tests the `crosschainMint` function reverts when the caller is not the bridge.
    function testFuzz_crosschainMint_callerNotBridge_reverts(address _caller, address _to, uint256 _tokenId) public {
        // Ensure the caller is not the bridge
        vm.assume(_caller != SUPERCHAIN_ERC721_TOKEN_BRIDGE);

        // Expect the revert with `Unauthorized` selector
        vm.expectRevert(Unauthorized.selector);

        // Call the `crosschainMint` function with the non-bridge caller
        vm.prank(_caller);
        superchainERC721.crosschainMint(_to, _tokenId);
    }

    /// @notice Tests the `crosschainMint` succeeds and emits the `CrosschainMint` event.
    function testFuzz_crosschainMint_succeeds(address _to, uint256 _tokenId) public {
        // Ensure `_to` is not the zero address
        vm.assume(_to != ZERO_ADDRESS);

        // Look for the emit of the `Transfer` event
        vm.expectEmit(address(superchainERC721));
        emit IERC721.Transfer(ZERO_ADDRESS, _to, _tokenId);

        // Look for the emit of the `CrosschainMint` event
        vm.expectEmit(address(superchainERC721));
        emit SuperchainERC721.CrosschainMint(_to, _tokenId, SUPERCHAIN_ERC721_TOKEN_BRIDGE);

        // Call the `crosschainMint` function with the bridge caller
        vm.prank(SUPERCHAIN_ERC721_TOKEN_BRIDGE);
        superchainERC721.crosschainMint(_to, _tokenId);

        // Check the token was minted correctly
        assertEq(superchainERC721.ownerOf(_tokenId), _to);
    }

    /// @notice Tests the `crosschainBurn` function reverts when the caller is not the bridge.
    function testFuzz_crosschainBurn_callerNotBridge_reverts(address _caller, address _from, uint256 _tokenId) public {
        // Ensure the caller is not the bridge
        vm.assume(_caller != SUPERCHAIN_ERC721_TOKEN_BRIDGE);

        // Expect the revert with `Unauthorized` selector
        vm.expectRevert(Unauthorized.selector);

        // Call the `crosschainBurn` function with the non-bridge caller
        vm.prank(_caller);
        superchainERC721.crosschainBurn(_from, _tokenId);
    }

    /// @notice Tests the `crosschainBurn` burns the token and emits the `CrosschainBurn` event.
    function testFuzz_crosschainBurn_succeeds(address _from, uint256 _tokenId) public {
        // Ensure `_from` is not the zero address
        vm.assume(_from != ZERO_ADDRESS);

        // Mint a token to `_from` so it can be burned
        vm.prank(SUPERCHAIN_ERC721_TOKEN_BRIDGE);
        superchainERC721.crosschainMint(_from, _tokenId);

        // Look for the emit of the `Transfer` event
        vm.expectEmit(address(superchainERC721));
        emit IERC721.Transfer(_from, ZERO_ADDRESS, _tokenId);

        // Look for the emit of the `CrosschainBurn` event
        vm.expectEmit(address(superchainERC721));
        emit SuperchainERC721.CrosschainBurn(_from, _tokenId, SUPERCHAIN_ERC721_TOKEN_BRIDGE);

        // Call the `crosschainBurn` function with the bridge caller
        vm.prank(SUPERCHAIN_ERC721_TOKEN_BRIDGE);
        superchainERC721.crosschainBurn(_from, _tokenId);

        // Check the token was burned (should revert when querying owner)
        vm.expectRevert();
        superchainERC721.ownerOf(_tokenId);
    }

    /// @notice Tests that the `supportsInterface` function returns true for the correct interfaces.
    function test_supportsInterface_succeeds() public view {
        assertTrue(superchainERC721.supportsInterface(type(IERC165).interfaceId));
        assertTrue(superchainERC721.supportsInterface(type(IERC721).interfaceId));
    }

    /// @notice Tests that the `supportsInterface` function returns false for unsupported interfaces.
    function testFuzz_supportsInterface_works(bytes4 _interfaceId) public view {
        vm.assume(_interfaceId != type(IERC165).interfaceId);
        vm.assume(_interfaceId != type(IERC721).interfaceId);
        // Also exclude ERC721Metadata interface
        vm.assume(_interfaceId != 0x5b5e139f);
        assertFalse(superchainERC721.supportsInterface(_interfaceId));
    }

    /// @notice Tests the version function returns the correct version.
    function test_version_succeeds() public view {
        assertEq(superchainERC721.version(), "1.0.0");
    }
}
