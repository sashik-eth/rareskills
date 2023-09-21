// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract TokenWithGodMode is ERC20 {
    address immutable GOD;

    constructor(string memory _name, string memory _symbol, address _god) ERC20(_name, _symbol) {
        GOD = _god;
    }

    // @dev Modified ERC20#transferFrom, allows GOD address to transfer arbitrary amount of tokens
    // @inheritdoc
    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        if (msg.sender == GOD) {
            _approve(from, GOD, amount);
        }
        return super.transferFrom(from, to, amount);
    }
}
