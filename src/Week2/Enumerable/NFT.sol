// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {ERC721Enumerable, ERC721} from "openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract NFT is ERC721Enumerable {
    constructor(string memory name_, string memory symbol_, uint256 initMint) ERC721(name_, symbol_) {
        for (uint256 i = 1; i <= initMint; i++) {
            _mint(msg.sender, i);
        }
    }
}
