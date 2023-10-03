// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {ERC721Royalty, ERC721} from "openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721Royalty.sol";
import {Ownable2Step} from "openzeppelin-contracts/contracts/access/Ownable2Step.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {BitMaps} from "openzeppelin-contracts/contracts/utils/structs/BitMaps.sol";
import {MerkleProof} from "openzeppelin-contracts/contracts/utils/cryptography/MerkleProof.sol";

contract NFT is ERC721Royalty, Ownable2Step {
    event Mint(address indexed receiver, uint256 indexed tokenId, uint256 price);

    uint256 public immutable MAX_SUPPLY;
    uint256 public immutable FULL_PRICE;
    uint256 public immutable DISCOUNT_PRICE;
    bytes32 immutable MERKLE_ROOT;

    uint256 tokenId;
    BitMaps.BitMap bitMap;

    constructor(
        string memory name_,
        string memory symbol_,
        uint256 maxSupply,
        uint96 initFee,
        uint256 fullPrice,
        uint256 discountPrice,
        bytes32 merkleRoot
    ) ERC721(name_, symbol_) {
        MAX_SUPPLY = maxSupply;
        FULL_PRICE = fullPrice;
        DISCOUNT_PRICE = discountPrice;
        MERKLE_ROOT = merkleRoot;
        _setDefaultRoyalty(msg.sender, initFee);
    }

    function setDefaultRoyalty(address receiver, uint96 feeNumerator) external onlyOwner {
        _setDefaultRoyalty(receiver, feeNumerator);
    }

    // @notice Withdraw collected eth or accidental sent funds 
    // @param token address of withdrawn token, should be 0 for eth
    function withdraw(address token) external onlyOwner {
        if (token == address(0)) {
            msg.sender.call{value: (address(this).balance)}("");
        } else {
            IERC20(token).transfer(msg.sender, IERC20(token).balanceOf(address(this)));
        }
    }

    // @notice Mint token and pay full price
    function mint() external payable {
        require(msg.value == FULL_PRICE, "Not enough eth");
        _safeMint(msg.sender, FULL_PRICE);
    }

    // @notice Mint token and pay discount price
    // @param index position in bitMap reserved for caller address
    // @param merkleProof proof that caller address and index are in Merkle tree
    function mint(uint256 index, bytes32[] calldata merkleProof) external payable {
        require(msg.value == DISCOUNT_PRICE, "Not enough eth");

        bytes32 node = keccak256(abi.encodePacked(msg.sender, index));
        require(MerkleProof.verifyCalldata(merkleProof, MERKLE_ROOT, node), "Wrong merkle proof");

        require(!BitMaps.get(bitMap, index), "Already minted with this proof");
        BitMaps.set(bitMap, index);

        _safeMint(msg.sender, DISCOUNT_PRICE);
    }

    function _safeMint(address receiver, uint256 price) internal override {
        uint256 _tokenId = ++tokenId;
        require(_tokenId <= MAX_SUPPLY, "Max supply reached");

        super._safeMint(receiver, _tokenId);
        emit Mint(msg.sender, _tokenId, price);
    }
}
