// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {ERC20Permit, ERC20} from "openzeppelin-contracts/contracts/token/ERC20/Extensions/ERC20Permit.sol";

contract LPT is ERC20Permit {
    constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) ERC20Permit(_name) {}
}
