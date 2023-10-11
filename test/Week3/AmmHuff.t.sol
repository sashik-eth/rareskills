// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Common, ERC20, Factory} from "./Common.t.sol";

contract AmmHuffTest is Common {
    function setUp() public {
        vm.label(address(this), "TEST CONTRACT");
        admin = makeAddr("ADMIN");
        user = makeAddr("USER");

        token1 = new ERC20("Wrapped Eth", "WETH"); 
        vm.label(address(token1), "TOKEN1");
    }

}