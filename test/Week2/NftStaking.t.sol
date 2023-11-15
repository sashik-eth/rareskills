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

    function testMintRevert(uint256 value) public {
        value = bound(value, 0, FULL_PRICE - 1);
        vm.deal(user, value);
        vm.prank(user);
        vm.expectRevert("Not enough eth");
        nft.mint{value: value}();
    }

    function testMintWithProof() public {
        vm.deal(user, DISCOUNT_PRICE);
        vm.startPrank(user);
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = USER_PROOF;
        nft.mint{value: DISCOUNT_PRICE}(1, proof);
        assertTrue(nft.balanceOf(user) == 1);
    }

    function testMintWithProofRevert(uint256 value) public {
        value = bound(value, 0, DISCOUNT_PRICE - 1);
        vm.deal(user, DISCOUNT_PRICE);

        bytes32[] memory proof = new bytes32[](1);
        
        vm.prank(user);
        vm.expectRevert("Wrong merkle proof");
        nft.mint{value: DISCOUNT_PRICE}(1, proof);    

        proof[0] = USER_PROOF;

        vm.prank(user);
        vm.expectRevert("Not enough eth");
        nft.mint{value: value}(1, proof);


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

        Token mockToken = new Token("Mock", "MCK");

        changePrank(address(234));
        vm.expectRevert("Only staking contract could mint");
        mockToken.mint(address(nft), 1 wei);

        changePrank(admin);
        mockToken.mint(address(nft), 1 wei);
        _balance = mockToken.balanceOf(address(nft));
        nft.withdraw(address(mockToken));
        balance_ = mockToken.balanceOf(address(nft));
        assertEq(_balance - balance_, 1 wei);
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

    function testStakeRevert() public {
        NFT mockNft = new NFT("Test NFT", "TNFT", MAX_SUPPLY, DEFAULT_FEE, FULL_PRICE, DISCOUNT_PRICE, MERKLE_ROOT); 
        vm.deal(user, FULL_PRICE);
        vm.startPrank(user);
        mockNft.mint{value: FULL_PRICE}();

        uint256 tokenId = 1;
        vm.expectRevert("Wrong NFT");
        mockNft.safeTransferFrom(user, address(staking), 1);
    }

    function testWithdrawRevert() public {
        testMint(1);
        vm.startPrank(user);
        uint256 tokenId = 1;
        nft.safeTransferFrom(user, address(staking), 1);

        skip(2 days);
        changePrank(address(234));
        vm.expectRevert("Only NFT staker could withdraw");
        staking.withdraw(tokenId);
    }

    function testClaimRevert() public {
        testMint(1);
        vm.startPrank(user);
        uint256 tokenId = 1;
        nft.safeTransferFrom(user, address(staking), 1);

        skip(2 days);
        changePrank(address(234));
        vm.expectRevert("Only NFT staker could claim");
        staking.claim(tokenId);
    }
}
