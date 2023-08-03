// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.8.0;

import {DSTest} from "ds-test/test.sol";
import {Utilities} from "./utils/Utilities.sol";
import {console} from "./utils/Console.sol";
import {Vm} from "forge-std/Vm.sol";

import {LendingLedger} from "../LendingLedger.sol";

contract LendingLederTest is DSTest {
    Vm internal immutable vm = Vm(HEVM_ADDRESS);

    Utilities internal utils;
    address payable[] internal users;

    LendingLedger lendingLeder;

    function setUp() public {
        utils = new Utilities();
        users = utils.createUsers(5);
        lendingLeder = new LendingLedger(address(0), address(0));
    }

    function testTryClaimWithInvalidStartEpoch() public {
        uint256 someWeeks = 7 * lendingLeder.WEEK();

        vm.expectRevert("Invalid timestamp");
        lendingLeder.claim(address(0), someWeeks + 1, type(uint256).max);

        vm.expectRevert("Invalid timestamp");
        lendingLeder.claim(address(0), someWeeks - 1, type(uint256).max);
    }

    function testTryClaimWithInvalidEndEpoch() public {
        uint256 someWeeks = 7 * lendingLeder.WEEK();

        vm.expectRevert("Invalid timestamp");
        lendingLeder.claim(address(0), type(uint256).max, someWeeks + 1);

        vm.expectRevert("Invalid timestamp");
        lendingLeder.claim(address(0), type(uint256).max, someWeeks - 1);
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
        lendingLeder.claim(market, (block.timestamp % WEEK) * WEEK, WEEK);
    }
}
