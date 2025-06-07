// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {YieldAuction} from "../src/YieldAuction.sol";
import {BatchTokenTransfer} from "../src/BatchTokenTransfer.sol";
import {Bidder} from "../src/Bidder.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("Mock Token", "MOCK") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract BatchTokenTransferTest is Test {
    // ANVIL KEY
    address constant TEST_USER_ADDRESS = 0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65;
    uint256 constant TEST_USER_PK = 0x47e179ec197488593b187f80a00eb0da91f1b9d0b13f8733639f19c30a34926a;
    uint256 constant YIELD_PRECISON = 1e18;

    YieldAuction yieldAuction;
    // The contract that users(EOA) will delegate execution to.
    BatchTokenTransfer implementation;
    Bidder protocol1;
    Bidder protocol2;
    // BatchCallAndSponsor public implementation;

    // ERC-20 token contract for minting test tokens.
    MockERC20 public token;

    function setUp() public {
        // Deploy an ERC-20 token contract
        token = new MockERC20();

        yieldAuction = new YieldAuction(address(token));
        // Deploy the delegation contract
        implementation = new BatchTokenTransfer(address(token), payable(address(yieldAuction)));
        protocol1 = new Bidder("Protocol 1", address(token), payable(address(yieldAuction)));
        protocol2 = new Bidder("Protocol 2", address(token), payable(address(yieldAuction)));

        //  Mint tokens for test user
        token.mint(TEST_USER_ADDRESS, 1e18);
    }

    function testSponsoredExecution() public {
        uint256 depositAmount = 1e18;
        uint256 promisedYieldByProtocol1 = 5e16;
        vm.prank(address(protocol1));
        yieldAuction.submitBid(TEST_USER_ADDRESS, promisedYieldByProtocol1, depositAmount);

        uint256 promisedYieldByProtocol2 = 7e16;
        vm.prank(address(protocol2));
        yieldAuction.submitBid(TEST_USER_ADDRESS, promisedYieldByProtocol2, depositAmount);

        vm.startPrank(TEST_USER_ADDRESS);
        yieldAuction.selectAndProcessBid(1);

        // assert(yieldAuction.getBalance(TEST_USER_ADDRESS) == depositAmount);
        YieldAuction.Bid memory selectedBid = yieldAuction.getSelectedBid();
        assert(selectedBid.bidder == address(protocol2));
        vm.stopPrank();

        // User has selected the protocol
        // Now protocol will transfer the tokens from user's account to its own address using EIP7702 (Protocol will sponsor the gas)

        // User signs a delegation allowing `implementation` to execute transactions on his behalf.
        Vm.SignedDelegation memory signedDelegation = vm.signDelegation(address(implementation), TEST_USER_PK);

        vm.startBroadcast(address(protocol2));
        vm.attachDelegation(signedDelegation);
        // Verify that user's account now temporarily behaves as a smart contract.
        bytes memory code = address(TEST_USER_ADDRESS).code;
        assert(code.length > 0);

        bytes memory functionParams = abi.encodePacked(address(protocol2), depositAmount);
        bytes32 digest = keccak256(abi.encodePacked(BatchTokenTransfer(TEST_USER_ADDRESS).nonce(), functionParams));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(TEST_USER_PK, MessageHashUtils.toEthSignedMessageHash(digest));
        bytes memory signature = abi.encodePacked(r, s, v);

        BatchTokenTransfer(TEST_USER_ADDRESS).transferToProtocol(signature, address(protocol2), depositAmount);

        vm.stopBroadcast();
        assert(token.balanceOf(address(protocol2)) == depositAmount);
        assert(token.balanceOf(TEST_USER_ADDRESS) == 0);

        // Let's assume that protocol will earn something using user's tokens.
        uint256 protocolEarnings = 1e17;
        token.mint(address(protocol2), protocolEarnings);
        vm.prank(TEST_USER_ADDRESS);
        yieldAuction.withdrawFromProtocol();

        assert(
            token.balanceOf(TEST_USER_ADDRESS)
                == depositAmount + (depositAmount * promisedYieldByProtocol2) / YIELD_PRECISON
        );
    }
}
