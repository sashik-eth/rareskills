pragma solidity 0.8.19;

import {Staking} from "../../../src/Week2/NftStaking/Staking.sol";
import {NFT} from "../../../src/Week2/NftStaking/NFT.sol";
import {Token} from "../../../src/Week2/NftStaking/Token.sol";
import {IERC721Receiver} from "openzeppelin-contracts/contracts/token/ERC721/IERC721Receiver.sol";

contract User {
    function proxy(address _target, bytes memory _calldata)
        public
        payable
        returns (bool success, bytes memory returnData)
    {
        (success, returnData) = address(_target).call{value: msg.value}(_calldata);
    }

    function onERC721Received(address, address from, uint256 tokenId, bytes calldata) external view returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}

contract Setup {
    struct Vars {
        uint256 rewardsTotalSupplyBefore;
        uint256 rewardsTotalSupplyAfter;
        uint256 userRewardBalanceBefore;
        uint256 userRewardBalanceAfter;
        uint256 userStakingTimestampBefore;
        uint256 userStakingTimestampAfter;
        address nftOwnerBefore;
        address nftOwnerAfter;
        address tokenStakerBefore;
        address tokenStakerAfter;
    }

    uint256 immutable MAX_SUPPLY = 20;
    uint96 immutable DEFAULT_FEE = 250; // in base points
    uint256 immutable FULL_PRICE = 0.1 ether;
    uint256 immutable DISCOUNT_PRICE = 0.6 ether;
    uint256 immutable REWARDS_PER_DAY = 10 ether;
    bytes32 immutable MERKLE_ROOT = "";

    Staking staking;
    NFT nft;
    Token token;

    User internal user;
    mapping(address => uint256) internal tokenIds;
    Vars internal vars;
    uint256 internal ghostExpectedTotalClaimed;

    bool private complete;

    modifier initUser() {
        if (user == User(address(0))) {
            user = new User();
        }

        _;
    }

    function _deploy() internal {
        nft = new NFT("Test NFT", "TNFT", MAX_SUPPLY, DEFAULT_FEE, FULL_PRICE, DISCOUNT_PRICE, MERKLE_ROOT);
        staking = new Staking("Test Token", "TST",nft, REWARDS_PER_DAY);
        token = staking.token();
    }

    function _mintNFTOnce() internal {
        require(msg.value == FULL_PRICE);
        if (tokenIds[address(user)] != 0) return;

        user.proxy{value: FULL_PRICE}(address(nft), abi.encodeWithSignature("mint()"));
        tokenIds[address(user)] = nft.tokenId();
    }

    function _before() internal {
        vars.rewardsTotalSupplyBefore = token.totalSupply();
        vars.userRewardBalanceBefore = token.balanceOf(address(user));
        vars.nftOwnerBefore = nft.ownerOf(tokenIds[address(user)]);
        (vars.tokenStakerBefore, vars.userStakingTimestampBefore) = staking.stakes(tokenIds[address(user)]);
    }

    function _after() internal {
        vars.rewardsTotalSupplyAfter = token.totalSupply();
        vars.userRewardBalanceAfter = token.balanceOf(address(user));
        vars.nftOwnerAfter = nft.ownerOf(tokenIds[address(user)]);
        (vars.tokenStakerAfter, vars.userStakingTimestampAfter) = staking.stakes(tokenIds[address(user)]);
    }
}
