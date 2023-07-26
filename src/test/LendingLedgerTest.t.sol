// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.8.0;

import {DSTest} from "ds-test/test.sol";
import {Utilities} from "./utils/Utilities.sol";
import {console} from "./utils/Console.sol";
import {Vm} from "forge-std/Vm.sol";

import "../LendingLedger.sol";

contract LendingLedgerTest is DSTest {
    Vm internal immutable vm = Vm(HEVM_ADDRESS);

    Utilities internal utils;
    address payable[] internal users;

    LendingLeder ledger;
    address guage = address(0);
    address goverance;

    uint256 public constant WEEK = 7 days;

    function setUp() public {
        utils = new Utilities();

        users = utils.createUsers(5);

        goverance = users[0];

        ledger = new LendingLeder(guage, goverance);
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

        uint256 fromEpoch = 0;
        uint256 toEpoch = 0;

        vm.startPrank(goverance);
        ledger.setRewards(fromEpoch, toEpoch, amountPerEpoch);

        fromEpoch = WEEK * 5 + 30 seconds;
        toEpoch = WEEK * 10 - 26 seconds;

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
}
