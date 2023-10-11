// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Pair} from "./Pair.sol";

contract Factory {
    address public feeReceiver;
    address public feeSetter;
    mapping(address => mapping(address => address)) private pairs;
    address[] public allPairs;

    error SameTokens();
    error ZeroAddress();
    error NotFeeSetter();
    error PairExist();

    event PairCreated(address indexed token0, address indexed token1, address pair, uint256);
    event FeeReceiverUpdate(address indexed oldFeeReceiver, address indexed newFeeReceiver);
    event FeeSetterUpdate(address indexed oldFeeSetter, address indexed newFeeSetter);

    constructor(address _feeSetter) {
        feeSetter = _feeSetter;
    }

    function getPair(address tokenA, address tokenB) external view returns (address pair) {
        return pairs[tokenA][tokenB];
    }

    function allPairsLength() external view returns (uint256) {
        return allPairs.length;
    }

    function createPair(address tokenA, address tokenB) external returns (address pair) {
        if (tokenA == tokenB) revert SameTokens();
        (tokenA, tokenB) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        if (tokenA == address(0)) revert ZeroAddress();
        if (pairs[tokenA][tokenB] != address(0)) revert PairExist();

        //bytes memory bytecode = type(Pair).creationCode;
        bytes memory bytecode = abi.encodePacked(type(Pair).creationCode, abi.encode(tokenA, tokenB));

        //bytes32 salt = keccak256(abi.encodePacked(tokenA, tokenB));

        assembly {
            //pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
            pair := create2(0, add(bytecode, 32), mload(bytecode), 0)
        }
        //Pair(pair).initialize(tokenA, tokenB);
        pairs[tokenA][tokenB] = pair;
        pairs[tokenB][tokenA] = pair;
        allPairs.push(pair);
        emit PairCreated(tokenA, tokenB, pair, allPairs.length);
    }

    function setFeeTo(address _feeReceiver) external {
        if (msg.sender != feeSetter) {
            revert NotFeeSetter();
        }
        address oldFeeReceiver = feeReceiver;
        feeReceiver = _feeReceiver;
        emit FeeReceiverUpdate(oldFeeReceiver, _feeReceiver);
    }

    function setFeeToSetter(address _feeSetter) external {
        if (msg.sender != feeSetter) {
            revert NotFeeSetter();
        }
        address oldFeeSetter = feeSetter;
        feeSetter = _feeSetter;
        emit FeeSetterUpdate(oldFeeSetter, _feeSetter);
    }
}
