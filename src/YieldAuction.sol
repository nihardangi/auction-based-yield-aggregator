// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/*
     * @title YieldAuction
     * @author Nihar Dangi
     *
     * The contract is designed to be as minimal as possible.    
     * 
     * Typical flow:
     * User deposits tokens
     * Defi protocols submits bids for user's tokens.
     * User selects the best bid.
     * Tokens to be transferred from user to a Defi protocol via EIP7702. Now, the protocol can invest these tokens and earn from it.
     * User can request a withdrawal at any time.
     * Protocol transfers the tokens with yield back to the user.     
     *
     * @notice This contract is the core of the yield auction engine. It handles all the logic
     * for placing a bid and processing a bid, as well as token withdrawal from selected Defi protocol.
     */
contract YieldAuction is Ownable {
    /////////////////////////////////////
    ///           Errors              ///
    /////////////////////////////////////
    error YieldAuction__AmountShouldBeGreaterThanZero();
    error YieldAuction__BidIndexGreaterThanAllowed();
    error YieldAuction__NoSelectedBidForWithdrawal();
    error YieldAuction__WithdrawalFailed();

    /////////////////////////////////////
    ///       Type Declaration        ///
    /////////////////////////////////////
    struct Bid {
        address bidder;
        uint256 promisedYield;
        uint256 amount;
    }

    ////////////////////////////////////
    ///       State Variables        ///
    ////////////////////////////////////
    mapping(address => Bid[]) s_bids;
    // mapping(address => uint256) s_balance;
    mapping(address => Bid) s_selectedBid;

    IERC20 immutable i_token;

    ///////////////////////////////////
    ///         Functions           ///
    //////////////////////////////////
    constructor(address tokenAddress) Ownable(msg.sender) {
        i_token = IERC20(tokenAddress);
    }

    fallback() external payable {}
    receive() external payable {}

    /////////////////////////////////////
    ///  External & Public Functions  ///
    /////////////////////////////////////
    /*
     * @param tokenHolder: Address of the user that owns the token for which protocol will submit a bid
     * @param promisedYield: Yield promised by the protocol to the user     
     * @notice This function will submit a bid for user's tokens. To be used by Defi protocols
     */
    function submitBid(address tokenHolder, uint256 promisedYield, uint256 amount) external {
        s_bids[tokenHolder].push(Bid(msg.sender, promisedYield, amount));
    }

    /*
     * @param bidIndex: Index of the bid that user wants to select.
     * @notice This function will transfer tokens from user to this smart contract. User's balance will be updated. 
     */
    function selectAndProcessBid(uint256 bidIndex) external {
        if (bidIndex >= s_bids[msg.sender].length) {
            revert YieldAuction__BidIndexGreaterThanAllowed();
        }
        s_selectedBid[msg.sender] = s_bids[msg.sender][bidIndex];
    }

    /*    
     * @notice This function will deposit your collateral and mint DSC in one transaction
     */
    function withdrawFromProtocol() external {
        Bid memory selectedBid = s_selectedBid[msg.sender];
        if (selectedBid.bidder == address(0)) {
            revert YieldAuction__NoSelectedBidForWithdrawal();
        }
        // Delete entry from selected bid state variable so that it gets set to the default value.
        delete(s_selectedBid[msg.sender]);
        (bool success,) = selectedBid.bidder.call(
            abi.encodeWithSignature(
                "withdraw(address,uint256,uint256)", msg.sender, selectedBid.amount, selectedBid.promisedYield
            )
        );
        if (!success) {
            revert YieldAuction__WithdrawalFailed();
        }
    }

    ////////////////////////////////////////////
    ///  Public and External View Functions  ///
    ////////////////////////////////////////////
    function getAllBids() external view returns (Bid[] memory) {
        return s_bids[msg.sender];
    }

    function getSelectedBid() external view returns (Bid memory) {
        return s_selectedBid[msg.sender];
    }
}
