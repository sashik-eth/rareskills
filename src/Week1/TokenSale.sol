// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {Owned} from "solmate/auth/Owned.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

// contract TokenSale is Ownable, IERC1363Receiver {
contract TokenSale is Owned {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;

    event Buy(address indexed buyer, uint256 bought, uint256 payed);
    event Sell(address indexed seller, uint256 sold, uint256 received);

    ERC20 immutable sellToken;
    ERC20 immutable paymentToken;
    uint256 immutable k;
    uint256 immutable initBalance;
    uint256 immutable initPrice;
    uint256 public immutable endTimestamp;

    uint256 public tokensSold;

    // @param _sellToken The address of sell token
    // @param _paymentToken The address of payment token
    // @param _initPrice Initial price of tokens
    // @param _finalPrice Final price of tokens
    // @param _initAmount Amount of tokens that would be available for sale
    // @param _endTimestamp Sale ending timestamp
    constructor(
        address _sellToken,
        address _paymentToken,
        uint256 _initPrice,
        uint256 _finalPrice,
        uint256 _initAmount,
        uint256 _endTimestamp
    ) Owned(msg.sender) {
        sellToken = ERC20(_sellToken);
        paymentToken = ERC20(_paymentToken);
        initBalance = _initAmount;
        initPrice = _initPrice;
        endTimestamp = _endTimestamp;
        k = (_finalPrice - _initPrice).divWadDown(initBalance);
    }

    // @notice Withdraw all tokens after sale ends
    // @dev Could be called only by OWNER
    // @param token The address of withdrawn token
    function withdraw(address token) external onlyOwner {
        require(block.timestamp > endTimestamp, "Too early withdraw");
        ERC20(token).safeTransfer(msg.sender, ERC20(token).balanceOf(address(this)));
    }

    // @notice Deposit initial tokens
    function deposit() external {
        sellToken.safeTransferFrom(msg.sender, address(this), initBalance);
    }

    // @notice Hook that allows buy and sell tokens by direct sending them using ERC1363Receiver#transferAndCall
    // @param spender The address that initiate transfer
    // @param sender The address from which tokens transferred
    // @param amount number of transferred tokens
    // @param data arbitrary user data, in case of buying should include buying amount
    function onTransferReceived(address, address sender, uint256 amount, bytes calldata data)
        external
        returns (bytes4)
    {
        if (msg.sender == address(paymentToken)) {
            uint256 output = abi.decode(data, (uint256));
            uint256 input = getBuyInput(output);
            require(input <= amount, "Not enough tokens sent");
            tokensSold += output;
            sellToken.safeTransfer(sender, output);
            if (amount > input) {
                paymentToken.safeTransfer(sender, amount - input);
            }
            emit Buy(sender, output, input);
        } else if (msg.sender == address(sellToken)) {
            uint256 output = getSellOutput(amount);
            tokensSold -= amount;
            paymentToken.safeTransfer(sender, output);
            emit Sell(sender, amount, output);
        } else {
            revert("Wrong token");
        }
        return bytes4(keccak256("onTransferReceived(address,address,uint256,bytes)"));
    }

    // @notice Buy tokens
    // @param amount Amount of tokens to buy
    // @param maxInput Max amount of payment tokens that buyer allows to pay
    function buy(uint256 amount, uint256 maxInput) external {
        uint256 input = _buy(amount);
        require(input <= maxInput, "Too expensive trade");
    }

    // @notice Sell tokens
    // @param amount Amount of tokens to sell
    // @param minOutput Min amount of payment tokens that seller allows to receive
    function sell(uint256 amount, uint256 minOutput) external {
        uint256 output = _sell(amount);
        require(output >= minOutput, "Too expensive trade");
    }

    // @notice Get amount of payment tokens that should be payed for specified amount of sell tokens
    // @param amount Tokens to buy
    // @return Tokens to pay
    function getBuyInput(uint256 amount) public view returns (uint256) {
        uint256 priceNow = tokensSold.mulWadUp(k) + initPrice;
        uint256 priceAfter = (tokensSold + amount).mulWadUp(k) + initPrice;
        return (priceNow + priceAfter + 1).mulWadUp(amount) / 2;
    }

    // @notice Get amount of payment tokens that would be payed for specified amount of sell tokens
    // @param amount Tokens to sell
    // @return Tokens would received
    function getSellOutput(uint256 amount) public view returns (uint256) {
        uint256 priceNow = (tokensSold).mulWadDown(k) + initPrice;
        uint256 priceAfter = (tokensSold - amount).mulWadDown(k) + initPrice;
        return (priceNow + priceAfter).mulWadDown(amount) / 2;
    }

    function _buy(uint256 amount) internal returns (uint256 input) {
        input = getBuyInput(amount);
        tokensSold += amount;
        paymentToken.safeTransferFrom(msg.sender, address(this), input);
        sellToken.safeTransfer(msg.sender, amount);
        emit Buy(msg.sender, amount, input);
    }

    function _sell(uint256 amount) internal returns (uint256 output) {
        output = getSellOutput(amount);
        tokensSold -= amount;
        sellToken.safeTransferFrom(msg.sender, address(this), amount);
        paymentToken.safeTransfer(msg.sender, output);
        emit Buy(msg.sender, amount, output);
    }
}
