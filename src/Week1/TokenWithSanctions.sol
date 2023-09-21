// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";

interface IERC1404 {
    function detectTransferRestriction(address from, address to, uint256 value) external view returns (uint8);
    function messageForTransferRestriction(uint8 restrictionCode) external view returns (string memory);
}

contract TokenWithSanctions is ERC20, Ownable, IERC1404 {
    event Blacklisted(address indexed user, bool status);

    uint8 public constant SUCCESS_CODE = 0;
    uint8 public constant SENDER_BLACKLISTED_CODE = 1;
    uint8 public constant RECEIVER_BLACKLISTED_CODE = 2;
    string public constant UNKNOWN_MESSAGE = "UNKNOWN";
    string public constant SUCCESS_MESSAGE = "SUCCESS";
    string public constant SENDER_BLACKLISTED_MESSAGE = "SENDER_BLACKLISTED";
    string public constant RECEIVER_BLACKLISTED_MESSAGE = "RECEIVER_BLACKLISTED";

    mapping(address => bool) private _blacklisted;

    constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) {}

    // @notice Blacklisting or removing holders from blacklist, callable by owner
    // @param user The address of holder
    // @param status Status of holder
    function blacklist(address user, bool status) external onlyOwner {
        require(user != address(0), "Zero address can't be restricted");
        _blacklisted[user] = status;
        emit Blacklisted(user, status);
    }

    /// @notice Detects if a transfer will be reverted and if so returns an appropriate reference code
    /// @param from Sending address
    /// @param to Receiving address
    /// @return Code by which to reference message for rejection reasoning
    function detectTransferRestriction(address from, address to, uint256) public view returns (uint8) {
        if (_blacklisted[from]) {
            return SENDER_BLACKLISTED_CODE;
        } else if (_blacklisted[to]) {
            return RECEIVER_BLACKLISTED_CODE;
        } else {
            return SUCCESS_CODE;
        }
    }

    /// @notice Returns a human-readable message for a given restriction code
    /// @param restrictionCode Identifier for looking up a message
    /// @return Text showing the restriction's reasoning
    function messageForTransferRestriction(uint8 restrictionCode) external pure returns (string memory) {
        if (restrictionCode == RECEIVER_BLACKLISTED_CODE) {
            return RECEIVER_BLACKLISTED_MESSAGE;
        } else if (restrictionCode == SENDER_BLACKLISTED_CODE) {
            return SENDER_BLACKLISTED_MESSAGE;
        } else if (restrictionCode == SUCCESS_CODE) {
            return SUCCESS_MESSAGE;
        } else {
            return UNKNOWN_MESSAGE;
        }
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal view override {
        if (detectTransferRestriction(from, to, amount) != 0) {
            revert("Transfer restricted");
        }
    }
}
