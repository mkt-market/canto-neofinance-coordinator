// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.8.0;

import {DSTest} from "ds-test/test.sol";
import {Utilities} from "./utils/Utilities.sol";
import {console} from "./utils/Console.sol";
import {Vm} from "forge-std/Vm.sol";

import "../LendingLedger.sol";

contract LendingLedgerTest is DSTest {
    Vm internal immutable vm = Vm(HEVM_ADDRESS);

    Utilities internal utils;
    address payable[] internal users;

    LendingLeder ledger;
    address guage = address(0);
    address goverance;

    function setUp() public {
        utils = new Utilities();

        users = utils.createUsers(5);

        goverance = users[0];

        ledger = new LendingLeder(guage, goverance);
    }

    function testAddWhitelistLendingMarket() public {
        address lendingMarket = vm.addr(5201314);

        vm.prank(goverance);
        ledger.whiteListLendingMarket(lendingMarket, true);

        bool isWhitelisted = ledger.lendingMarketWhitelist(lendingMarket);
        assertTrue(isWhitelisted);
    }
}
