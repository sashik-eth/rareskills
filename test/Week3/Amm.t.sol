// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {FixedPointMathLib, Pair, Factory} from "../../src/Week3/Pair.sol";
import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {IERC3156FlashBorrower} from "../../src/Week3/interfaces/IERC3156FlashBorrower.sol";

contract AmmTest is Test, IERC3156FlashBorrower {
    Factory factory;
    ERC20 token0;
    ERC20 token1;
    Pair pair;

    address user;
    address admin;

    function setUp() public {
        vm.label(address(this), "TEST CONTRACT");

        admin = makeAddr("ADMIN");
        user = makeAddr("USER");

        token1 = new ERC20("Wrapped Eth", "WETH");
        vm.label(address(token1), "TOKEN1");
        token0 = new ERC20("Circle token", "USDC");
        vm.label(address(token0), "TOKEN0");

        factory = new Factory();
        pair = testCreatePair(address(token0), address(token1));
    }

    function testCreatePair(address tokenA, address tokenB) public returns (Pair _pair) {
        if (factory.getPair(tokenA, tokenB) != address(0)) vm.expectRevert(Factory.PairExist.selector);
        if (tokenA == tokenB) vm.expectRevert(Factory.SameTokens.selector);
        if (tokenA == address(0) || tokenB == address(0)) vm.expectRevert(Factory.ZeroAddress.selector);
        _pair = Pair(factory.createPair(tokenA, tokenB));
    }

    function testCreatePairNoCollision(address tokenA, address tokenB, address tokenC) public {
        vm.assume(tokenA != tokenB);
        vm.assume(tokenA != tokenC);
        vm.assume(tokenB != tokenC);
        vm.assume(tokenA != address(0));
        vm.assume(tokenB != address(0));
        vm.assume(tokenC != address(0));

        Pair pair1 = testCreatePair(tokenA, tokenB);
        Pair pair2 = testCreatePair(tokenB, tokenC);
        Pair pair3 = testCreatePair(tokenA, tokenC);
        assertTrue(address(pair1) != address(0));
        assertTrue(address(pair2) != address(0));
        assertTrue(address(pair3) != address(0));
        assertTrue(pair1 != pair2);
        assertTrue(pair1 != pair3);
    }

    function testMintLp(address to, uint112 token0In, uint112 token1In) public returns (uint256 liquidity) {
        deal(address(token0), address(this), uint256(token0In));
        deal(address(token1), address(this), uint256(token1In));
        token0.transfer(address(pair), token0In);
        token1.transfer(address(pair), token1In);

        uint256 _balance = pair.balanceOf(to);
        if (FixedPointMathLib.sqrt(uint256(token0In) * token1In) <= pair.MINIMUM_LIQUIDITY()) vm.expectRevert();
        if (to == address(0)) vm.expectRevert("ERC20: mint to the zero address");
        liquidity = pair.mint(to);
        uint256 balance_ = pair.balanceOf(to);
        assertEq(balance_ - _balance, liquidity, "Wrong amount of LP tokens minted");
    }

    function testSwap(uint112 token0Mint, uint112 token1Mint, uint112 swapAmount) public {
        vm.assume(token0Mint > 1 ether);
        vm.assume(token1Mint > 1 ether);
        vm.assume(uint256(token0Mint) + swapAmount < type(uint112).max);
        vm.assume(swapAmount > 1 ether && swapAmount < token1Mint);
        testMintLp(address(this), token0Mint, token1Mint);

        vm.assume(swapAmount < token0Mint);
        deal(address(token0), user, swapAmount);
        vm.startPrank(user);
        token0.transfer(address(pair), swapAmount);

        (uint256 r0, uint256 r1,) = pair.getReserves();

        uint256 receiveAmount = token1Mint - (r0 * r1 / (token0Mint + swapAmount)) - 2;
        receiveAmount -= receiveAmount * 30 / 10000;

        uint256 _balance = token1.balanceOf(user);
        pair.swap(0, receiveAmount, user);
        uint256 balance_ = token1.balanceOf(user);

        assertEq(balance_ - _balance, receiveAmount);
    }

    function testBurn(address to, uint112 token0In, uint112 token1In)
        public
        returns (uint256 amount0, uint256 amount1)
    {
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

    function testMaxFlashLoan() public {
        uint256 amount = pair.maxFlashLoan(address(token0));
        assertEq(amount, token0.balanceOf(address(pair)), "Wrong max flashloan amount");
        amount = pair.maxFlashLoan(address(token1));
        assertEq(amount, token1.balanceOf(address(pair)), "Wrong max flashloan amount");
        amount = pair.maxFlashLoan(makeAddr("RANDOM TOKEN"));
        assertEq(amount, 0, "Max flashloan should be 0 for not supported token");
    }

    function testFlashLoan(uint256 amount, bool tokenOne) public {
        ERC20 token = tokenOne ? token1 : token0;
        testMintLp(admin, 100 ether, 100 ether);
        amount = bound(amount, 0, 100 ether);
        uint256 fee = pair.flashFee(address(token), amount);
        deal(address(token), address(this), fee);
        token.approve(address(pair), type(uint256).max);

        uint256 _balance = token.balanceOf(address(pair));
        if (amount > pair.maxFlashLoan(address(token))) vm.expectRevert("TRANSFER_FAILED");
        pair.flashLoan(IERC3156FlashBorrower(address(this)), address(token), amount, "TEST DATA");
        uint256 balance_ = token.balanceOf(address(pair));

        assertEq(balance_ - _balance, fee, "Wrong balance after flashloan");
    }

    function testFlashLoanRevert() public {
        testMintLp(admin, 100 ether, 100_000 ether);

        address receiver = address(new BadReceiver());

        vm.expectRevert(Pair.CallbackFailed.selector);
        pair.flashLoan(IERC3156FlashBorrower(receiver), address(token0), 1, "");
    }

    function onFlashLoan(address initiator, address token, uint256 amount, uint256 fee, bytes calldata data)
        external
        returns (bytes32)
    {
        require(initiator == address(this), "Wrong initiator received");
        require(keccak256(data) == keccak256("TEST DATA"), "Wrong calldata received");
        ERC20(token).approve(msg.sender, amount + fee);
        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }

    function testTwap() public {
        testMintLp(address(this), 100 ether, 100 ether);
        // price 1:1
        skip(1000);

        deal(address(token0), user, 50 ether);
        vm.startPrank(user);
        token0.transfer(address(pair), 50 ether);
        uint256 res = 33333333333333333333;
        res -= res * 30 / 10000;
        pair.swap(0, res, user);
        // price 1.5:0.66 = 2.27

        skip(1000);

        token1.transfer(address(pair), res);
        pair.swap(1, 0, user);
        // pice 1:1
        uint256 price0CumulativeLast = pair.price0CumulativeLast();
        uint256 price1CumulativeLast = pair.price1CumulativeLast();
        emit log_uint(price0CumulativeLast / 2000); // (1.5/0.66 + 1 ) / 2 ~ 1.63
        emit log_uint(price1CumulativeLast / 2000); // (0.66/1.5 + 1 ) / 2 ~ 0.72
    }
}

contract BadReceiver {
    function onFlashLoan(address, address, uint256, uint256, bytes calldata) external pure returns (bytes32 res) {}
}
