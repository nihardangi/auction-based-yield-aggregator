// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./YieldAuction.sol";

contract Bidder is Ownable {
    /////////////////////////////////////
    ///           Errors              ///
    /////////////////////////////////////
    error Bidder__TokenTransferFailed();
    error Bidder__OnlyYieldAuctionContractCanCall();

    ////////////////////////////////////
    ///       State Variables        ///
    ////////////////////////////////////
    string public i_protocolName;
    IERC20 i_token;
    YieldAuction i_yieldAuctionContract;

    uint256 private constant YIELD_PRECISION = 1e18;

    mapping(address => uint256) s_userBalance;

    ///////////////////////////////////
    ///           Events           ///
    //////////////////////////////////
    event TokensTransferredWithYieldToUser(address indexed user, uint256 amount);

    ///////////////////////////////////
    ///         Modifiers           ///
    //////////////////////////////////
    modifier onlyYieldAuctionContract() {
        if (msg.sender != address(i_yieldAuctionContract)) {
            revert Bidder__OnlyYieldAuctionContractCanCall();
        }
        _;
    }

    ///////////////////////////////////
    ///         Functions           ///
    //////////////////////////////////
    constructor(string memory name, address tokenAddress, address payable yieldAuctionContract) Ownable(msg.sender) {
        i_protocolName = name;
        i_token = IERC20(tokenAddress);
        i_yieldAuctionContract = YieldAuction(yieldAuctionContract);
    }

    /////////////////////////////////////
    ///  External & Public Functions  ///
    /////////////////////////////////////
    function withdraw(address user, uint256 depositedAmount, uint256 promisedYield) external onlyYieldAuctionContract {
        uint256 totalTokens = depositedAmount + (promisedYield * depositedAmount) / YIELD_PRECISION;
        bool success = i_token.transfer(user, totalTokens);
        if (!success) {
            revert Bidder__TokenTransferFailed();
        }
        emit TokensTransferredWithYieldToUser(user, totalTokens);
    }
}
