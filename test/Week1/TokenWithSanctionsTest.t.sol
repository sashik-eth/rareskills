// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {TokenWithSanctions} from "../../src/Week1/TokenWithSanctions.sol";

contract TokenWithSanctionsTest is Test {
    TokenWithSanctions token;

    address OWNER = makeAddr("OWNER");
    address SENDER = makeAddr("SENDER");
    address RECEIVER = makeAddr("RECEIVER");

    function setUp() public {
        token = new TokenWithSanctions("TokenWithSanctions", "TWS");
        token.transferOwnership(OWNER);
    }

    event Blacklisted(address indexed user, bool status);

    function testBlacklistEmitEvent(address user, bool status) public {
        vm.assume(user != address(0));
        vm.expectEmit();
        emit Blacklisted(user, status);

        vm.prank(OWNER);
        token.blacklist(user, status);
    }

    function testRevertOnBlacklistingZeroAddress() public {
        vm.expectRevert("Zero address can't be restricted");
        vm.prank(OWNER);
        token.blacklist(address(0), true);
    }

    function testRevertOnBlacklistingByNotOwner() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(SENDER);
        token.blacklist(address(0), true);
    }

    function testBlacklistedAddressCannotTransfer() public {
        uint256 amount = 100 ether;
        deal(address(token), SENDER, amount);
        vm.prank(OWNER);
        token.blacklist(SENDER, true);

        vm.expectRevert("Transfer restricted");
        vm.prank(SENDER);
        token.transfer(RECEIVER, amount);
    }

    function testBlacklistedAddressCannotReceive() public {
        uint256 amount = 100 ether;
        deal(address(token), SENDER, amount);
        vm.prank(OWNER);
        token.blacklist(RECEIVER, true);

        vm.expectRevert("Transfer restricted");
        vm.prank(SENDER);
        token.transfer(RECEIVER, amount);
    }

    function testFuzzingBlacklisting(address from, address to, address blacklisted, uint256 amount) public {
        vm.assume(blacklisted != address(0));
        vm.assume(from != address(0));
        vm.assume(to != address(0));
        vm.assume(from != to);
        deal(address(token), from, amount);

        vm.startPrank(OWNER);
        token.blacklist(blacklisted, true);

        changePrank(from);
        token.approve(address(this), amount);
        if (from == blacklisted || to == blacklisted) {
            vm.expectRevert("Transfer restricted");
        }
        changePrank(address(this));
        token.transferFrom(from, to, amount);
    }

    function testMessageDecodedCorrectly() public view {
        string memory zeroMsg = token.messageForTransferRestriction(0);
        assert(keccak256(abi.encodePacked(zeroMsg)) == keccak256(abi.encodePacked(token.SUCCESS_MESSAGE())));

        string memory senderMsg = token.messageForTransferRestriction(1);
        assert(
            keccak256(abi.encodePacked(senderMsg)) == keccak256(abi.encodePacked(token.SENDER_BLACKLISTED_MESSAGE()))
        );

        string memory receiverMsg = token.messageForTransferRestriction(2);
        assert(
            keccak256(abi.encodePacked(receiverMsg))
                == keccak256(abi.encodePacked(token.RECEIVER_BLACKLISTED_MESSAGE()))
        );

        string memory wrongMsg = token.messageForTransferRestriction(22);
        assert(keccak256(abi.encodePacked(wrongMsg)) == keccak256(abi.encodePacked(token.UNKNOWN_MESSAGE())));
    }
}
