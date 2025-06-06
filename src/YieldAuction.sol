// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./BatchCallAndSponsor.sol";

/*
     * @title YieldAuction
     * @author Nihar Dangi
     *
     * The contract is designed to be as minimal as possible.
     * 
     * 
     * 
     * 
     * This is a stablecoin with the properties:
     * - Exogenously Collateralized
     * - Dollar Pegged
     * - Algorithmically Stable
     *
     * It is similar to DAI if DAI had no governance, no fees, and was backed by only WETH and WBTC.
     *
     * Our DSC system should always be "overcollateralized". At no point, should the value of
     * all collateral < the $ backed value of all the DSC.
     *
     * @notice This contract is the core of the Decentralized Stablecoin system. It handles all the logic
     * for minting and redeeming DSC, as well as depositing and withdrawing collateral.
     * @notice This contract is based on the MakerDAO DSS system
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
        (bool success,) = selectedBid.bidder.call(
            abi.encodeWithSignature(
                "withdraw(address,uint256,uint256)", msg.sender, selectedBid.amount, selectedBid.promisedYield
            )
        );
        if (!success) {
            revert YieldAuction__WithdrawalFailed();
        }
        // Update selected bid state variable and set it to default value after withdrawal by user.
        delete(s_selectedBid[msg.sender]);
    }

    ////////////////////////////////////////////
    ///  Public and External View Functions  ///
    ////////////////////////////////////////////
    function getAllBids() external view returns (Bid[] memory) {
        return s_bids[msg.sender];
    }

    // function getBalance(address user) external view returns (uint256) {
    //     return s_balance[user];
    // }

    function getSelectedBid() external view returns (Bid memory) {
        return s_selectedBid[msg.sender];
    }
}

// User deposits money
// Protocol submits a bid
// User selects a bid
// User's tokens are transferred to the protocol
// Protocol returns the token with yield
