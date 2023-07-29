// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.8.0;

import {DSTest} from "ds-test/test.sol";
import {Utilities} from "./utils/Utilities.sol";
import {console} from "./utils/Console.sol";
import {Vm} from "forge-std/Vm.sol";

import "../LendingLedger.sol";

contract DummyGaugeController {
    function gauge_relative_weight_write(address _gauge, uint256 _time) external returns (uint256) {
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

    uint248 amountPerEpoch = 1 ether;

    uint256 fromEpoch = WEEK * 5;

    uint256 toEpoch = WEEK * 10;

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

    function whiteListMarket() internal {
        vm.prank(goverance);
        ledger.whiteListLendingMarket(lendingMarket, true);
    }

    function testSyncLedgerUnderflow() public {
        whiteListMarket();

        int256 delta = -100;
        vm.startPrank(lendingMarket);

        vm.expectRevert("Lender balance underflow");
        ledger.sync_ledger(lender, delta);
    }

    function testSyncLedgerWithoutGap() public {
        whiteListMarket();

        int256 delta = 1.1 ether;
        vm.startPrank(lendingMarket);
        ledger.sync_ledger(lender, delta);

        uint256 epoch = 0;

        uint256 lendingMarketBalance = ledger.lendingMarketBalances(lendingMarket, lender, epoch);

        assertTrue(lendingMarketBalance == uint256(delta));

        uint256 lendingMarketTotal = ledger.lendingMarketTotalBalance(lendingMarket, epoch);

        assertTrue(lendingMarketTotal == uint256(delta));
    }

    function testSyncLedgerWithGaps() public {
        // prepare
        whiteListMarket();
        vm.warp(block.timestamp + WEEK);

        vm.startPrank(lendingMarket);

        int256 deltaStart = 1 ether;
        uint256 epochStart = (block.timestamp / WEEK) * WEEK;
        ledger.sync_ledger(lender, deltaStart);

        // gaps of 3 week
        uint256 newTime = block.timestamp + 3 * WEEK;
        vm.warp(newTime);
        int256 deltaEnd = 1 ether;
        uint256 epochEnd = (newTime / WEEK) * WEEK;
        ledger.sync_ledger(lender, deltaEnd);

        // lender balance is forwarded and set
        uint256 lenderBalance = ledger.lendingMarketBalances(lendingMarket, lender, epochEnd);
        assertEq(lenderBalance, uint256(deltaStart) + uint256(deltaEnd));

        // total balance is forwarded and set
        uint256 totalBalance = ledger.lendingMarketTotalBalance(lendingMarket, epochEnd);
        assertEq(totalBalance, uint256(deltaStart) + uint256(deltaEnd));
    }

    function setupStateBeforeClaim() internal {
        whiteListMarket();

        vm.prank(goverance);
        ledger.setRewards(fromEpoch, toEpoch, amountPerEpoch);

        vm.warp(WEEK * 5);

        int256 delta = 1.1 ether;
        vm.prank(lendingMarket);
        ledger.sync_ledger(lender, delta);

        // airdrop ledger enough token balance for user to claim
        payable(ledger).transfer(1000 ether);

        vm.warp(WEEK * 20);
    }

    function testClaimValidLenderOneEpoch() public {
        setupStateBeforeClaim();

        uint256 balanceBefore = address(lender).balance;
        vm.prank(lender);
        ledger.claim(lendingMarket, fromEpoch, fromEpoch);
        uint256 balanceAfter = address(lender).balance;
        assertTrue(balanceAfter - balanceBefore == 1 ether);

        uint256 claimedEpoch = ledger.userClaimedEpoch(lendingMarket, lender);
        assertTrue(claimedEpoch - fromEpoch == WEEK);
    }
}
