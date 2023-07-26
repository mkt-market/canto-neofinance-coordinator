// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.8.0;

import {DSTest} from "ds-test/test.sol";
import {Utilities} from "./utils/Utilities.sol";
import {console} from "./utils/Console.sol";
import {Vm} from "forge-std/Vm.sol";

import {LendingLeder} from "../LendingLedger.sol";

contract LendingLederTest is DSTest {
    Vm internal immutable vm = Vm(HEVM_ADDRESS);

    Utilities internal utils;
    address payable[] internal users;

    LendingLeder lendingLeder;

    function setUp() public {
        utils = new Utilities();
        users = utils.createUsers(5);

        lendingLeder = new LendingLeder(address(0), address(this));
    }

    function testTryClaimForEpochWithoutSetRewards() public {
        address payable alice = users[0];
        vm.label(alice, "Alice");
        address market = address(6);
        vm.label(market, "market");

        lendingLeder.whiteListLendingMarket(market, true);

        uint256 WEEK = lendingLeder.WEEK();

        vm.warp(block.timestamp + WEEK);

        vm.prank(market);
        lendingLeder.sync_ledger(alice, 1);

        vm.warp(block.timestamp + WEEK);

        vm.expectRevert("Reward not set yet");
        vm.prank(alice);
        lendingLeder.claim(
            market,
            (block.timestamp % WEEK) * WEEK,
            WEEK
        );
    }
}