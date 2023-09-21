// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";

contract DelayEscrow is ReentrancyGuard {
    using SafeERC20 for IERC20;

    event Locked(address indexed token, address indexed seller, uint256 indexed endTimestamp, uint256 amount);
    event Withdraw(address indexed token, address indexed seller, uint256 indexed endTimestamp, uint256 amount);

    mapping(address => mapping(address => mapping(uint256 => uint256))) public lockedAmounts;

    uint256 public immutable DELAY = 3 days;

    // @notice Deposit and lock tokens for seller
    // @notice Should not be used with rebasing tokens
    // @param The address of token
    // @param The address of seller
    // @param Amount of locked tokens
    function deposit(IERC20 token, address seller, uint256 amount) external nonReentrant {
        uint256 _balance = token.balanceOf(address(this));
        token.transferFrom(msg.sender, address(this), amount);
        uint256 balance_ = token.balanceOf(address(this));

        uint256 endTimestamp = block.timestamp + DELAY;
        uint256 lockedAmount = balance_ - _balance;

        lockedAmounts[address(token)][seller][endTimestamp] += lockedAmount;
        emit Locked(address(token), seller, endTimestamp, lockedAmount);
    }

    // @notice Withdraw locked amount after delay
    // @param token The address of withdrawn token
    // @param timestamp Time market of locked potion of tokens
    function withdraw(IERC20 token, uint256 timestamp) external {
        require(timestamp < block.timestamp, "Too early");
        uint256 amount = lockedAmounts[address(token)][msg.sender][timestamp];
        delete lockedAmounts[address(token)][msg.sender][timestamp];
        token.safeTransfer(msg.sender, amount);
        emit Locked(address(token), msg.sender, timestamp, amount);
    }
}
