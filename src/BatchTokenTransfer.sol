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

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "forge-std/console2.sol";
import "./YieldAuction.sol";

contract BatchTokenTransfer {
    error BatchTokenTransfer__OnlyEOAAllowedToCall();
    error BatchTokenTransfer__OnlySelectedProtocolCanCall();

    IERC20 immutable i_token;
    address payable immutable i_yieldAuction;

    /// @notice A nonce used for replay protection.
    uint256 public nonce;

    modifier onlySelectedProtocol(address protocol) {
        // YieldAuction(i_yieldAuction)

        if (YieldAuction(i_yieldAuction).getSelectedBid().bidder != protocol) {
            revert BatchTokenTransfer__OnlySelectedProtocolCanCall();
        }
        _;
    }

    constructor(address tokenAddress, address payable yieldAuction) {
        i_token = IERC20(tokenAddress);
        i_yieldAuction = yieldAuction;
    }

    // function directTransferToProtocol(address protocol, uint256 amount) external {
    //     if (msg.sender != address(this)) {
    //         revert BatchTokenTransfer__OnlyEOAAllowedToCall();
    //     }
    //     i_token.transfer(protocol, amount);
    //     nonce++;
    // }

    // First check if protocol is the one selected by the user (onlySelectedProtocol)
    // Perform signature validation
    // Transfer tokens to protocol

    // Now update in yieldAuction contract that amount has been transferred to which protocol.
    // Maybe not necessary as same information can be fetched from selectedBid state variable. Function will call selectAndProcessBid
    // and that will update the selectedBid state variable.
    function transferToProtocol(bytes calldata signature, address protocol, uint256 amount)
        external
        onlySelectedProtocol(protocol)
    {
        // Compute the digest that the account was expected to sign.
        bytes memory functionParams = abi.encodePacked(protocol, amount);
        bytes32 digest = keccak256(abi.encodePacked(nonce, functionParams));

        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(digest);

        // Recover the signer from the provided signature.
        address recovered = ECDSA.recover(ethSignedMessageHash, signature);
        require(recovered == address(this), "Invalid signature");
        i_token.transfer(protocol, amount);
        nonce++;
    }
}
