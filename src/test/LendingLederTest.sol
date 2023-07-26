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

    function testTryClaimForUserThatNeverDeposited() public {
        vm.expectRevert("No deposits for this user");
        lendingLeder.claim(
            address(6),
            type(uint256).max,
            type(uint256).max
        );
    }
}