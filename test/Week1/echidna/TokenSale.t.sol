
// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {TokenSale} from "../../../src/Week1/TokenSale.sol";
import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {ERC1363} from "erc1363-payable-token/contracts/token/ERC1363/ERC1363.sol";


contract MockERC1363 is ERC1363 {
    constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) {}

    function mint(address receiver, uint amount) external {
        _mint(receiver, amount);
    }
}

contract TokenSaleTest {

    uint256 initPrice = 100 ether;
    uint256 finalPrice = 300 ether;
    uint256 initAmount = 1_000_000 ether;
    uint256 endTimestamp = block.timestamp + 30 days;
    MockERC1363 mockSellToken;
    MockERC1363 mockPaymentToken;
    TokenSale sale;
    constructor() {
        mockSellToken = new MockERC1363("Mock Sell Token", "MST");
        mockPaymentToken = new MockERC1363("Mock Payment Token", "MPT");
        sale = new TokenSale(ERC20(address(mockSellToken)), ERC20(address(mockPaymentToken)), initPrice, finalPrice, initAmount, endTimestamp);

        mockSellToken.mint(address(this), initAmount);
        mockSellToken.approve(address(sale), initAmount);
        sale.deposit();
    }

    function echidna_totalBalanceCorrect() public view returns(bool) {
        uint256 sellTokenBalance = mockSellToken.balanceOf(address(sale));
        if (sellTokenBalance > initAmount) return true;

        uint256 paymentTokenBalance = mockPaymentToken.balanceOf(address(sale));
        uint256 currentPrice = finalPrice - sellTokenBalance * (finalPrice - initPrice) / initAmount;

        return paymentTokenBalance >= ((initAmount - sellTokenBalance) * (currentPrice + initPrice)) / 2 ether;
    }

    function harnessBuy(uint256 amount) public {
        uint256 inputRequired = sale.getBuyInput(amount);
        mockPaymentToken.mint(address(this), inputRequired);
        mockPaymentToken.approve(address(sale), inputRequired);
        sale.buy(amount, inputRequired);
    }

    function harnessSell(uint256 amount) public {
        uint256 output = sale.getSellOutput(amount);
        mockSellToken.mint(address(this), amount);
        mockSellToken.approve(address(sale), amount);
        sale.sell(amount, output);
    }

    function harnessHookBuy(uint256 amount) public {
        uint256 inputRequired = sale.getBuyInput(amount);
        mockPaymentToken.mint(address(this), inputRequired);
        mockPaymentToken.transferAndCall(address(sale), inputRequired, abi.encode(amount));
    }

    function harnessHookSell(uint256 amount) public {
        mockSellToken.mint(address(this), amount);
        mockSellToken.transferAndCall(address(sale), amount);
    }

    function donateToken(uint256 amount, bool isSellToken) public {
        if (isSellToken) {
            mockSellToken.mint(address(sale), amount);
        } else {
            mockPaymentToken.mint(address(sale), amount);
        }
    }
}

