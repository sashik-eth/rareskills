// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {TokenSale} from "../../src/Week1/TokenSale.sol";
import {ERC1363} from "erc1363-payable-token/contracts/token/ERC1363/ERC1363.sol";
import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract MockERC1363 is ERC1363 {
    constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) {}
}

contract TokenSaleTest is Test {
    TokenSale sale;
    MockERC1363 mockSellToken;
    MockERC1363 mockPaymentToken;
    MockERC1363 mockOtherToken;
    uint256 initPrice = 100 ether;
    uint256 finalPrice = 300 ether;
    uint256 initAmount = 1_000_000 ether;
    uint256 endTimestamp = block.timestamp + 30 days;
    address OWNER = makeAddr("OWNER");
    address USER = makeAddr("USER");

    function setUp() public {
        mockSellToken = new MockERC1363("Mock Sell Token", "MST");
        mockPaymentToken = new MockERC1363("Mock Payment Token", "MPT");
        mockOtherToken = new MockERC1363("Mock Other Token", "MOT");

        sale =
        new TokenSale((address(mockSellToken)), address(mockPaymentToken), initPrice, finalPrice, initAmount, endTimestamp);
        deal(address(mockSellToken), address(this), initAmount);
        mockSellToken.approve(address(sale), initAmount);
        sale.deposit();
        sale.transferOwnership(OWNER);
    }

    function testBuy(uint256 amount) public {
        amount = bound(amount, 0, initAmount);
        vm.assume(type(uint256).max > finalPrice * amount);
        uint256 inputRequired = sale.getBuyInput(amount);
        deal(address(mockPaymentToken), USER, inputRequired);

        vm.startPrank(USER);
        mockPaymentToken.approve(address(sale), inputRequired);
        uint256 _balance = mockSellToken.balanceOf(USER);
        sale.buy(amount, inputRequired);
        uint256 balance_ = mockSellToken.balanceOf(USER);
        assertEq(balance_ - _balance, amount, "Bought wrong amount");
    }

    function testBuyRevert(uint256 amount) public {
        amount = bound(amount, 0, initAmount);
        vm.assume(type(uint256).max > finalPrice * amount);
        uint256 inputRequired = sale.getBuyInput(amount);
        vm.assume(inputRequired > 1);
        deal(address(mockPaymentToken), USER, inputRequired);

        vm.startPrank(USER);
        mockPaymentToken.approve(address(sale), inputRequired);
        vm.expectRevert("Too expensive trade");
        sale.buy(amount, inputRequired - 1);
    }

    function testSell(uint256 amount) public {
        amount = bound(amount, 0, initAmount);
        testBuy(amount);
        uint256 outputExpected = sale.getSellOutput(amount);
        vm.assume(mockPaymentToken.balanceOf(address(sale)) <= outputExpected);
        deal(address(mockSellToken), USER, amount);

        vm.startPrank(USER);
        mockSellToken.approve(address(sale), amount);
        uint256 _balance = mockPaymentToken.balanceOf(USER);
        sale.sell(amount, outputExpected);
        uint256 balance_ = mockPaymentToken.balanceOf(USER);
        assertEq(balance_ - _balance, outputExpected, "Sold wrong amount");
    }

    function testSellRevert(uint256 amount) public {
        amount = bound(amount, 0, initAmount);
        testBuy(amount);
        uint256 outputExpected = sale.getSellOutput(amount);
        vm.assume(mockPaymentToken.balanceOf(address(sale)) <= outputExpected);
        deal(address(mockSellToken), USER, amount);

        vm.startPrank(USER);
        mockSellToken.approve(address(sale), amount);
        vm.expectRevert("Too expensive trade");
        sale.sell(amount, outputExpected + 1);
    }

    function testRevertIfOwnerDepositLess(uint256 amount) public {
        vm.assume(amount < initAmount);
        TokenSale _sale =
            new TokenSale(address(mockSellToken), address(mockPaymentToken), initPrice, finalPrice, initAmount, endTimestamp);
        deal(address(mockSellToken), address(this), amount);
        mockSellToken.approve(address(_sale), amount);
        vm.expectRevert();
        sale.deposit();
    }

    function testOwnerCanWithdraw(uint256 timePassed) public {
        vm.warp(timePassed);
        uint256 _balance = mockSellToken.balanceOf(OWNER);
        vm.prank(OWNER);
        if (block.timestamp <= endTimestamp) {
            vm.expectRevert("Too early withdraw");
            sale.withdraw(address(mockSellToken));
        } else {
            sale.withdraw(address(mockSellToken));
            uint256 balance_ = mockSellToken.balanceOf(OWNER);
            assertEq(balance_ - _balance, initAmount, "Wrong amount of tokens withdrawn");
        }
    }

    function testBuyOnCallback(uint256 amount) public {
        amount = bound(amount, 0, initAmount);
        vm.assume(type(uint256).max > finalPrice * amount);
        uint256 inputRequired = sale.getBuyInput(amount);
        deal(address(mockPaymentToken), USER, inputRequired);

        vm.startPrank(USER);
        uint256 _balance = mockSellToken.balanceOf(USER);
        mockPaymentToken.transferAndCall(address(sale), inputRequired, abi.encode(amount));
        uint256 balance_ = mockSellToken.balanceOf(USER);
        assertEq(balance_ - _balance, amount, "Bought wrong amount");
    }

    function testSellOnCallback(uint256 amount) public {
        amount = bound(amount, 0, initAmount);
        testBuy(amount);
        uint256 outputExpected = sale.getSellOutput(amount);
        vm.assume(mockPaymentToken.balanceOf(address(sale)) <= outputExpected);
        deal(address(mockSellToken), USER, amount);

        vm.startPrank(USER);
        uint256 _balance = mockPaymentToken.balanceOf(USER);
        mockSellToken.transferAndCall(address(sale), amount);
        uint256 balance_ = mockPaymentToken.balanceOf(USER);
        assertEq(balance_ - _balance, outputExpected, "Sold wrong amount");
    }

    function testRevertOnCallbackWithWrongToken() public {
        vm.expectRevert("Wrong token");
        mockOtherToken.transferAndCall(address(sale), 0);
    }

    function testRevertBuyOnCallbackWithWrongAmount(uint256 amount) public {
        amount = bound(amount, 0, initAmount);
        vm.assume(type(uint256).max > finalPrice * amount);
        uint256 inputRequired = sale.getBuyInput(amount);
        vm.assume(inputRequired > 0);
        deal(address(mockPaymentToken), USER, inputRequired);

        vm.startPrank(USER);
        vm.expectRevert("Not enough tokens sent");
        mockPaymentToken.transferAndCall(address(sale), inputRequired - 1, abi.encode(amount));
    }

    function testBuyOnCallbackReturnExceeded(uint256 amount, uint256 exceedAmount) public {
        amount = bound(amount, 0, initAmount);
        vm.assume(type(uint256).max > finalPrice * amount);
        uint256 inputRequired = sale.getBuyInput(amount);
        exceedAmount = bound(exceedAmount, 0, type(uint256).max - inputRequired);
        deal(address(mockPaymentToken), USER, inputRequired + exceedAmount);
        vm.startPrank(USER);

        mockPaymentToken.transferAndCall(address(sale), inputRequired + exceedAmount, abi.encode(amount));
        uint256 balance = mockPaymentToken.balanceOf(USER);
        assertEq(balance, exceedAmount, "Return wrong amount");
    }
}
