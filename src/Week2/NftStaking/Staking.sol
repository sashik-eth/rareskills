// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {IERC721Receiver} from "openzeppelin-contracts/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC721} from "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import {Token} from "./Token.sol";

contract Staking is IERC721Receiver {
    struct StakeInfo {
        address staker;
        uint96 lastClaimAt;
    }

    uint256 immutable public REWARDS_PER_DAY;
    IERC721 immutable public nft;

    Token public token;
    mapping(uint256 => StakeInfo) public stakes;

    event Stake(address indexed staker, uint256 indexed tokenId);
    event Claim(address indexed staker, uint256 indexed tokenId, uint256 amount);
    event Withdraw(address indexed staker, uint256 indexed tokenId);

    constructor(string memory tokenName, string memory tokenSymbol, IERC721 _nft, uint256 _rewardsPerDay) {
        nft = _nft;
        REWARDS_PER_DAY = _rewardsPerDay;
        token = new Token(tokenName, tokenSymbol);
    }

    // @notice Hook that allows stake NFT by direct transfer 
    // @param from The address from which tokens transferred
    // @param tokenId If of transferred token
    function onERC721Received(address, address from, uint256 tokenId, bytes calldata) external returns (bytes4) {
        require(msg.sender == address(nft), "Wrong NFT");
        _stake(from, tokenId);
        return IERC721Receiver.onERC721Received.selector;
    }

    // @notice Withdraw staked NFT
    // @param tokenId Id of withdrawn NFT
    function withdraw(uint256 tokenId) external {
        require(stakes[tokenId].staker == msg.sender, "Only NFT staker could withdraw");
        _claim(tokenId);
        delete stakes[tokenId].staker;
        nft.safeTransferFrom(address(this), msg.sender, tokenId);
        emit Withdraw(msg.sender, tokenId);
    }

    // @notice Claim collected rewards
    // @param tokenId Id of claiming NFT
    function claim(uint256 tokenId) external {
        require(stakes[tokenId].staker == msg.sender, "Only NFT staker could claim");
        _claim(tokenId);
    }

    function _stake(address staker, uint256 tokenId) internal {
        stakes[tokenId].staker = staker;
        stakes[tokenId].lastClaimAt = uint96(block.timestamp);
        emit Stake(staker, tokenId);
    }

    function _claim(uint256 tokenId) internal {
        // could be unchecked safely since math operations here could not realistic overflow
        unchecked {
            uint256 daysPassed = (block.timestamp - stakes[tokenId].lastClaimAt) / 1 days;
            uint256 collectedRewards = REWARDS_PER_DAY * daysPassed;
            stakes[tokenId].lastClaimAt += uint96(daysPassed * 1 days);
            token.mint(msg.sender, collectedRewards);
            emit Claim(msg.sender, tokenId, collectedRewards);
        }
    }
}
