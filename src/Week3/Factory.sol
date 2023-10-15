// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Pair} from "./Pair.sol";

contract Factory {
    uint256 public allPairsLength;
    mapping(address => mapping(address => address)) private pairs;

    error SameTokens();
    error ZeroAddress();
    error NotFeeSetter();
    error PairExist();

    event PairCreated(address indexed token0, address indexed token1, address pair, uint256);
    event FeeReceiverUpdate(address indexed oldFeeReceiver, address indexed newFeeReceiver);
    event FeeSetterUpdate(address indexed oldFeeSetter, address indexed newFeeSetter);

    constructor() {}

    /**
     * @notice  Get trading pair by tokens addresses
     * @param   tokenA  address of the first trading token
     * @param   tokenB  address of the  second trading token
     * @return  pair  address of the created pair
     */
    function getPair(address tokenA, address tokenB) external view returns (address pair) {
        return pairs[tokenA][tokenB];
    }

    /**
     * @notice  Create new AMM pair
     * @param   tokenA  address of the first trading token
     * @param   tokenB  address of the  second trading token
     * @return  pair  address of the created pair
     */
    function createPair(address tokenA, address tokenB) external returns (address pair) {
        if (tokenA == tokenB) revert SameTokens();
        (tokenA, tokenB) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        if (tokenA == address(0)) revert ZeroAddress();
        if (pairs[tokenA][tokenB] != address(0)) revert PairExist();

        bytes memory bytecode = abi.encodePacked(type(Pair).creationCode, abi.encode(tokenA, tokenB));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), 0)
        }

        pairs[tokenA][tokenB] = pair;
        pairs[tokenB][tokenA] = pair;
        emit PairCreated(tokenA, tokenB, pair, ++allPairsLength);
    }
}
