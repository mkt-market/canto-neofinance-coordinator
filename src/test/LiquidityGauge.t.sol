// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.8.0;

import {Test} from "forge-std/Test.sol";
import {Utilities} from "./utils/Utilities.sol";

import "../LendingLedger.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("M20", "M20") {
        _mint(msg.sender, 1000 ether);
    }
}

contract DummyGaugeController {
    function gauge_relative_weight_write(address _gauge, uint256 _time) external returns (uint256) {
        return 1 ether;
    }
}

contract LiquidityGaugeTest is Test {
    Utilities internal utils;
    address payable[] internal users;

    LendingLedger ledger;
    DummyGaugeController controller;
    MockERC20 token;
    LiquidityGauge liquidityGauge;

    address governance;
    address lender;
    address erc20Token;

    function setUp() public {
        utils = new Utilities();
        users = utils.createUsers(5);

        governance = users[0];
        lender = users[1];

        controller = new DummyGaugeController();
        ledger = new LendingLedger(address(controller), governance);
        erc20Token = vm.addr(5201314);
    }

    function whitelistToken() public {
        vm.prank(lender);
        token = new MockERC20();

        vm.mockCall(
            address(ledger.baseV1Factory()),
            abi.encodeWithSelector(BaseV1Factory.getPair.selector),
            abi.encode(address(token))
        );

        vm.prank(governance);
        ledger.whiteListLendingMarket(erc20Token, true, true);

        liquidityGauge = LiquidityGauge(ledger.liquidityGauges(address(erc20Token)));
    }

    function testDepositUnderlying() public {
        whitelistToken();

        uint256 amount = 1.1 ether;

        vm.startPrank(lender);
        token.approve(address(liquidityGauge), amount);
        liquidityGauge.depositUnderlying(amount);

        assertEq(token.balanceOf(lender), 1000 ether - amount);
        assertEq(liquidityGauge.balanceOf(lender), amount);

        uint256 ledgerBalance = ledger.lendingMarketTotalBalance(address(erc20Token));
        assertTrue(ledgerBalance == amount);
    }

    function testDepositUnderlyingInvalid() public {
        whitelistToken();

        uint256 amount = 1000.1 ether;

        vm.startPrank(lender);
        token.approve(address(liquidityGauge), amount);

        vm.expectRevert("ERC20: transfer amount exceeds balance");
        liquidityGauge.depositUnderlying(amount);
    }

    function testWithdrawUnderlying() public {
        whitelistToken();

        uint256 depositAmount = 1.1 ether;
        uint256 withdrawAmount = 1 ether;

        vm.startPrank(lender);

        token.approve(address(liquidityGauge), depositAmount);
        liquidityGauge.depositUnderlying(depositAmount);

        liquidityGauge.approve(address(liquidityGauge), withdrawAmount);
        liquidityGauge.withdrawUnderlying(withdrawAmount);

        assertEq(token.balanceOf(lender), 1000 ether - depositAmount + withdrawAmount);
        assertEq(liquidityGauge.balanceOf(lender), depositAmount - withdrawAmount);

        uint256 ledgerBalance = ledger.lendingMarketTotalBalance(address(erc20Token));
        assertTrue(ledgerBalance == depositAmount - withdrawAmount);
    }

    function testWithdrawUnderlyingInvalid() public {
        whitelistToken();

        uint256 depositAmount = 1.1 ether;
        uint256 withdrawAmount = 1.2 ether;

        vm.startPrank(lender);

        token.approve(address(liquidityGauge), depositAmount);
        liquidityGauge.depositUnderlying(depositAmount);

        liquidityGauge.approve(address(liquidityGauge), withdrawAmount);

        vm.expectRevert("ERC20: burn amount exceeds balance");
        liquidityGauge.withdrawUnderlying(withdrawAmount);
    }

    function testSyncLedgerOnTransfer() public {
        whitelistToken();

        uint256 amount = 1.1 ether;

        vm.startPrank(lender);
        token.approve(address(liquidityGauge), amount);
        liquidityGauge.depositUnderlying(amount);
        liquidityGauge.transfer(governance, amount);

        uint256 ledgerBalance;
        (ledgerBalance, , ) = ledger.userInfo(lender, address(erc20Token));
        assertEq(ledgerBalance, 0);

        (ledgerBalance, , ) = ledger.userInfo(governance, address(erc20Token));
        ledgerBalance = ledger.lendingMarketTotalBalance(address(erc20Token));
        assertEq(ledgerBalance, amount);
    }
}
