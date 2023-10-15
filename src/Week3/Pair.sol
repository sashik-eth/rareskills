// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {LPT} from "./LPT.sol";
import {Factory} from "./Factory.sol";
import {IERC3156FlashBorrower} from "./interfaces/IERC3156FlashBorrower.sol";
import {IERC3156FlashLender} from "./interfaces/IERC3156FlashLender.sol";

contract Pair is LPT, ReentrancyGuard, IERC3156FlashLender {
    Factory public immutable FACTORY;
    ERC20 public immutable TOKEN0;
    ERC20 public immutable TOKEN1;
    uint112 public constant UINT112_MAX = type(uint112).max;
    uint256 public constant MINIMUM_LIQUIDITY = 1000;
    bytes4 private constant SELECTOR = bytes4(keccak256(bytes("transfer(address,uint256)")));
    uint256 private constant BASE_POINTS = 10_000;
    uint256 private constant FEE = 30;

    uint256 public price0CumulativeLast;
    uint256 public price1CumulativeLast;

    uint112 private reserve0;
    uint112 private reserve1;
    uint32 private blockTimestampLast;

    error Overflow();
    error LowLiquidity();
    error LowInputs();
    error Kbroke();
    error ZeroOutputs();
    error WrongToAddress();
    error TokenNotSupported();
    error CallbackFailed();

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

    /**
     * @notice  Get reserves values
     * @return  _reserve0  reserve amount of the first trading token
     * @return  _reserve1  reserve amount of the second trading token
     * @return  _blockTimestampLast  timestamp of the last reserves update
     */
    function getReserves() external view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) {
        return (reserve0, reserve1, blockTimestampLast);
    }

    // @dev The fee to be charged for a given loan.
    // @param token The loan currency.
    // @param amount The amount of tokens lent.
    // @return The amount of `token` to be charged for the loan, on top of the returned principal.
    function flashFee(address token, uint256 amount) public view returns (uint256 fee) {
        if (token != address(TOKEN0) && token != address(TOKEN1)) revert TokenNotSupported();
        fee = amount * FEE / BASE_POINTS;
    }

    /**
     * @dev The amount of currency available to be lent.
     * @param token The loan currency.
     * @return amount The amount of `token` that can be borrowed.
     */
    function maxFlashLoan(address token) external view returns (uint256 amount) {
        if (token == address(TOKEN0)) {
            amount = TOKEN0.balanceOf(address(this));
        } else if (token == address(TOKEN1)) {
            amount = TOKEN1.balanceOf(address(this));
        }
    }

    /**
     * @dev Initiate a flash loan.
     * @param receiver The receiver of the tokens in the loan, and the receiver of the callback.
     * @param token The loan currency.
     * @param amount The amount of tokens lent.
     * @param data Arbitrary data structure, intended to contain user-defined parameters.
     */
    function flashLoan(IERC3156FlashBorrower receiver, address token, uint256 amount, bytes calldata data)
        external
        nonReentrant
        returns (bool)
    {
        (uint112 _reserve0, uint112 _reserve1) = (reserve0, reserve1);

        SafeTransferLib.safeTransfer(ERC20(token), address(receiver), amount);
        uint256 fee = flashFee(token, amount);

        if (receiver.onFlashLoan(msg.sender, token, amount, fee, data) != keccak256("ERC3156FlashBorrower.onFlashLoan"))
        {
            revert CallbackFailed();
        }

        unchecked {
            SafeTransferLib.safeTransferFrom(ERC20(token), address(receiver), address(this), amount + fee);
        }

        uint256 balance0 = TOKEN0.balanceOf(address(this));
        uint256 balance1 = TOKEN1.balanceOf(address(this));
        _update(balance0, balance1, _reserve0, _reserve1);
        return true;
    }

    /**
     * @notice  Mint new LP tokens
     * @param   to  receiver of LPs
     * @return  liquidity  amount of minted LPs
     */
    function mint(address to) external nonReentrant returns (uint256 liquidity) {
        (uint112 _reserve0, uint112 _reserve1) = (reserve0, reserve1);
        uint256 balance0 = TOKEN0.balanceOf(address(this));
        uint256 balance1 = TOKEN1.balanceOf(address(this));
        uint256 amount0 = balance0 - _reserve0;
        uint256 amount1 = balance1 - _reserve1;

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
        emit Mint(msg.sender, amount0, amount1);
    }

    /**
     * @notice  Burn LP tokens
     * @param   to tokens receiver address
     * @return  amount0 amount of received token0
     * @return  amount1 amount of received token1
     */
    function burn(address to) external nonReentrant returns (uint256 amount0, uint256 amount1) {
        (uint112 _reserve0, uint112 _reserve1) = (reserve0, reserve1);

        uint256 balance0 = TOKEN0.balanceOf(address(this));
        uint256 balance1 = TOKEN1.balanceOf(address(this));
        uint256 liquidity = balanceOf(address(this));

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
        emit Burn(msg.sender, amount0, amount1, to);
    }

    /**
     * @notice  Swap tokens
     * @param   amount0Out  Desired amount of token 0
     * @param   amount1Out  Desired amount of token 1
     * @param   to  Receiver address of swapped tokens
     */
    function swap(uint256 amount0Out, uint256 amount1Out, address to) external nonReentrant {
        if (amount0Out == 0 && amount1Out == 0) revert ZeroOutputs();
        (uint112 _reserve0, uint112 _reserve1) = (reserve0, reserve1);
        if (amount0Out >= _reserve0 || amount1Out >= _reserve1) revert LowLiquidity();
        if (amount0Out > 0) SafeTransferLib.safeTransfer(TOKEN0, to, amount0Out);
        if (amount1Out > 0) SafeTransferLib.safeTransfer(TOKEN1, to, amount1Out);

        uint256 balance0 = TOKEN0.balanceOf(address(this));
        uint256 balance1 = TOKEN1.balanceOf(address(this));

        uint256 amount0In = balance0 > _reserve0 - amount0Out ? balance0 - (_reserve0 - amount0Out) : 0;
        uint256 amount1In = balance1 > _reserve1 - amount1Out ? balance1 - (_reserve1 - amount1Out) : 0;
        if (amount0In == 0 && amount1In == 0) revert LowInputs();

        uint256 balance0Adjusted = balance0 * BASE_POINTS - amount0In * FEE;
        uint256 balance1Adjusted = balance1 * BASE_POINTS - amount1In * FEE;
        if (balance0Adjusted * balance1Adjusted < uint256(_reserve0) * _reserve1 * BASE_POINTS * BASE_POINTS) {
            revert Kbroke();
        }

        _update(balance0, balance1, _reserve0, _reserve1);
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }

    /**
     * @notice Force reserves to match balances
     */
    function sync() external nonReentrant {
        _update(TOKEN0.balanceOf(address(this)), TOKEN1.balanceOf(address(this)), reserve0, reserve1);
    }

    function _update(uint256 balance0, uint256 balance1, uint112 _reserve0, uint112 _reserve1) private {
        unchecked {
            if (balance0 > UINT112_MAX || balance1 > UINT112_MAX) revert Overflow();
            uint32 blockTimestamp = uint32(block.timestamp % 2 ** 32);
            uint256 timeElapsed = blockTimestamp - blockTimestampLast; // overflow is intended
            if (timeElapsed > 0 && _reserve0 > 0 && _reserve1 > 0) {
                price0CumulativeLast += FixedPointMathLib.mulDivDown(_reserve1, 1e18, _reserve0) * timeElapsed;
                price1CumulativeLast += FixedPointMathLib.mulDivDown(_reserve0, 1e18, _reserve1) * timeElapsed;
            }
            reserve0 = uint112(balance0);
            reserve1 = uint112(balance1);
            blockTimestampLast = blockTimestamp;
            emit Sync(uint112(balance0), uint112(balance1));
        }
    }
}
