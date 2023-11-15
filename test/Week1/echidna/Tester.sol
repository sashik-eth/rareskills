pragma solidity 0.8.19;
import "./Setup.sol";
import {PropertiesAsserts} from "properties/util/PropertiesHelper.sol";

contract Tester is Setup, PropertiesAsserts {
    constructor() {
        _deploy();
    }

    function donateToken(uint256 amount, bool isSellToken) public {
        if (isSellToken) {
            mockSellToken.mint(address(sale), amount);
        } else {
            mockPaymentToken.mint(address(sale), amount);
        }
    }

    function totalValueInvariant() internal view returns (bool holds) {
        uint256 sellTokenBalance = mockSellToken.balanceOf(address(sale));
        if (sellTokenBalance > initAmount) return true;

        uint256 paymentTokenBalance = mockPaymentToken.balanceOf(address(sale));
        uint256 currentPrice = finalPrice - sellTokenBalance * (finalPrice - initPrice) / initAmount;

        return paymentTokenBalance >= ((initAmount - sellTokenBalance) * (currentPrice + initPrice)) / 2 ether;
    }

    function buy(uint amountToBuy) public initUser {
        uint256 amountToSpend = sale.getBuyInput(amountToBuy);
        _mintPaymentTokenOnce(amountToBuy);
        
        _before();

        (bool success, ) = user.proxy(
            address(sale),
            abi.encodeWithSelector(
                sale.buy.selector,
                amountToBuy,
                amountToSpend
            )
        );

        _after();

        assertWithMsg(totalValueInvariant(), "Total value is less than should be");

        if (success && amountToBuy != 0) {
            assertGte(
                sale.getSellOutput(vars.userBalanceSellAfter - vars.userBalanceSellBefore) * 1001 / 1000,
                vars.userBalancePaymentBefore - vars.userBalancePaymentAfter,
                "User didn't overpay"
            );
            assertGte( 
                vars.priceAfter,
                vars.priceBefore,
                "Price increase or remain after successful buy"
            );
            assertGt(
                vars.userBalancePaymentBefore,
                vars.userBalancePaymentAfter,
                "User payment balance decrease"
            );
            assertGt(
                vars.contractBalancePaymentAfter,
                vars.contractBalancePaymentBefore,
                "Sale contract payment balance increase"
            );
            assertGt(
                vars.userBalanceSellAfter,
                vars.userBalanceSellBefore,
                "User sell token balance increase"
            );
            assertGt(
                vars.contractBalanceSellBefore,
                vars.contractBalanceSellAfter,
                "Sale contract sell token balance decrease"
            );
        } else {
            assertEq(
                vars.priceAfter,
                vars.priceBefore,
                "Price remain after failed or 0 amount buy"
            );
            assertEq(
                vars.userBalancePaymentBefore,
                vars.userBalancePaymentAfter,
                "User payment balance remain"
            );
            assertEq(
                vars.contractBalancePaymentAfter,
                vars.contractBalancePaymentBefore,
                "Sale contract payment balance remain"
            );
            assertEq(
                vars.userBalanceSellAfter,
                vars.userBalanceSellBefore,
                "User sell token balance remain"
            );
            assertEq(
                vars.contractBalanceSellBefore,
                vars.contractBalanceSellAfter,
                "Sale contract sell token balance remain"
            );
        }
    }

    function buyWithHook(uint amountToBuy) public initUser {
        uint256 amountToSpend = sale.getBuyInput(amountToBuy);
        amountToSpend = clampBetween(amountToSpend, amountToSpend, type(uint256).max);
        _mintPaymentTokenOnce(amountToBuy);
        
        _before();

        (bool success, ) = user.proxy(
            address(mockPaymentToken),
            abi.encodeWithSignature(
                "transferAndCall(address,uint256,bytes)",
                address(sale),
                amountToSpend,
                abi.encode(amountToBuy)
            )
        );

        _after();

        assertWithMsg(totalValueInvariant(), "Total value is less than should be");

        if (success && amountToBuy != 0) {
            assertGte(
                sale.getSellOutput(vars.userBalanceSellAfter - vars.userBalanceSellBefore) * 1001 / 1000,
                vars.userBalancePaymentBefore - vars.userBalancePaymentAfter,
                "User didn't overpay"
            );
            assertGte(
                vars.priceAfter,
                vars.priceBefore,
                "Price increase or remain after successful buy"
            );
            assertGt(
                vars.userBalancePaymentBefore,
                vars.userBalancePaymentAfter,
                "User payment balance decrease"
            );
            assertGt(
                vars.contractBalancePaymentAfter,
                vars.contractBalancePaymentBefore,
                "Sale contract payment balance increase"
            );
            assertGt(
                vars.userBalanceSellAfter,
                vars.userBalanceSellBefore,
                "User sell token balance increase"
            );
            assertGt(
                vars.contractBalanceSellBefore,
                vars.contractBalanceSellAfter,
                "Sale contract sell token balance decrease"
            );
        } else {
            assertEq(
                vars.priceAfter,
                vars.priceBefore,
                "Price remain after failed or 0 amount buy"
            );
            assertEq(
                vars.userBalancePaymentBefore,
                vars.userBalancePaymentAfter,
                "User payment balance remain"
            );
            assertEq(
                vars.contractBalancePaymentAfter,
                vars.contractBalancePaymentBefore,
                "Sale contract payment balance remain"
            );
            assertEq(
                vars.userBalanceSellAfter,
                vars.userBalanceSellBefore,
                "User sell token balance remain"
            );
            assertEq(
                vars.contractBalanceSellBefore,
                vars.contractBalanceSellAfter,
                "Sale contract sell token balance remain"
            );
        }
    }

    function sell(uint amountToSell) public initUser {
        
        uint256 amountToReceive = sale.getSellOutput(amountToSell);
        _mintSellTokenOnce(amountToSell);
        
        _before();
        (bool success, ) = user.proxy(
            address(sale),
            abi.encodeWithSelector(
                sale.sell.selector,
                amountToSell,
                amountToReceive
            )
        );

        _after();

        assertWithMsg(totalValueInvariant(), "Total value is less than should be");
        
        if (success && amountToSell != 0) {
            assertGte( 
                vars.priceBefore,
                vars.priceAfter,
                "Price decrease or remain after successful sell"
            );
            assertGt(
                vars.userBalancePaymentAfter,
                vars.userBalancePaymentBefore,
                "User payment balance increase"
            );
            assertGt(
                vars.contractBalancePaymentBefore,
                vars.contractBalancePaymentAfter,
                "Sale contract payment balance decrease"
            );
            assertGt(
                vars.userBalanceSellBefore,
                vars.userBalanceSellAfter,
                "User sell token balance decrease"
            );
            assertGt(
                vars.contractBalanceSellAfter,
                vars.contractBalanceSellBefore,
                "Sale contract sell token balance increase"
            );
        } else {
            assertEq(
                vars.priceAfter,
                vars.priceBefore,
                "Price remain after failed or 0 amount sell"
            );
            assertEq(
                vars.userBalancePaymentBefore,
                vars.userBalancePaymentAfter,
                "User payment balance remain"
            );
            assertEq(
                vars.contractBalancePaymentAfter,
                vars.contractBalancePaymentBefore,
                "Sale contract payment balance remain"
            );
            assertEq(
                vars.userBalanceSellAfter,
                vars.userBalanceSellBefore,
                "User sell token balance remain"
            );
            assertEq(
                vars.contractBalanceSellBefore,
                vars.contractBalanceSellAfter,
                "Sale contract sell token balance remain"
            );
        }
    }

    function sellWithHook(uint amountToSell) public initUser {
        uint256 amountToSpend = sale.getBuyInput(amountToSell);
        amountToSpend = clampBetween(amountToSpend, amountToSpend, type(uint256).max);
        _mintSellTokenOnce(amountToSell);
        
        _before();

        (bool success, ) = user.proxy(
            address(mockSellToken),
            abi.encodeWithSignature(
                "transferAndCall(address,uint256)",
                address(sale),
                amountToSell
            )
        );

        _after();
        
        assertWithMsg(totalValueInvariant(), "Total value is less than should be");

        if (success && amountToSell != 0) {
            assertGte(
                vars.priceBefore,
                vars.priceAfter,
                "Price increase or remain after successful buy"
            );
            assertGt(
                vars.userBalancePaymentAfter,
                vars.userBalancePaymentBefore,
                "User payment balance increase"
            );
            assertGt(
                vars.contractBalancePaymentBefore,
                vars.contractBalancePaymentAfter,
                "Sale contract payment balance decrease"
            );
            assertGt(
                vars.userBalanceSellBefore,
                vars.userBalanceSellAfter,
                "User sell token balance decrease"
            );
            assertGt(
                vars.contractBalanceSellAfter,
                vars.contractBalanceSellBefore,
                "Sale contract sell token balance increase"
            );
        } else {
            assertEq(
                vars.priceAfter,
                vars.priceBefore,
                "Price remain after failed or 0 amount buy"
            );
            assertEq(
                vars.userBalancePaymentBefore,
                vars.userBalancePaymentAfter,
                "User payment balance remain"
            );
            assertEq(
                vars.contractBalancePaymentAfter,
                vars.contractBalancePaymentBefore,
                "Sale contract payment balance remain"
            );
            assertEq(
                vars.userBalanceSellAfter,
                vars.userBalanceSellBefore,
                "User sell token balance remain"
            );
            assertEq(
                vars.contractBalanceSellBefore,
                vars.contractBalanceSellAfter,
                "Sale contract sell token balance remain"
            );
        }
    }
}