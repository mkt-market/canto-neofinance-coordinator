// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.8.0;

import {DSTest} from "ds-test/test.sol";
import {Utilities} from "./utils/Utilities.sol";
import {console} from "./utils/Console.sol";
import {Vm} from "forge-std/Vm.sol";

import {VotingEscrow} from "../VotingEscrow.sol";

contract VotingEscrowTest is DSTest {
    Vm internal immutable vm = Vm(HEVM_ADDRESS);

    VotingEscrow votingEscrow;

    function setUp() public {
        votingEscrow = new VotingEscrow("Test", "TEST");
    }

    function testTryWithdrawNonExistingLock() public {
        vm.expectRevert("No lock");
        votingEscrow.withdraw();
    }
}
