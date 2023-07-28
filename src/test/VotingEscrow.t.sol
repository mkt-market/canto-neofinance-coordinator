// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.8.0;

import {DSTest} from "ds-test/test.sol";
import {Utilities} from "./utils/Utilities.sol";
import {console} from "./utils/Console.sol";
import {Vm} from "forge-std/Vm.sol";
import {StdAssertions} from "forge-std/StdAssertions.sol";

import {VotingEscrow} from "../VotingEscrow.sol";

contract VotingEscrowTest is DSTest, StdAssertions {
    Vm internal immutable vm = Vm(HEVM_ADDRESS);

    Utilities internal utils;
    address payable[] internal users;
    address alice;
    address bob;
    address charlie;

    VotingEscrow public votingEscrow;

    function setUp() public {
        utils = new Utilities();
        users = utils.createUsers(3);
        alice = users[0];
        bob = users[1];
        charlie = users[2];

        votingEscrow = new VotingEscrow("test", "TEST");
    }

    function testTotalSupplyAndTotalSupplyAt() public {
        uint256 week = votingEscrow.WEEK();
        uint256 locktime = votingEscrow.LOCKTIME();
        uint256 locktimeInWeeks = locktime / week;

        // Initial state
        assertEq(votingEscrow.totalSupply(), 0);
        assertEq(votingEscrow.totalSupplyAt(block.number), 0);

        vm.expectRevert("Only past block number");
        votingEscrow.totalSupplyAt(block.number + 1);

        // Create locks
        uint256 aliceAmount = 6e18;
        uint256 bobAmount = 3e18;
        uint256 charlieAmount = 1e18;

        vm.prank(alice);
        votingEscrow.createLock{ value: aliceAmount }(aliceAmount);
        vm.prank(bob);
        votingEscrow.createLock{ value: bobAmount }(bobAmount);
        vm.prank(charlie);
        votingEscrow.createLock{ value: charlieAmount }(charlieAmount);

        uint256 initialBalance = votingEscrow.totalSupply();
        uint256 decayWeekAprox = initialBalance / (5 * 52);

        // Until the last week
        for (uint256 _weeks; _weeks < locktimeInWeeks - 1; ++_weeks) {
            uint256 prevTot = votingEscrow.totalSupply();
            uint256 prevTotAt = votingEscrow.totalSupplyAt(block.number);

            vm.warp(block.timestamp + week);
            vm.roll(block.number + 1);
            votingEscrow.checkpoint();

            uint256 tot = votingEscrow.totalSupply();
            assertApproxEqRel(tot, prevTot - decayWeekAprox, 0.00000001e18); // 0,000001% Delta
            uint256 totAt = votingEscrow.totalSupplyAt(block.number);
            assertApproxEqRel(totAt, prevTotAt - decayWeekAprox, 0.00000001e18); // 0,000001% Delta
        }

        // Last week
        vm.warp(block.timestamp + week);
        vm.roll(block.number + 1);
        votingEscrow.checkpoint();

        assertEq(votingEscrow.totalSupply(), 0);
        assertEq(votingEscrow.totalSupplyAt(block.number), 0);
    }
}