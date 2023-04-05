// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.10;

import "../BaseTest.sol";
import "../../the-rewarder/AccountingToken.sol";
import "../../DamnValuableToken.sol";
import "../../the-rewarder/FlashLoanerPool.sol";
import "../../the-rewarder/TheRewarderPool.sol";
import "../../the-rewarder/RewardToken.sol";
import "../../the-rewarder/MaliciousContractReward.sol";

contract TheRewarder is BaseTest {

    uint TOKENS_IN_LENDER_POOL = 1000000 ether;

    AccountingToken accToken;
    FlashLoanerPool flashLoanerPool;
    TheRewarderPool rewarderPool;
    RewardToken rewardToken;
    DamnValuableToken liquidityToken;
    MaliciousContractReward maliciousContract;

    address attacker;
    address alice;
    address bob;
    address charlie;
    address david;

    constructor() {
        // setup the needed user accordly
        string[] memory labels = new string[](5);
        labels[0] = "Attacker";
        labels[1] = "Alice";
        labels[2] = "Bob";
        labels[3] = "Charlie";
        labels[4] = "David";
        preSetup(5, labels);
    }

    function setUp() public override {
        super.setUp();
        attacker = users[0];

        // Setup liquidityToken
        liquidityToken = new DamnValuableToken();
        vm.label(address(liquidityToken), "DamnValuableToken");

        // Setup flashLoanerPool and fund it
        flashLoanerPool = new FlashLoanerPool(address(liquidityToken));
        liquidityToken.transfer(address(flashLoanerPool), TOKENS_IN_LENDER_POOL);

        // Setup rewarderPool, rewardToken and accToken
        rewarderPool = new TheRewarderPool(address(liquidityToken));
        rewardToken = rewarderPool.rewardToken();
        accToken = rewarderPool.accToken();

        // Setup users deposits
        for( uint256 i = 1; i < users.length; i++ ) {
            uint256 amount = 100 ether;
            liquidityToken.transfer(users[i], amount);
            vm.startPrank(users[i]);
            liquidityToken.approve(address(rewarderPool), amount);
            rewarderPool.deposit(amount);
            vm.stopPrank();

            // verify accToken are minted
            assertEq(accToken.balanceOf(users[i]), amount);
        }
        // Assert accToken total supply = 400 and rewardToken total supply = 0
        assertEq(accToken.totalSupply(), 400 ether);
        assertEq(rewardToken.totalSupply(), 0);

        // Pass 5 days so in order to jump to the next round period
        utils.mineTime(5 days);

        // Assert each depositor get 25 tokens as a rewards
        for( uint256 i = 1; i < users.length; i++ ){
            vm.prank(users[i]);
            rewarderPool.distributeRewards();
            assertEq(rewardToken.balanceOf(users[i]), 25 ether);
        }

        // Assert total rewards supply = 100
        assertEq(rewardToken.totalSupply(), 100 ether);

        // Assert attacker has zero DVT tokens
        assertEq(liquidityToken.balanceOf(address(attacker)), 0);

        // Assert only two round have ocurred
        assertEq(rewarderPool.roundNumber(), 2);

        // As the attacker deploy the malicuousContract;
        vm.prank(attacker);
        maliciousContract = new MaliciousContractReward(
            address(flashLoanerPool),
            address(rewarderPool),
            address(liquidityToken),
            address(rewardToken));
    }

    function test_Exploit() public {
        runTest();
    }

    function exploit() internal override {
        /** CODE YOUR EXPLOIT HERE */
        // Jump another 5 days in order to jump to the next round
        utils.mineTime(5 days);
        // Attack
        vm.prank(attacker);
        maliciousContract.attack();
    }

    function success() internal override {
        /** SUCCESS CONDITIONS */
        assertEq(rewarderPool.roundNumber(), 3);

        for ( uint256 i = 1; i < users.length; i++ ){
            uint256 rewards = rewardToken.balanceOf(users[i]);
            // The difference between current and previous should be lower than 0.01 tokens
            uint256 delta = rewards - 25 ether;
            assertLt(delta, 0.01 ether);
        }
        // RewardsToken is grater than 100
        assertGt(rewardToken.totalSupply(), 100 ether);

        // Rewards issued to the attacker
        uint256 rewardsAttacker = rewardToken.balanceOf(attacker);
        uint256 deltaAttacker = 100 ether - rewardsAttacker;
        assertLt(deltaAttacker, 0.1 ether);

        // Attacker finishes with zero DVT tokens in balance
        assertEq(liquidityToken.balanceOf(attacker), 0);
    }
}