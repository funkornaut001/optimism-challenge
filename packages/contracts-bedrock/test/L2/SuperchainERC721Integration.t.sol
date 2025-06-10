// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Testing
import { Test } from "forge-std/Test.sol";

// Libraries
import { Predeploys } from "src/libraries/Predeploys.sol";
import { Unauthorized, ZeroAddress } from "src/libraries/errors/CommonErrors.sol";

// Contracts
import { SuperchainERC721TokenBridge } from "src/L2/SuperchainERC721TokenBridge.sol";

// Interfaces
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IL2ToL2CrossDomainMessenger } from "interfaces/L2/IL2ToL2CrossDomainMessenger.sol";

// Mocks
import { MockSuperchainERC721Implementation } from "test/mocks/SuperchainERC721Implementation.sol";

/// @title SuperchainERC721Integration
/// @notice Integration tests for SuperchainERC721TokenBridge using the real contract
/// @dev Tests the interaction between SuperchainERC721TokenBridge and SuperchainERC721 tokens
contract SuperchainERC721Integration is Test {
    // Test Configuration
    uint256 constant DESTINATION_CHAIN_ID = 902;
    uint256 constant SOURCE_CHAIN_ID = 901;

    // Test addresses
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    // Events from the real contract
    event SendERC721(
        address indexed token, address indexed from, address indexed to, uint256 tokenId, uint256 destination
    );

    event RelayERC721(address indexed token, address indexed from, address indexed to, uint256 tokenId, uint256 source);

    // Test contracts - using the REAL SuperchainERC721TokenBridge
    SuperchainERC721TokenBridge bridge721;
    MockSuperchainERC721Implementation testNFT;

    /// @notice Sets up the test environment with the real bridge contract
    function setUp() public {
        // Deploy the REAL SuperchainERC721TokenBridge at the predeploy address
        SuperchainERC721TokenBridge bridgeImpl = new SuperchainERC721TokenBridge();
        vm.etch(Predeploys.SUPERCHAIN_ERC721_TOKEN_BRIDGE, address(bridgeImpl).code);
        bridge721 = SuperchainERC721TokenBridge(Predeploys.SUPERCHAIN_ERC721_TOKEN_BRIDGE);

        // Verify bridge721 is deployed and working
        assertEq(bridge721.version(), "1.0.0", "Bridge version should be 1.0.0");

        // Deploy test NFT with alice as owner
        testNFT = new MockSuperchainERC721Implementation("TestNFT", "TNFT", alice);

        // Mint some test tokens to alice
        for (uint256 i = 1; i <= 5; i++) {
            testNFT.mint(alice, i);
        }

        // Give alice and bob some ETH for transactions
        vm.deal(alice, 1 ether);
        vm.deal(bob, 1 ether);
    }

    /// @notice Test basic setup and deployment
    function test_setup_succeeds() public view {
        assertEq(address(bridge721), Predeploys.SUPERCHAIN_ERC721_TOKEN_BRIDGE);
        assertEq(bridge721.version(), "1.0.0");
        assertEq(IERC721(testNFT).balanceOf(alice), 5);
        assertEq(IERC721(testNFT).ownerOf(1), alice);
    }

    /// @notice Test sending ERC721 token cross-chain
    function test_sendERC721_succeeds() public {
        uint256 tokenId = 1;

        // Mock the L2ToL2CrossDomainMessenger for the sendMessage call
        vm.mockCall(
            Predeploys.L2_TO_L2_CROSS_DOMAIN_MESSENGER,
            abi.encodeWithSignature("sendMessage(uint256,address,bytes)"),
            abi.encode(keccak256("mock_message_hash"))
        );

        // Verify alice owns the token
        assertEq(IERC721(testNFT).ownerOf(tokenId), alice);

        // Expect the SendERC721 event
        vm.expectEmit(true, true, true, true, address(bridge721));
        emit SendERC721(address(testNFT), alice, bob, tokenId, DESTINATION_CHAIN_ID);

        // Send token cross-chain
        vm.prank(alice);
        bytes32 msgHash = bridge721.sendERC721(address(testNFT), bob, tokenId, DESTINATION_CHAIN_ID);

        // Verify token was burned (no longer exists)
        vm.expectRevert();
        IERC721(testNFT).ownerOf(tokenId);

        // Verify message hash was returned
        assertTrue(msgHash != bytes32(0));

        // Verify alice's balance decreased
        assertEq(IERC721(testNFT).balanceOf(alice), 4);
    }

    /// @notice Test relaying ERC721 token from another chain
    function test_relayERC721_succeeds() public {
        uint256 tokenId = 42;

        // Mock the L2ToL2CrossDomainMessenger to simulate cross-chain message
        vm.mockCall(
            Predeploys.L2_TO_L2_CROSS_DOMAIN_MESSENGER,
            abi.encodeCall(IL2ToL2CrossDomainMessenger.crossDomainMessageContext, ()),
            abi.encode(address(bridge721), SOURCE_CHAIN_ID)
        );

        // Expect the RelayERC721 event
        vm.expectEmit(true, true, true, true, address(bridge721));
        emit RelayERC721(address(testNFT), alice, bob, tokenId, SOURCE_CHAIN_ID);

        // Simulate cross-chain message relay
        vm.prank(Predeploys.L2_TO_L2_CROSS_DOMAIN_MESSENGER);
        bridge721.relayERC721(address(testNFT), alice, bob, tokenId);

        // Verify token was minted to bob
        assertEq(IERC721(testNFT).ownerOf(tokenId), bob);
        assertEq(IERC721(testNFT).balanceOf(bob), 1);
    }

    /// @notice Test complete cross-chain transfer cycle
    function test_crossChainTransferCycle_succeeds() public {
        uint256 tokenId = 3;

        // Mock the L2ToL2CrossDomainMessenger for sendMessage
        vm.mockCall(
            Predeploys.L2_TO_L2_CROSS_DOMAIN_MESSENGER,
            abi.encodeWithSignature("sendMessage(uint256,address,bytes)"),
            abi.encode(keccak256("mock_message_hash"))
        );

        // Step 1: Alice sends token cross-chain
        vm.prank(alice);
        bytes32 msgHash = bridge721.sendERC721(address(testNFT), bob, tokenId, DESTINATION_CHAIN_ID);

        // Verify token was burned
        vm.expectRevert();
        IERC721(testNFT).ownerOf(tokenId);

        // Step 2: Simulate message relay on destination chain
        vm.mockCall(
            Predeploys.L2_TO_L2_CROSS_DOMAIN_MESSENGER,
            abi.encodeCall(IL2ToL2CrossDomainMessenger.crossDomainMessageContext, ()),
            abi.encode(address(bridge721), SOURCE_CHAIN_ID)
        );

        vm.prank(Predeploys.L2_TO_L2_CROSS_DOMAIN_MESSENGER);
        bridge721.relayERC721(address(testNFT), alice, bob, tokenId);

        // Verify token was minted to bob
        assertEq(IERC721(testNFT).ownerOf(tokenId), bob);
        assertEq(IERC721(testNFT).balanceOf(bob), 1);
        assertEq(IERC721(testNFT).balanceOf(alice), 4);
    }

    /// @notice Test that sendERC721 reverts when sender doesn't own token
    function test_sendERC721_unauthorizedSender_reverts() public {
        uint256 tokenId = 1;

        // Bob tries to send alice's token - should revert with InvalidTokenOwnership
        vm.expectRevert(SuperchainERC721TokenBridge.InvalidTokenOwnership.selector);
        vm.prank(bob);
        bridge721.sendERC721(address(testNFT), alice, tokenId, DESTINATION_CHAIN_ID);
    }

    /// @notice Test that sendERC721 reverts when recipient is zero address
    function test_sendERC721_zeroRecipient_reverts() public {
        uint256 tokenId = 1;

        vm.expectRevert(ZeroAddress.selector);
        vm.prank(alice);
        bridge721.sendERC721(address(testNFT), address(0), tokenId, DESTINATION_CHAIN_ID);
    }

    /// @notice Test that relayERC721 reverts when called by non-messenger
    function test_relayERC721_unauthorizedCaller_reverts() public {
        uint256 tokenId = 42;

        vm.expectRevert(Unauthorized.selector);
        vm.prank(alice);
        bridge721.relayERC721(address(testNFT), alice, bob, tokenId);
    }

    /// @notice Test that relayERC721 reverts when cross-domain sender is not bridge
    function test_relayERC721_invalidCrossDomainSender_reverts() public {
        uint256 tokenId = 42;

        // Mock messenger to return different sender
        vm.mockCall(
            Predeploys.L2_TO_L2_CROSS_DOMAIN_MESSENGER,
            abi.encodeCall(IL2ToL2CrossDomainMessenger.crossDomainMessageContext, ()),
            abi.encode(alice, SOURCE_CHAIN_ID) // alice instead of bridge
        );

        vm.expectRevert(SuperchainERC721TokenBridge.InvalidCrossDomainSender.selector);
        vm.prank(Predeploys.L2_TO_L2_CROSS_DOMAIN_MESSENGER);
        bridge721.relayERC721(address(testNFT), alice, bob, tokenId);
    }

    /// @notice Test that SuperchainERC721 only allows bridge to mint/burn
    function test_superchainERC721_bridgeOnlyAccess() public {
        uint256 tokenId = 100;

        // Direct calls to crosschainMint/crosschainBurn should fail
        vm.expectRevert(Unauthorized.selector);
        vm.prank(alice);
        testNFT.crosschainMint(alice, tokenId);

        vm.expectRevert(Unauthorized.selector);
        vm.prank(alice);
        testNFT.crosschainBurn(alice, 1);

        // Bridge should be able to mint/burn
        vm.prank(Predeploys.SUPERCHAIN_ERC721_TOKEN_BRIDGE);
        testNFT.crosschainMint(alice, tokenId);
        assertEq(IERC721(testNFT).ownerOf(tokenId), alice);

        vm.prank(Predeploys.SUPERCHAIN_ERC721_TOKEN_BRIDGE);
        testNFT.crosschainBurn(alice, tokenId);
        vm.expectRevert();
        IERC721(testNFT).ownerOf(tokenId);
    }

    /// @notice Test multiple token transfers
    function test_multipleTransfers_succeed() public {
        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = 1;
        tokenIds[1] = 2;
        tokenIds[2] = 3;

        // Mock the L2ToL2CrossDomainMessenger for sendMessage calls
        vm.mockCall(
            Predeploys.L2_TO_L2_CROSS_DOMAIN_MESSENGER,
            abi.encodeWithSignature("sendMessage(uint256,address,bytes)"),
            abi.encode(keccak256("mock_message_hash"))
        );

        // Send multiple tokens
        for (uint256 i = 0; i < tokenIds.length; i++) {
            vm.prank(alice);
            bridge721.sendERC721(address(testNFT), bob, tokenIds[i], DESTINATION_CHAIN_ID);
        }

        // Verify all tokens were burned
        for (uint256 i = 0; i < tokenIds.length; i++) {
            vm.expectRevert();
            IERC721(testNFT).ownerOf(tokenIds[i]);
        }

        // Alice should have 2 tokens left (started with 5, sent 3)
        assertEq(IERC721(testNFT).balanceOf(alice), 2);

        // Simulate relaying all tokens to bob
        vm.mockCall(
            Predeploys.L2_TO_L2_CROSS_DOMAIN_MESSENGER,
            abi.encodeCall(IL2ToL2CrossDomainMessenger.crossDomainMessageContext, ()),
            abi.encode(address(bridge721), SOURCE_CHAIN_ID)
        );

        for (uint256 i = 0; i < tokenIds.length; i++) {
            vm.prank(Predeploys.L2_TO_L2_CROSS_DOMAIN_MESSENGER);
            bridge721.relayERC721(address(testNFT), alice, bob, tokenIds[i]);
        }

        // Bob should now have 3 tokens
        assertEq(IERC721(testNFT).balanceOf(bob), 3);

        // Verify bob owns all the tokens
        for (uint256 i = 0; i < tokenIds.length; i++) {
            assertEq(IERC721(testNFT).ownerOf(tokenIds[i]), bob);
        }
    }

    /// @notice Test that bridge integrates properly with different SuperchainERC721 implementations
    function test_differentNFTContracts_succeed() public {
        // Deploy a second NFT contract
        MockSuperchainERC721Implementation testNFT2 = new MockSuperchainERC721Implementation("TestNFT2", "TNFT2", alice);
        testNFT2.mint(alice, 1);

        // Mock the L2ToL2CrossDomainMessenger
        vm.mockCall(
            Predeploys.L2_TO_L2_CROSS_DOMAIN_MESSENGER,
            abi.encodeWithSignature("sendMessage(uint256,address,bytes)"),
            abi.encode(keccak256("mock_message_hash"))
        );

        // Bridge should work with different NFT contracts
        vm.prank(alice);
        bridge721.sendERC721(address(testNFT2), bob, 1, DESTINATION_CHAIN_ID);

        // Verify token was burned from the second contract
        vm.expectRevert();
        IERC721(testNFT2).ownerOf(1);

        // Original NFT should be unaffected
        assertEq(IERC721(testNFT).balanceOf(alice), 5);
    }
}