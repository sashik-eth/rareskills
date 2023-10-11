// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {LPT} from "./LPT.sol";
import {Factory} from "./Factory.sol";

import {Test} from "forge-std/Test.sol";
// TODO add eip3156
// TODO check TWAP 
// TODO add more unchecked
// TODO check other way to prevent inflationary attack
contract Pair is LPT, ReentrancyGuard, Test {
    Factory public immutable FACTORY;
    ERC20 public immutable TOKEN0;
    ERC20 public immutable TOKEN1;
    uint112 public constant UINT112_MAX = type(uint112).max;
    uint256 public constant MINIMUM_LIQUIDITY = 1000;
    bytes4 private constant SELECTOR = bytes4(keccak256(bytes("transfer(address,uint256)")));

    uint112 private reserve0;
    uint112 private reserve1;
    uint32 private blockTimestampLast;
 
    uint256 public price0CumulativeLast;
    uint256 public price1CumulativeLast;
    uint256 public kLast; // reserve0 * reserve1, as of immediately after the most recent liquidity event

    error Overflow();
    error LowLiquidity();
    error LowInputs();
    error Kbroke();
    error ZeroOutputs();
    error WrongToAddress();
    event Mint(address indexed sender, uint256 amount0, uint256 amount1);
    event Burn(address indexed sender, uint256 amount0, uint256 amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    constructor(address _token0, address _token1) LPT("AMM Pair", "AMP") {
        FACTORY = Factory(msg.sender);
        TOKEN0 = ERC20(_token0);
        TOKEN1 = ERC20(_token1);
    }

    function getReserves() public view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) {
        return (reserve0, reserve1, blockTimestampLast);
    }

    function mint(address to) external nonReentrant returns (uint256 liquidity) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        uint256 balance0 = TOKEN0.balanceOf(address(this));
        uint256 balance1 = TOKEN1.balanceOf(address(this));
        uint256 amount0 = balance0 - _reserve0;
        uint256 amount1 = balance1 - _reserve1;

        bool feeOn = _mintFee(_reserve0, _reserve1);
        uint256 _totalSupply = totalSupply();
        if (_totalSupply == 0) {
            liquidity = FixedPointMathLib.sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY;
            _mint(address(0xdead), MINIMUM_LIQUIDITY); 
        } else {
            uint256 liq0 = amount0 * _totalSupply / _reserve0;
            uint256 liq1 = amount1 * _totalSupply / _reserve1;
            if (liq0 < liq1) {
                liquidity = liq0;
            } else {
                liquidity = liq1;
            }
        }
        if (liquidity == 0) revert LowLiquidity();
        _mint(to, liquidity);

        _update(balance0, balance1, _reserve0, _reserve1);
        if (feeOn) kLast = uint256(reserve0) * reserve1;
        emit Mint(msg.sender, amount0, amount1);
    }

    function burn(address to) external nonReentrant returns (uint256 amount0, uint256 amount1)  {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // gas savings

        uint256 balance0 = TOKEN0.balanceOf(address(this));
        uint256 balance1 = TOKEN1.balanceOf(address(this));
        uint256 liquidity = balanceOf(address(this));

        bool feeOn = _mintFee(_reserve0, _reserve1);
        uint256 _totalSupply = totalSupply(); 
        amount0 = liquidity * balance0 / _totalSupply; 
        amount1 = liquidity * balance1 / _totalSupply; 

        if (amount0 == 0 || amount1 == 0) revert LowLiquidity();
        _burn(address(this), liquidity);

        SafeTransferLib.safeTransfer(TOKEN0, to, amount0);
        SafeTransferLib.safeTransfer(TOKEN1, to, amount1);
        balance0 = TOKEN0.balanceOf(address(this));
        balance1 = TOKEN1.balanceOf(address(this));

        _update(balance0, balance1, _reserve0, _reserve1);
        if (feeOn) kLast = uint256(reserve0) * reserve1; 
        emit Burn(msg.sender, amount0, amount1, to);
    }

    function swap(uint256 amount0Out, uint256 amount1Out, address to) external nonReentrant {
        if (amount0Out == 0 && amount1Out == 0) revert ZeroOutputs();
        (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // gas savings
        if (amount0Out >= _reserve0 || amount1Out >= _reserve1) revert LowLiquidity();

        uint256 balance0;
        uint256 balance1;

        if (to == address(TOKEN0) || to == address(TOKEN1)) revert WrongToAddress();

        if (amount0Out > 0) SafeTransferLib.safeTransfer(TOKEN0, to, amount0Out); 
        if (amount1Out > 0) SafeTransferLib.safeTransfer(TOKEN1, to, amount1Out);

        balance0 = TOKEN0.balanceOf(address(this));
        balance1 = TOKEN1.balanceOf(address(this));
        
        uint256 amount0In = balance0 > _reserve0 - amount0Out ? balance0 - (_reserve0 - amount0Out) : 0;
        uint256 amount1In = balance1 > _reserve1 - amount1Out ? balance1 - (_reserve1 - amount1Out) : 0;
        if (amount0In == 0 && amount1In == 0) revert LowInputs();
        
        uint256 balance0Adjusted = balance0 * 1000 - amount0In * 3;
        uint256 balance1Adjusted = balance1 * 1000 - amount1In * 3;
        if (balance0Adjusted * balance1Adjusted < uint256(_reserve0) * _reserve1 * 1000_000) revert Kbroke();
    
        _update(balance0, balance1, _reserve0, _reserve1);
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }

    function skim(address to) external nonReentrant {
        unchecked {
            // @audit safe?
            SafeTransferLib.safeTransfer(TOKEN0, to, TOKEN0.balanceOf(address(this)) - reserve0);
            SafeTransferLib.safeTransfer(TOKEN1, to, TOKEN1.balanceOf(address(this)) - reserve1);
        }
    }

    function sync() external nonReentrant {
        _update(TOKEN0.balanceOf(address(this)), TOKEN1.balanceOf(address(this)), reserve0, reserve1);
    }

    function _mintFee(uint112 _reserve0, uint112 _reserve1) private returns (bool feeOn) {
        address feeTo = FACTORY.feeReceiver();
        feeOn = feeTo != address(0);
        uint256 _kLast = kLast;
        if (feeOn) {
            if (_kLast != 0) {
                
                uint256 rootK = FixedPointMathLib.sqrt(uint256(_reserve0) * uint256(_reserve1));
                uint256 rootKLast = FixedPointMathLib.sqrt(_kLast);
                if (rootK > rootKLast) {
                    uint256 numerator = totalSupply() * (rootK - rootKLast);
                    uint256 denominator = rootK * 5 + rootKLast;
                    uint256 liquidity = numerator / denominator;
                    if (liquidity > 0) _mint(feeTo, liquidity);
                }
            }
        } else if (_kLast != 0) {
            kLast = 0;
        }
    }

    function _update(uint256 balance0, uint256 balance1, uint112 _reserve0, uint112 _reserve1) private {
        if (balance0 > UINT112_MAX || balance1 > type(uint112).max) revert Overflow(); // @audit really needed?
        uint256 blockTimestamp = block.timestamp % 2 ** 32;
        unchecked {
            uint256 timeElapsed = blockTimestamp - blockTimestampLast; 
            if (timeElapsed > 0 && _reserve0 > 0 && _reserve1 > 0) {
                price0CumulativeLast += FixedPointMathLib.mulDivDown(_reserve1, UINT112_MAX, _reserve0) * timeElapsed;
                price1CumulativeLast += FixedPointMathLib.mulDivDown(_reserve0, UINT112_MAX, _reserve1) * timeElapsed;
            }
        }
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        blockTimestampLast = uint32(blockTimestamp);
        emit Sync(uint112(balance0), uint112(balance1));
    }
}
