// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.8.0;

import {DSTest} from "ds-test/test.sol";
import {Utilities} from "./utils/Utilities.sol";
import {console} from "./utils/Console.sol";
import {Vm} from "forge-std/Vm.sol";

import "../LendingLedger.sol";

contract DummyGaugeController {
    function gauge_relative_weight_write(
        address _gauge,
        uint256 _time
    ) external returns (uint256) {
        return 1 ether;
    }
}

contract LendingLedgerTest is DSTest {
    Vm internal immutable vm = Vm(HEVM_ADDRESS);

    Utilities internal utils;
    address payable[] internal users;

    LendingLeder ledger;
    DummyGaugeController controller;
    address goverance;

    uint256 public constant WEEK = 7 days;

    address lendingMarket;

    address lender;

    function setUp() public {
        utils = new Utilities();

        users = utils.createUsers(5);

        goverance = users[0];

        controller = new DummyGaugeController();

        ledger = new LendingLeder(address(controller), goverance);

        lendingMarket = vm.addr(5201314);

        lender = users[1];
    }

    function testAddWhitelistLendingMarket() public {
        address lendingMarket = vm.addr(5201314);

        vm.prank(goverance);
        ledger.whiteListLendingMarket(lendingMarket, true);

        bool isWhitelisted = ledger.lendingMarketWhitelist(lendingMarket);
        assertTrue(isWhitelisted);
    }

    function testAddWhitelistLendingMarketAgain() public {
        address lendingMarket = vm.addr(5201314);

        vm.startPrank(goverance);
        ledger.whiteListLendingMarket(lendingMarket, true);

        bool isWhitelisted = ledger.lendingMarketWhitelist(lendingMarket);
        assertTrue(isWhitelisted);

        vm.expectRevert("No change");
        ledger.whiteListLendingMarket(lendingMarket, true);

        assertTrue(isWhitelisted);
    }

    function testRemoveWhitelistEntry() public {
        address lendingMarket = vm.addr(5201314);

        vm.startPrank(goverance);
        ledger.whiteListLendingMarket(lendingMarket, true);

        bool isWhitelisted = ledger.lendingMarketWhitelist(lendingMarket);
        assertTrue(isWhitelisted);

        ledger.whiteListLendingMarket(lendingMarket, false);

        isWhitelisted = ledger.lendingMarketWhitelist(lendingMarket);
        assertTrue(!isWhitelisted);
    }

    function testSetRewardWithInvalidEpoch() public {
        uint248 amountPerEpoch = 1 ether;

        uint256 fromEpoch = WEEK * 5 + 30 seconds;
        uint256 toEpoch = WEEK * 10 - 26 seconds;

        vm.expectRevert("Invalid timestamp");
        ledger.setRewards(fromEpoch, toEpoch, amountPerEpoch);
    }

    function testSetValidRewardDistribution() public {
        uint248 amountPerEpoch = 1 ether;

        uint256 fromEpoch = WEEK * 5;
        uint256 toEpoch = WEEK * 10;

        vm.startPrank(goverance);
        ledger.setRewards(fromEpoch, toEpoch, amountPerEpoch);

        for (uint256 i = fromEpoch; i <= toEpoch; i += WEEK) {
            (bool set, uint248 amount) = ledger.rewardInformation(i);
            assertTrue(set);
            assertTrue(amount == amountPerEpoch);
        }
    }

    function testSetRewardTwice() public {
        uint248 amountPerEpoch = 1 ether;

        uint256 fromEpoch = WEEK * 5;
        uint256 toEpoch = WEEK * 10;

        vm.startPrank(goverance);
        ledger.setRewards(fromEpoch, toEpoch, amountPerEpoch);

        vm.expectRevert("Rewards already set");
        ledger.setRewards(fromEpoch, toEpoch, amountPerEpoch);
    }

    function testSyncLedgerMarketNotWhitelisted() public {
        int256 delta = 0.5 ether;

        vm.startPrank(lendingMarket);
        vm.expectRevert("Market not whitelisted");
        ledger.sync_ledger(lender, delta);
    }
}
