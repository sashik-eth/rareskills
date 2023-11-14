pragma solidity ^0.8.0;

import {TokenSale} from "../../../src/Week1/TokenSale.sol";
import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {ERC1363} from "erc1363-payable-token/contracts/token/ERC1363/ERC1363.sol";

contract User {
    function proxy(
        address _target,
        bytes memory _calldata
    ) public returns (bool success, bytes memory returnData) {
        (success, returnData) = address(_target).call(_calldata);
    }
}

contract MockERC1363 is ERC1363 {
    constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) {}

    function mint(address receiver, uint amount) external {
        _mint(receiver, amount);
    }
}

contract Setup {
    struct Vars {
        uint256 contractBalanceSellBefore;
        uint256 contractBalancePaymentBefore;
        uint256 contractBalanceSellAfter;
        uint256 contractBalancePaymentAfter;
        uint256 userBalanceSellBefore;
        uint256 userBalancePaymentBefore;
        uint256 userBalanceSellAfter;
        uint256 userBalancePaymentAfter;
        uint256 buyPriceBefore;
        uint256 buyPriceAfter;
        uint256 sellPriceBefore;
        uint256 sellPriceAfter;
    }

    uint256 initPrice = 100 ether;
    uint256 finalPrice = 300 ether;
    uint256 initAmount = 1_000_000 ether;
    uint256 endTimestamp = block.timestamp + 30 days;

    MockERC1363 mockSellToken;
    MockERC1363 mockPaymentToken;
    TokenSale sale;

    User internal user;
    Vars internal vars;

    bool private completePayment;
    bool private completeSell;

    modifier initUser() {
        if (user == User(address(0))) {
            user = new User();
        }

        _;
    }

    function _deploy() internal {
        mockSellToken = new MockERC1363("Mock Sell Token", "MST");
        mockPaymentToken = new MockERC1363("Mock Payment Token", "MPT");
        sale = new TokenSale(ERC20(address(mockSellToken)), ERC20(address(mockPaymentToken)), initPrice, finalPrice, initAmount, endTimestamp);

        mockSellToken.mint(address(this), initAmount);
        mockSellToken.approve(address(sale), initAmount);
        sale.deposit();
    }

    function _mintPaymentTokenOnce(uint256 amount) internal {
        if (completePayment) return;

        mockPaymentToken.mint(address(user), amount);

        user.proxy(
            address(mockPaymentToken),
            abi.encodeWithSelector(
                mockPaymentToken.approve.selector,
                address(sale),
                type(uint256).max
            )
        );
        completePayment = true;
    }

    function _mintSellTokenOnce(uint256 amount) internal {
        if (completeSell) return;

        mockSellToken.mint(address(user), amount);
        user.proxy(
            address(mockSellToken),
            abi.encodeWithSelector(
                mockSellToken.approve.selector,
                address(sale),
                type(uint256).max
            )
        );

        completeSell = true;
    }

    function _before() internal {
        vars.userBalanceSellBefore = mockSellToken.balanceOf(address(user));
        vars.userBalancePaymentBefore = mockPaymentToken.balanceOf(address(user));
        vars.contractBalanceSellBefore = mockSellToken.balanceOf(address(sale));
        vars.contractBalancePaymentBefore = mockPaymentToken.balanceOf(address(sale));
        vars.buyPriceBefore = sale.getBuyInput(1);
        vars.sellPriceBefore = sale.getSellOutput(1);
    }

    function _after() internal {
        vars.userBalanceSellAfter = mockSellToken.balanceOf(address(user));
        vars.userBalancePaymentAfter = mockPaymentToken.balanceOf(address(user));
        vars.contractBalanceSellAfter = mockSellToken.balanceOf(address(sale));
        vars.contractBalancePaymentAfter = mockPaymentToken.balanceOf(address(sale));
        vars.buyPriceAfter = sale.getBuyInput(1);
        vars.sellPriceAfter = sale.getSellOutput(1);
    }
}