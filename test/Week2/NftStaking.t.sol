// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {Staking} from "../../src/Week2/NftStaking/Staking.sol";
import {NFT} from "../../src/Week2/NftStaking/NFT.sol";
import {Token} from "../../src/Week2/NftStaking/Token.sol";

contract NftStakingTest is Test {
    uint256 immutable MAX_SUPPLY = 20;
    uint96 immutable DEFAULT_FEE = 250; // in base points
    uint256 immutable FULL_PRICE = 0.1 ether;
    uint256 immutable DISCOUNT_PRICE = 0.6 ether;
    uint256 immutable REWARDS_PER_DAY = 10 ether;
    bytes32 immutable MERKLE_ROOT = 0x3db00218640696329ea5c096072fb16abc0552d235c3a2bd79ca10a161bef006; // root for USER and ADMIN addresses with index 1 and 2
    bytes32 immutable USER_PROOF = 0x10af03da28d6b63391879611293241a8de16ab745dfba6b22fb7c527149392ec;
    Staking staking;
    NFT nft;
    Token token;

    address user;
    address admin;

    function setUp() public {
        user = makeAddr("USER");
        admin = makeAddr("ADMIN");
        vm.prank(admin);
        nft = new NFT("Test NFT", "TNFT", MAX_SUPPLY, DEFAULT_FEE, FULL_PRICE, DISCOUNT_PRICE, MERKLE_ROOT);
        staking = new Staking("Test Token", "TST",nft, REWARDS_PER_DAY);
        token = staking.token();
    }

    function testMint(uint256 amount) public {
        amount = bound(amount, 0, MAX_SUPPLY);
        vm.deal(user, FULL_PRICE * amount);
        vm.startPrank(user);
        for (uint256 i; i < amount; ++i) {
            nft.mint{value: FULL_PRICE}();
        }
        vm.stopPrank();
        assertTrue(nft.balanceOf(user) == amount);
    }

    function testMintWithProof() public {
        vm.deal(user, DISCOUNT_PRICE);
        vm.startPrank(user);
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = USER_PROOF;
        nft.mint{value: DISCOUNT_PRICE}(1, proof);
        assertTrue(nft.balanceOf(user) == 1);
    }

    function testRevertIfReuseProof() public {
        testMintWithProof();
        vm.expectRevert("Already minted with this proof");
        testMintWithProof();
    }

    function testRevertIfMintTooMuch() public {
        testMint(MAX_SUPPLY);
        vm.deal(user, FULL_PRICE);
        vm.startPrank(user);
        vm.expectRevert("Max supply reached");
        nft.mint{value: FULL_PRICE}();
    }

    function testOnlyOwnerChangeRoyalty() public {
        vm.prank(user);
        vm.expectRevert();
        nft.setDefaultRoyalty(user, 100);

        vm.prank(admin);
        nft.setDefaultRoyalty(user, 100);
    }

    function testWithdraw() public {
        testMint(MAX_SUPPLY);

        uint256 _balance = admin.balance;
        vm.startPrank(admin);
        nft.withdraw(address(0));
        uint256 balance_ = admin.balance;
        assertEq(balance_ - _balance, MAX_SUPPLY * FULL_PRICE);

        nft.withdraw(address(token));
    }

    function testStakeClaimAndWithdraw() public {
        testMint(1);
        vm.startPrank(user);
        uint256 tokenId = 1;
        nft.safeTransferFrom(user, address(staking), 1);

        skip(2 days);

        staking.claim(tokenId);
        assertEq(REWARDS_PER_DAY * 2, token.balanceOf(user));

        staking.withdraw(tokenId);
        assertEq(nft.ownerOf(tokenId), user);
    }
}
