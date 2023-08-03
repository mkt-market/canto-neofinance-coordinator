// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.8.0;

import {DSTest} from "ds-test/test.sol";
import {Utilities} from "./utils/Utilities.sol";
import {console} from "./utils/Console.sol";
import {Vm} from "forge-std/Vm.sol";

import {LendingLeder} from "../LendingLedger.sol";

contract LendingLederTest is DSTest {
    Vm internal immutable vm = Vm(HEVM_ADDRESS);

    LendingLeder lendingLeder;

    function setUp() public {
        lendingLeder = new LendingLeder(address(0), address(0));
    }

    function testTryClaimWithInvalidStartEpoch() public {
        uint256 someWeeks = 7 * lendingLeder.WEEK();

        vm.expectRevert("Invalid timestamp");
        lendingLeder.claim(
            address(0),
            someWeeks + 1,
            type(uint256).max
        );

        vm.expectRevert("Invalid timestamp");
        lendingLeder.claim(
            address(0),
            someWeeks - 1,
            type(uint256).max
        );
    }

    function testTryClaimWithInvalidEndEpoch() public {
        uint256 someWeeks = 7 * lendingLeder.WEEK();

        vm.expectRevert("Invalid timestamp");
        lendingLeder.claim(
            address(0),
            type(uint256).max,
            someWeeks + 1
        );

        vm.expectRevert("Invalid timestamp");
        lendingLeder.claim(
            address(0),
            type(uint256).max,
            someWeeks - 1
        );
    }
}