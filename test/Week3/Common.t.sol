// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {FixedPointMathLib, Pair, Factory} from "../../src/Week3/Pair.sol";
import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract Common is Test {
    Factory factory;
    ERC20 token0;
    ERC20 token1;
    Pair pair;

    address user;
    address admin;

    function testCreatePair(address tokenA, address tokenB) public returns (Pair _pair) {
        if (factory.getPair(tokenA, tokenB) != address(0)) vm.expectRevert(Factory.PairExist.selector);
        if (tokenA == tokenB) vm.expectRevert(Factory.SameTokens.selector);
        if (tokenA == address(0) || tokenB == address(0)) vm.expectRevert(Factory.ZeroAddress.selector);
        _pair = Pair(factory.createPair(tokenA, tokenB));
    }

    function testMintLp(address to, uint112 token0In, uint112 token1In) public returns (uint256 liquidity) {
        
        deal(address(token0), address(this), uint256(token0In));
        deal(address(token1), address(this), uint256(token1In));
        token0.transfer(address(pair), token0In);
        token1.transfer(address(pair), token1In);

        uint256 _balance = pair.balanceOf(to);
        if (FixedPointMathLib.sqrt(uint256(token0In) * token1In) <= pair.MINIMUM_LIQUIDITY() ) vm.expectRevert();
        if (to == address(0)) vm.expectRevert("ERC20: mint to the zero address");
        liquidity= pair.mint(to);
        uint256 balance_ = pair.balanceOf(to);
        assertEq(balance_ - _balance, liquidity, "Wrong amount of LP tokens minted");
    }

    function testBurn(address to, uint112 token0In, uint112 token1In) public returns (uint256 amount0, uint256 amount1)  {
        uint256 liquidity = testMintLp(to, token0In, token1In);
        vm.assume(pair.totalSupply() > 0);
        vm.assume(liquidity * token0.balanceOf(address(pair)) / pair.totalSupply() > 0);
        vm.assume(liquidity * token1.balanceOf(address(pair)) / pair.totalSupply() > 0);
        vm.prank(to);
        pair.transfer(address(pair), liquidity);
        uint256 _balance0 = token0.balanceOf(to);
        uint256 _balance1 = token1.balanceOf(to);
        if (to == address(0)) vm.expectRevert("ERC20: transfer to the zero address");
        (amount0, amount1) = pair.burn(to);
        uint256 balance0_ = token0.balanceOf(to);
        uint256 balance1_ = token1.balanceOf(to);
        assertEq(balance0_ - _balance0, amount0, "Wrong amount of token0 returned");
        assertEq(balance1_ - _balance1, amount1, "Wrong amount of token1 returned");
    }
}