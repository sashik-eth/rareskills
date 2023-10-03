// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract Token is ERC20 {
    address immutable STAKING;

    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {
        STAKING = msg.sender;
    }

    function mint(address receiver, uint256 amount) external {
        require(msg.sender == STAKING, "Only staking contract could mint");
        _mint(receiver, amount);
    }
}
