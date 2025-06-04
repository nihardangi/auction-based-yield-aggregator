// Layout of Contract:
// version
// imports
// interfaces, libraries, contracts
// errors
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./YieldAuction.sol";

contract Bidder is Ownable {
    // struct Bid {
    //     address bidder;
    //     uint256 promisedYield;
    // }

    string public i_protocolName;
    IERC20 i_token;

    mapping(address => uint256) s_userBalance;

    constructor(string memory name, address tokenAddress) Ownable(msg.sender) {
        i_protocolName = name;
        i_token = IERC20(tokenAddress);
    }

    function depositTokens(uint256 amount) external {
        i_token.transferFrom(msg.sender, address(this), amount);
        s_userBalance[msg.sender] += amount;
    }

    function submitBid(address yieldAuctionContract, uint256 promisedYield, bytes calldata contractCode)
        external
        onlyOwner
    {
        // bytes callData=abi.encodeCall(depositTokens,);

        abi.encodeCall(this.depositTokens, (promisedYield));
        // YieldAuction(yieldAuctionContract).submitBid(promisedYield,)
    }
}
