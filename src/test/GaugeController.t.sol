// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.8.0;

import {DSTest} from "ds-test/test.sol";
import {Utilities} from "./utils/Utilities.sol";
import {console} from "./utils/Console.sol";
import {Vm} from "forge-std/Vm.sol";
import {VotingEscrow} from "../VotingEscrow.sol";
import {GaugeController} from "../GaugeController.sol";

contract GaugeControllerTest is DSTest {
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
}
