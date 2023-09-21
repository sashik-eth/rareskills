// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {TokenWithGodMode} from "../../src/Week1/TokenWithGodMode.sol";

contract TokenWithGodModeTest is Test {
    TokenWithGodMode token;

    address GOD = makeAddr("GOD");

    function setUp() public {
        token = new TokenWithGodMode("TokenWithSanctions", "TWS", GOD);
    }

    function testGodCouldTransferFromArbitraryAddress(address sender, address receiver, uint256 amount) public {
        vm.assume(sender != address(0));
        vm.assume(receiver != address(0));
        vm.assume(sender != receiver);
        deal(address(token), sender, amount);

        vm.prank(GOD);
        token.transferFrom(sender, receiver, amount);
    }

    function testGodCannotSpentMoreThanUserHave(address sender, address receiver, uint256 amount) public {
        vm.assume(sender != address(0));
        vm.assume(receiver != address(0));
        vm.assume(sender != receiver);
        vm.assume(amount < type(uint256).max);

        deal(address(token), sender, amount);

        vm.prank(GOD);
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        token.transferFrom(sender, receiver, amount + 1);
    }
}
