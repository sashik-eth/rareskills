// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {IERC721Enumerable} from "openzeppelin-contracts/contracts/token/ERC721/extensions/IERC721Enumerable.sol";

contract Getter {
    IERC721Enumerable immutable nft;

    constructor(IERC721Enumerable _nft) {
        nft = _nft;
    }

    // @notice Returns count of prime Ids owned by address
    // @param owner Address of owner
    // @return count Number of prime Ids
    function getPrimeIdsCountOwnedBy(address owner) external view returns (uint256 count) {
        // could be unchecked safely since both math operations in loop could not overflow
        unchecked {
            uint256 balance = nft.balanceOf(owner);
            for (uint256 i; i < balance;) {
                uint256 id = nft.tokenOfOwnerByIndex(owner, i);
                if (!isNotPrime(id)) {
                    ++count;
                }
                ++i;
            }
        }
    }

    function isNotPrime(uint256 n) internal pure returns (bool notPrime) {
        assembly {
            let halfOfN := add(shr(1, n), 1)
            for { let i := 2 } lt(i, halfOfN) { i := add(i, 1) } {
                if iszero(mod(n, i)) {
                    notPrime := true
                    break
                }
            }
        }
    }
}
