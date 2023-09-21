// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {DelayEscrow} from "../../src/Week1/DelayEscrow.sol";

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract DelayEscrowTest is Test {
    DelayEscrow delayEscrow;
    ERC20 mockToken;

    address BUYER = makeAddr("BUYER");
    address SELLER = makeAddr("SELLER");

    function setUp() public {
        delayEscrow = new DelayEscrow();
        mockToken = new ERC20("Mock TOKEN", "MKT");
    }

    function testSuccessfulDepositAndWithdraw(uint256 amount) public {
        deal(address(mockToken), BUYER, amount);
        vm.startPrank(BUYER);
        mockToken.approve(address(delayEscrow), amount);
        delayEscrow.deposit(mockToken, SELLER, amount);

        skip(delayEscrow.DELAY() + 1);

        uint256 _balance = mockToken.balanceOf(SELLER);
        changePrank(SELLER);
        delayEscrow.withdraw(mockToken, block.timestamp - 1);
        uint256 balance_ = mockToken.balanceOf(SELLER);
        assertEq(balance_ - _balance, amount, "Wrong withdraw amount");
    }

    function testRevertWithdrawIfTooEarlyCall(uint256 amount, uint256 _delay) public {
        vm.assume(_delay < delayEscrow.DELAY());
        deal(address(mockToken), BUYER, amount);
        vm.startPrank(BUYER);
        mockToken.approve(address(delayEscrow), amount);
        delayEscrow.deposit(mockToken, SELLER, amount);

        skip(_delay);

        changePrank(SELLER);
        vm.expectRevert("Too early");
        delayEscrow.withdraw(mockToken, block.timestamp);
    }
}
