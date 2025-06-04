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

    /////////////////////////////////////
    ///       Type Declaration        ///
    /////////////////////////////////////
    struct Bid {
        address bidder;
        uint256 promisedYield;
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
     * @param amount: Amount of tokens that user wants to deposit.
     * @notice This function will transfer tokens from user to this smart contract. User's balance will be updated. 
     */
    // function deposit(uint256 amount) external payable {
    //     if (amount <= 0) {
    //         revert YieldAuction__AmountShouldBeGreaterThanZero();
    //     }
    //     i_token.transferFrom(msg.sender, address(this), amount);
    //     s_balance[msg.sender] += amount;
    // }

    /*
     * @param tokenHolder: Address of the user that owns the token for which protocol will submit a bid
     * @param promisedYield: Yield promised by the protocl to the user
     * @param contractCode: The amount of DSC you want to mint
     * @notice This function will deposit your collateral and mint DSC in one transaction
     */
    function submitBid(address tokenHolder, uint256 promisedYield) external {
        s_bids[tokenHolder].push(Bid(msg.sender, promisedYield));
    }

    /*
     * @param bidIndex: Index of the bid that user wants to select.
     * @notice This function will transfer tokens from user to this smart contract. User's balance will be updated. 
     */
    function selectAndProcessBid(uint256 bidIndex) external {
        if (s_bids[msg.sender].length < bidIndex) {
            revert YieldAuction__BidIndexGreaterThanAllowed();
        }
        s_selectedBid[msg.sender] = s_bids[msg.sender][bidIndex];
    }

    function withdrawFromProtocol() external {}

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
        console2.log("Inside getSelectedBid msg.sender------------", msg.sender);
        console2.log("bidder--------------", s_selectedBid[msg.sender].bidder);
        return s_selectedBid[msg.sender];
    }
}

// User deposits money
// Protocol submits a bid
// User selects a bid
// User's tokens are transferred to the protocol
// Protocol returns the token with yield
