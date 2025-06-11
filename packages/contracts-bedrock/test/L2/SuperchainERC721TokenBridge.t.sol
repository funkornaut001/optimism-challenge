// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Testing utilities
import { Test } from "forge-std/Test.sol";

// Libraries
import { Predeploys } from "src/libraries/Predeploys.sol";
import { IL2ToL2CrossDomainMessenger } from "interfaces/L2/IL2ToL2CrossDomainMessenger.sol";
import { Unauthorized, ZeroAddress } from "src/libraries/errors/CommonErrors.sol";

// Target contract
import { SuperchainERC721TokenBridge } from "src/L2/SuperchainERC721TokenBridge.sol";
import { ISuperchainERC721 } from "interfaces/L2/ISuperchainERC721.sol";
import { MockSuperchainERC721Implementation } from "test/mocks/SuperchainERC721Implementation.sol";

/// @title SuperchainERC721TokenBridgeTest
/// @notice Contract for testing the SuperchainERC721TokenBridge contract.
contract SuperchainERC721TokenBridgeTest is Test {
    address internal constant ZERO_ADDRESS = address(0);

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    event SendERC721(
        address indexed token, address indexed from, address indexed to, uint256 tokenId, uint256 destination
    );

    event RelayERC721(address indexed token, address indexed from, address indexed to, uint256 tokenId, uint256 source);

    ISuperchainERC721 public superchainERC721;
    SuperchainERC721TokenBridge public superchainERC721TokenBridge;

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    uint256 public constant TOKEN_ID = 1;
    uint256 public constant DESTINATION_CHAIN_ID = 2;
    uint256 public constant SOURCE_CHAIN_ID = 1;

    /// @notice Sets up the test suite.
    function setUp() public {
        vm.etch(Predeploys.SUPERCHAIN_ERC721_TOKEN_BRIDGE, address(new SuperchainERC721TokenBridge()).code);
        superchainERC721TokenBridge = SuperchainERC721TokenBridge(Predeploys.SUPERCHAIN_ERC721_TOKEN_BRIDGE);
        superchainERC721 =
            ISuperchainERC721(address(new MockSuperchainERC721Implementation("SuperchainERC721", "SCE721", alice)));
    }

    /// @notice Helper function to setup a mock and expect a call to it.
    function _mockAndExpect(address _receiver, bytes memory _calldata, bytes memory _returned) internal {
        vm.mockCall(_receiver, _calldata, _returned);
        vm.expectCall(_receiver, _calldata);
    }

    /// @notice Tests the `sendERC721` function reverts when the address `_to` is zero.
    function testFuzz_sendERC721_zeroAddressTo_reverts(address _sender, uint256 _tokenId, uint256 _chainId) public {
        // Expect the revert with `ZeroAddress` selector
        vm.expectRevert(ZeroAddress.selector);

        // Call the `sendERC721` function with the zero address as `_to`
        vm.prank(_sender);
        superchainERC721TokenBridge.sendERC721(address(superchainERC721), ZERO_ADDRESS, _tokenId, _chainId);
    }

    /// @notice Tests the `sendERC721` function reverts when the caller doesn't own the token.
    function testFuzz_sendERC721_invalidTokenOwnership_reverts(
        address _sender,
        address _to,
        uint256 _tokenId,
        uint256 _chainId
    )
        public
    {
        vm.assume(_to != ZERO_ADDRESS);
        vm.assume(_sender != ZERO_ADDRESS);

        // Mint token to alice (not _sender) to avoid invalid tokenId revert
        MockSuperchainERC721Implementation(address(superchainERC721)).mint(alice, _tokenId);

        // Expect the revert with `InvalidTokenOwnership` selector
        vm.expectRevert(SuperchainERC721TokenBridge.SuperchainERC721TokenBridge_InvalidTokenOwnership.selector);

        // Call the `sendERC721` function with _sender who doesn't own the token
        vm.prank(_sender);
        superchainERC721TokenBridge.sendERC721(address(superchainERC721), _to, _tokenId, _chainId);
    }

    /// @notice Tests the `sendERC721` function burns the sender token, sends the message, and emits the `SendERC721`
    /// event.
    function testFuzz_sendERC721_succeeds(
        address _sender,
        address _to,
        uint256 _tokenId,
        uint256 _chainId,
        bytes32 _msgHash
    )
        external
    {
        // Ensure `_sender` and `_to` are not the zero address
        vm.assume(_sender != ZERO_ADDRESS);
        vm.assume(_to != ZERO_ADDRESS);

        // Mint token to the sender so they can send it
        MockSuperchainERC721Implementation(address(superchainERC721)).mint(_sender, _tokenId);

        // Verify sender owns the token before sending
        assertEq(superchainERC721.ownerOf(_tokenId), _sender);

        // Look for the emit of the `Transfer` event (burn)
        vm.expectEmit(address(superchainERC721));
        emit Transfer(_sender, ZERO_ADDRESS, _tokenId);

        // Look for the emit of the `SendERC721` event
        vm.expectEmit(address(superchainERC721TokenBridge));
        emit SendERC721(address(superchainERC721), _sender, _to, _tokenId, _chainId);

        // Mock the call over the `sendMessage` function and expect it to be called properly
        bytes memory _message =
            abi.encodeCall(superchainERC721TokenBridge.relayERC721, (address(superchainERC721), _sender, _to, _tokenId));
        _mockAndExpect(
            Predeploys.L2_TO_L2_CROSS_DOMAIN_MESSENGER,
            abi.encodeCall(
                IL2ToL2CrossDomainMessenger.sendMessage, (_chainId, address(superchainERC721TokenBridge), _message)
            ),
            abi.encode(_msgHash)
        );

        // Call the `sendERC721` function
        vm.prank(_sender);
        bytes32 _returnedMsgHash =
            superchainERC721TokenBridge.sendERC721(address(superchainERC721), _to, _tokenId, _chainId);

        // Check the message hash was generated correctly
        assertEq(_msgHash, _returnedMsgHash);

        // Check the token was burned (should revert when querying owner)
        vm.expectRevert("ERC721: invalid token ID");
        superchainERC721.ownerOf(_tokenId);
    }

    /// @notice Tests the `relayERC721` function reverts when the caller is not the L2ToL2CrossDomainMessenger.
    function testFuzz_relayERC721_notMessenger_reverts(
        address _token,
        address _caller,
        address _to,
        uint256 _tokenId
    )
        public
    {
        // Ensure the caller is not the messenger
        vm.assume(_caller != Predeploys.L2_TO_L2_CROSS_DOMAIN_MESSENGER);

        // Expect the revert with `Unauthorized` selector
        vm.expectRevert(Unauthorized.selector);

        // Call the `relayERC721` function with the non-messenger caller
        vm.prank(_caller);
        superchainERC721TokenBridge.relayERC721(_token, _caller, _to, _tokenId);
    }

    /// @notice Tests the `relayERC721` function reverts when the `crossDomainMessageSender` that sent the message is
    /// not
    /// the same SuperchainERC721TokenBridge.
    function testFuzz_relayERC721_notCrossDomainSender_reverts(
        address _crossDomainMessageSender,
        uint256 _source,
        address _to,
        uint256 _tokenId
    )
        public
    {
        vm.assume(_crossDomainMessageSender != address(superchainERC721TokenBridge));

        // Mock the call over the `crossDomainMessageContext` function setting a wrong sender
        vm.mockCall(
            Predeploys.L2_TO_L2_CROSS_DOMAIN_MESSENGER,
            abi.encodeCall(IL2ToL2CrossDomainMessenger.crossDomainMessageContext, ()),
            abi.encode(_crossDomainMessageSender, _source)
        );

        // Expect the revert with `InvalidCrossDomainSender` selector
        vm.expectRevert(SuperchainERC721TokenBridge.SuperchainERC721TokenBridge_InvalidCrossDomainSender.selector);

        // Call the `relayERC721` function with the sender caller
        vm.prank(Predeploys.L2_TO_L2_CROSS_DOMAIN_MESSENGER);
        superchainERC721TokenBridge.relayERC721(address(superchainERC721), _crossDomainMessageSender, _to, _tokenId);
    }

    /// @notice Tests the `relayERC721` mints the token and emits the `RelayERC721` event.
    function testFuzz_relayERC721_succeeds(address _from, address _to, uint256 _tokenId, uint256 _source) public {
        vm.assume(_to != ZERO_ADDRESS);

        // Mock the call over the `crossDomainMessageContext` function setting the same address as value
        _mockAndExpect(
            Predeploys.L2_TO_L2_CROSS_DOMAIN_MESSENGER,
            abi.encodeCall(IL2ToL2CrossDomainMessenger.crossDomainMessageContext, ()),
            abi.encode(address(superchainERC721TokenBridge), _source)
        );

        // Look for the emit of the `Transfer` event (mint)
        vm.expectEmit(address(superchainERC721));
        emit Transfer(ZERO_ADDRESS, _to, _tokenId);

        // Look for the emit of the `RelayERC721` event
        vm.expectEmit(address(superchainERC721TokenBridge));
        emit RelayERC721(address(superchainERC721), _from, _to, _tokenId, _source);

        // Call the `relayERC721` function with the messenger caller
        vm.prank(Predeploys.L2_TO_L2_CROSS_DOMAIN_MESSENGER);
        superchainERC721TokenBridge.relayERC721(address(superchainERC721), _from, _to, _tokenId);

        // Check the token was minted to the correct recipient
        assertEq(superchainERC721.ownerOf(_tokenId), _to);
    }

    /// @notice Tests that the version function returns the correct version.
    function test_version_succeeds() public view {
        string memory expected = "1.0.0";
        assertEq(superchainERC721TokenBridge.version(), expected);
    }
}
