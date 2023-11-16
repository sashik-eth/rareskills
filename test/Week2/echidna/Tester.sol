pragma solidity 0.8.19;

import "./Setup.sol";
import {PropertiesAsserts} from "properties/util/PropertiesHelper.sol";

contract Tester is Setup, PropertiesAsserts {
    constructor() {
        _deploy();
    }

    function stakeWithHook() public payable initUser {
        _mintNFTOnce();
        uint256 tokenId = tokenIds[address(user)];

        _before();

        (bool success,) = user.proxy(
            address(nft),
            abi.encodeWithSignature(
                "safeTransferFrom(address,address,uint256)", address(user), address(staking), tokenId
            )
        );

        _after();

        if (success) {
            assertWithMsg(vars.nftOwnerBefore == address(user), "User should be owner of NFT before");
            assertWithMsg(vars.nftOwnerAfter == address(staking), "NFT transfer incorrect");

            assertWithMsg(vars.tokenStakerBefore == address(0), "Staker address should 0 before staking");
            assertWithMsg(vars.tokenStakerAfter == address(user), "Staker address should be user after staking");

            assertEq(vars.userRewardBalanceAfter, vars.userRewardBalanceBefore, "User's reward balance should remain");
            assertEq(vars.rewardsTotalSupplyBefore, vars.rewardsTotalSupplyAfter, "Reward total supply should remain");
            assertEq(vars.userStakingTimestampBefore, 0, "User staking timestamp should be 0 before staking");
            assertEq(
                vars.userStakingTimestampAfter,
                block.timestamp,
                "User staking timestamp should be equal to current time after staking"
            );
        } else {
            assertWithMsg(vars.tokenStakerBefore == vars.tokenStakerAfter, "Staker address should remain");
            assertWithMsg(vars.nftOwnerBefore == vars.nftOwnerAfter, "NFT should not transfer");
            assertEq(vars.userRewardBalanceAfter, vars.userRewardBalanceBefore, "User's reward balance should remain");
            assertEq(vars.rewardsTotalSupplyBefore, vars.rewardsTotalSupplyAfter, "Reward total supply should remain");
            assertEq(
                vars.userStakingTimestampBefore, vars.userStakingTimestampAfter, "User staking timestamp should remain"
            );
        }

        assertEq(
            ghostExpectedTotalClaimed,
            token.totalSupply(),
            "Total supply of rewards should be equal to expected ghost value"
        );
    }

    function withdraw() public initUser {
        uint256 tokenId = tokenIds[address(user)];

        _before();

        (bool success,) = user.proxy(address(staking), abi.encodeWithSignature("withdraw(uint256)", tokenId));

        _after();

        if (success) {
            uint256 expectedRewards =
                ((block.timestamp - vars.userStakingTimestampBefore) / 1 days) * staking.REWARDS_PER_DAY();
            ghostExpectedTotalClaimed += expectedRewards;

            assertEq(
                vars.userRewardBalanceAfter - vars.userRewardBalanceBefore,
                expectedRewards,
                "User's reward balance should increased correctly"
            );
            assertEq(
                vars.rewardsTotalSupplyAfter - vars.rewardsTotalSupplyBefore,
                expectedRewards,
                "Reward total supply should increased correctly"
            );

            assertWithMsg(vars.nftOwnerBefore == address(staking), "NFT owner incorrect");
            assertWithMsg(vars.nftOwnerAfter == address(user), "User should be owner of NFT after");

            assertWithMsg(vars.tokenStakerBefore == address(user), "Staker address should be user before withdraw");
            assertWithMsg(vars.tokenStakerAfter == address(0), "Staker address should be 0 after withdraw");

            assertGt(vars.userStakingTimestampBefore, 0, "User staking timestamp should be > 0 before withdraw");
            assertEq(vars.userStakingTimestampAfter, 0, "User staking timestamp should be equal to 0 after withdraw");
        } else {
            assertWithMsg(vars.tokenStakerBefore == vars.tokenStakerAfter, "Staker address should remain");
            assertWithMsg(vars.nftOwnerBefore == vars.nftOwnerAfter, "NFT should not transfer");
            assertEq(vars.userRewardBalanceAfter, vars.userRewardBalanceBefore, "User's reward balance should remain");
            assertEq(vars.rewardsTotalSupplyBefore, vars.rewardsTotalSupplyAfter, "Reward total supply should remain");
            assertEq(
                vars.userStakingTimestampBefore, vars.userStakingTimestampAfter, "User staking timestamp should remain"
            );
        }

        assertEq(
            ghostExpectedTotalClaimed,
            token.totalSupply(),
            "Total supply of rewards should be equal to expected ghost value"
        );
    }

    function claim() public initUser {
        uint256 tokenId = tokenIds[address(user)];

        _before();

        (bool success,) = user.proxy(address(staking), abi.encodeWithSignature("claim(uint256)", tokenId));

        _after();

        if (success) {
            uint256 expectedRewards =
                ((block.timestamp - vars.userStakingTimestampBefore) / 1 days) * staking.REWARDS_PER_DAY();
            ghostExpectedTotalClaimed += expectedRewards;

            assertEq(
                vars.userRewardBalanceAfter - vars.userRewardBalanceBefore,
                expectedRewards,
                "User's reward balance should increased correctly"
            );
            assertEq(
                vars.rewardsTotalSupplyAfter - vars.rewardsTotalSupplyBefore,
                expectedRewards,
                "Reward total supply should increased correctly"
            );

            assertWithMsg(vars.nftOwnerBefore == address(staking), "NFT owner incorrect");
            assertWithMsg(vars.nftOwnerAfter == address(staking), "NFT owner incorrect");

            assertWithMsg(vars.tokenStakerBefore == address(user), "Staker address should be user before claim");
            assertWithMsg(vars.tokenStakerAfter == address(user), "Staker address should be user after claim");

            assertGt(vars.userStakingTimestampBefore, 0, "User staking timestamp should be > 0 before claim");
            assertEq(
                vars.userStakingTimestampAfter,
                vars.userStakingTimestampBefore
                    + ((block.timestamp - vars.userStakingTimestampBefore) / 1 days) * 1 days,
                "User staking timestamp should increase correctly after claim"
            );
        } else {
            assertWithMsg(vars.tokenStakerBefore == vars.tokenStakerAfter, "Staker address should remain");
            assertWithMsg(vars.nftOwnerBefore == vars.nftOwnerAfter, "NFT should not transfer");
            assertEq(vars.userRewardBalanceAfter, vars.userRewardBalanceBefore, "User's reward balance should remain");
            assertEq(vars.rewardsTotalSupplyBefore, vars.rewardsTotalSupplyAfter, "Reward total supply should remain");
            assertEq(
                vars.userStakingTimestampBefore, vars.userStakingTimestampAfter, "User staking timestamp should remain"
            );
        }

        assertEq(
            ghostExpectedTotalClaimed,
            token.totalSupply(),
            "Total supply of rewards should be equal to expected ghost value"
        );
    }
}
