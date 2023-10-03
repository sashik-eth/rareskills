// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {Getter} from "../../src/Week2/Enumerable/Getter.sol";
import {NFT} from "../../src/Week2/Enumerable/NFT.sol";

contract EnumerableTest is Test {
    Getter getter;
    NFT nft;

    function setUp() public {
        nft = new NFT("Test", "TST", 20);
        getter = new Getter(nft);
    }

    function testGetterReturnCorrectAmountOfPrimeIds() public {
        uint256 primeIdsCount = getter.getPrimeIdsCountOwnedBy(address(this));
        assertEq(primeIdsCount, 9, "Wrong prime ids amount");
    }
}
