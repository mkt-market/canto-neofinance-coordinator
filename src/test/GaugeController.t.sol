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

    VotingEscrow internal ve;
    GaugeController internal gc;

    function setUp() public {
        utils = new Utilities();
        users = utils.createUsers(5);
        (gov, user1, user2) = (users[0], users[1], users[2]);

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

    function testRemoveGaugeForNonExistingGauge() public {
        assertTrue(!gc.isValidGauge(user1));
        vm.prank(gov);
        vm.expectRevert("Invalid gauge address");
        gc.remove_gauge(user1);
    }
}
