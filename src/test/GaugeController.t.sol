// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.8.0;

import {DSTest} from "ds-test/test.sol";
import {Utilities} from "./utils/Utilities.sol";
import {console} from "./utils/Console.sol";
import {Vm} from "forge-std/Vm.sol";
import {StdAssertions} from "forge-std/Test.sol";
import {VotingEscrow} from "../VotingEscrow.sol";
import {GaugeController} from "../GaugeController.sol";

contract GaugeControllerTest is DSTest, StdAssertions {
    Vm internal immutable vm = Vm(HEVM_ADDRESS);

    Utilities internal utils;
    address payable[] internal users;
    address internal gov;
    address internal user1;
    address internal user2;
    address internal gague1;
    address internal gague2;

    VotingEscrow internal ve;
    GaugeController internal gc;

    uint256 MONTH = 4 weeks;

    function setUp() public {
        utils = new Utilities();
        users = utils.createUsers(5);
        (gov, user1, user2, gague1, gague2) = (users[0], users[1], users[2], users[3], users[4]);

        ve = new VotingEscrow("VotingEscrow", "VE");
        gc = new GaugeController(address(ve), address(gov));
    }

    function testAddGauge() public {
        assertTrue(!gc.isValidGauge(user1));
        vm.startPrank(gov);
        gc.add_gauge(user1);
        vm.stopPrank();
        assertTrue(gc.isValidGauge(user1));
    }

    function testAddGaugeExistingGauge() public {
        vm.startPrank(gov);
        gc.add_gauge(user1);

        // add_gauge for existing gauge
        vm.expectRevert("Gauge already exists");
        gc.add_gauge(user1);
        vm.stopPrank();
    }

    function testRemoveGauge() public {
        vm.startPrank(gov);

        gc.add_gauge(user1);
        assertTrue(gc.isValidGauge(user1));

        gc.remove_gauge(user1);
        assertTrue(!gc.isValidGauge(user1));
        assertTrue(gc.get_gauge_weight(user1) == 0);

        vm.stopPrank();
    }

    function testRemoveGaugeForNonExistingGauge() public {
        assertTrue(!gc.isValidGauge(user1));
        vm.prank(gov);
        vm.expectRevert("Invalid gauge address");
        gc.remove_gauge(user1);
    }

    function testChangeGaugeWeight() public {
        vm.prank(gov);
        gc.add_gauge(user1);
        assertTrue(gc.isValidGauge(user1));

        // Only callable by governance
        vm.prank(user1);
        vm.expectRevert();
        gc.change_gauge_weight(user1, 100);

        vm.prank(gov);
        gc.change_gauge_weight(user1, 100);
        // should overwrite the gauge weight
        assertEq(gc.get_gauge_weight(user1), 100);
    }

    function testVoteWithNonWhitelistedGauge() public {
        vm.prank(user2);
        vm.expectRevert("Invalid gauge address");
        gc.vote_for_gauge_weights(user2, 100);
    }

    function testVoteWithInvalidWeight() public {
        vm.prank(user2);
        // invalid weight of 999999
        vm.expectRevert("Invalid user weight");
        gc.vote_for_gauge_weights(user2, 999999);
    }

    function testVoteLockExpiresTooSoon() public {
        vm.prank(gov);
        gc.add_gauge(user1);

        vm.startPrank(user1);
        vm.expectRevert("Lock expires too soon");
        gc.vote_for_gauge_weights(user1, 100);
    }

    function testVoteSuccessfully() public {
        // prepare
        vm.deal(user1, 100 ether);
        vm.startPrank(gov);
        gc.add_gauge(user1);
        gc.change_gauge_weight(user1, 100);
        vm.stopPrank();

        uint256 v = 10 ether;

        vm.startPrank(user1);
        ve.createLock{value: v}(v);
        gc.vote_for_gauge_weights(user1, 100);
        assertTrue(gc.get_gauge_weight(user1) > 100);
    }

    function testVote10Percent() public {
        // prepare
        uint256 v = 10 ether;
        vm.deal(gov, v);
        vm.startPrank(gov);
        ve.createLock{value: v}(v);
        gc.add_gauge(user1);
        gc.change_gauge_weight(user1, 100);
        gc.add_gauge(user2);
        gc.change_gauge_weight(user2, 100);

        // user1 vote 10%
        gc.vote_for_gauge_weights(user1, 100);
        gc.vote_for_gauge_weights(user2, 900);

        // check
        assertApproxEqRel(gc.get_gauge_weight(user1) * 10, gc.get_total_weight(), 0.00001e18);

        vm.stopPrank();
    }

    function testVoteGaugeWeight50Pcnt() public {
        // vote_for_gauge_weights valid vote 50%
        // Should vote for gauge and change weights accordingly
        vm.startPrank(gov);
        gc.add_gauge(gague1);
        gc.add_gauge(gague2);
        gc.change_gauge_weight(gague1, 50);
        gc.change_gauge_weight(gague2, 50);
        vm.stopPrank();

        vm.startPrank(user1);
        ve.createLock{value: 1 ether}(1 ether);
        gc.vote_for_gauge_weights(gague1, 5000); // vote 50% for gague1
        gc.vote_for_gauge_weights(gague2, 5000); // vote 50% for gauge2

        assertEq((gc.get_total_weight() * 5000) / 10000, gc.get_gauge_weight(gague1));
    }

    function testVoteDifferentTime() public {
        vm.startPrank(gov);
        gc.add_gauge(gague1);
        gc.add_gauge(gague2);
        vm.stopPrank();

        vm.deal(user1, 1010 ether);
        vm.deal(user2, 1010 ether);

        uint256 lockStart = block.timestamp;
        vm.prank(user1);
        ve.createLock{value: 1000 ether}(1000 ether);
        vm.prank(user2);
        ve.createLock{value: 1000 ether}(1000 ether);

        // [(uint, uint), ...]
        uint256[4] memory weights = [uint256(8000), 2000, 9000, 1000]; // explicit casting

        vm.startPrank(user1);
        gc.vote_for_gauge_weights(gague1, weights[0]);
        gc.vote_for_gauge_weights(gague2, weights[1]);
        // TODO would be nice to have, but the mapping is not public.
        // assertEq(gc.vote_user_power(user1), 10000);
        vm.stopPrank();

        for (uint256 i; i < 10; i++) {
            checkpoint();
            uint256 _rel_weigth_1 = gc.gauge_relative_weight(gague1, block.timestamp);
            uint256 _rel_weigth_2 = gc.gauge_relative_weight(gague2, block.timestamp);
            assertApproxEqRel(_rel_weigth_1, (weights[0] * 1e18) / 1e3, 1e18);
            assertApproxEqRel(_rel_weigth_2, (weights[1] * 1e18) / 1e3, 1e18);
        }

        vm.startPrank(user2);
        gc.vote_for_gauge_weights(gague1, weights[2]);
        gc.vote_for_gauge_weights(gague2, weights[3]);
        // assertEq(gc.vote_user_power(user2), 10000);
        vm.stopPrank();

        for (uint256 i; i < 10; i++) {
            checkpoint();
            uint256 _rel_weigth_1 = gc.gauge_relative_weight(gague1, block.timestamp);
            uint256 _rel_weigth_2 = gc.gauge_relative_weight(gague2, block.timestamp);
            assertApproxEqRel(_rel_weigth_1, ((weights[0] + weights[2]) * 1e18) / 2e3, 1e18);
            assertApproxEqRel(_rel_weigth_2, ((weights[1] + weights[3]) * 1e18) / 2e3, 1e18);
        }

        skip((ve.LOCKTIME() - lockStart + ve.WEEK() - 1)); // warp to unlock
        uint256 rel_weigth_1 = gc.gauge_relative_weight(gague1, block.timestamp);
        uint256 rel_weigth_2 = gc.gauge_relative_weight(gague2, block.timestamp);
        assertEq(rel_weigth_1, 0);
        assertEq(rel_weigth_2, 0);
    }

    function testVoteExpiry() public {
        vm.startPrank(gov);
        gc.add_gauge(gague1);
        gc.change_gauge_weight(gague1, 100);
        vm.stopPrank();

        vm.startPrank(user1);
        ve.createLock{value: 1 ether}(1 ether);

        skip(ve.LOCKTIME());

        vm.expectRevert("Lock expires too soon");
        gc.vote_for_gauge_weights(gague1, 10000);
    }

    function checkpoint() public {
        skip(MONTH);
        mine(1);

        gc.checkpoint_gauge(gague1);
        gc.checkpoint_gauge(gague2);
    }

    // TODO similar functions in forge Test.sol helper contract, might consider to move
    function skip(uint256 time) public {
        vm.warp(block.timestamp + time);
    }

    function mine(uint256 blocks) public {
        vm.roll(block.number + blocks);
    }
}
