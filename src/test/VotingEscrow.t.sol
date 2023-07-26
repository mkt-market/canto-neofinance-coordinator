// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "../VotingEscrow.sol";

contract VotingEscrowTest is Test {
    VotingEscrow public ve;

    address public constant user1 = address(10001);
    address public constant user2 = address(10002);
    address public constant user3 = address(10003);

    function setUp() public {
        ve = new VotingEscrow("Voting Escrow", "VE");
        vm.deal(user1, 1 ether);
        vm.deal(user2, 1 ether);
        vm.deal(user3, 1 ether);
    }

    uint256 public constant WEEK = 7 days;

    function _floorToWeek(uint256 _t) internal pure returns (uint256) {
        return (_t / WEEK) * WEEK;
    }

    function testSuccessCreateLock() public {
        // Lock with a duration 5 year should be created with delegated set to msg.sender
        vm.prank(user1);
        ve.createLock{value: 100}(100);
        assertEq(ve.lockEnd(user1), _floorToWeek(block.timestamp + ve.LOCKTIME()));
        (, , , address delegatee) = ve.locked(user1);
        assertEq(delegatee, user1);
    }

    function testRevertDelegateNonExisting() public {
        // delegate for non-existing lock
        vm.prank(user1);
        vm.expectRevert("No lock");
        ve.delegate(user1);
    }

    function testRevertDelegateAlreadyDelegated() public {
        testSuccessCreateLock();
        // delegate to already delegated address
        vm.prank(user1);
        vm.expectRevert("Already delegated");
        ve.delegate(user1);
    }

    function testRevertDelegateToWithoutLock() public {
        // delegate to address without lock
        testSuccessCreateLock();
        vm.prank(user1);
        vm.expectRevert("Delegatee has no lock");
        ve.delegate(user2);
    }

    function testSuccessDelegate() public {
        // successful delegate
        testSuccessCreateLock();
        vm.prank(user2);
        ve.createLock{value: 100}(100);
        vm.prank(user1);
        ve.delegate(user2);
        (, , , address delegatee) = ve.locked(user1);
        assertEq(delegatee, user2);
    }

    function testRevertDelegateExpired() public {
        // delegate to delegatee with expired lock
        testSuccessCreateLock();
        (, uint256 end, , ) = ve.locked(user1);
        vm.warp(end + 1);
        vm.prank(user2);
        ve.createLock{value: 100}(100);
        vm.prank(user2);
        vm.expectRevert("Delegatee lock expired");
        ve.delegate(user1);
    }

    function testRevertDelegateShorter() public {
        // delegate to delegatee with shorter lock
        testSuccessCreateLock();
        vm.warp(block.timestamp + 10 days);
        vm.prank(user2);
        ve.createLock{value: 100}(100);
        vm.prank(user2);
        vm.expectRevert("Only delegate to longer lock");
        ve.delegate(user1);
    }

    function testSuccessUnDelegate() public {
        // successful undelegate
        testSuccessDelegate();
        vm.prank(user1);
        ve.delegate(user1);
        (, , , address delegatee) = ve.locked(user1);
        assertEq(delegatee, user1);
    }

    function testSuccessReDelegate() public {
        // successful redelegate
        testSuccessDelegate();
        vm.prank(user3);
        ve.createLock{value: 100}(100);
        vm.prank(user1);
        ve.delegate(user3);
        (, , , address delegatee) = ve.locked(user1);
        assertEq(delegatee, user3);
    }

    function testSuccessIncreaseUndelegated() public {
        // increaseAmount basic functionality for undelegated lock
        // Should increase amount / delegated by the provided value, new end should be reset to be 5 years in the future
        testSuccessUnDelegate();
        vm.warp(block.timestamp + 10 days);
        vm.prank(user1);
        ve.increaseAmount{value: 100}(100);
        (, , int128 delegated, ) = ve.locked(user1);
        assertEq(delegated, 200);
        assertEq(ve.lockEnd(user1), block.timestamp + ve.LOCKTIME());
    }

    function testSuccessIncreaseDelegated() public {
        // increaseAmount basic functionality for delegated lock
        // Should reset end to be 5 years in the future and increase delegated value of delegatee
        testSuccessDelegate();
        vm.prank(user1);
        ve.increaseAmount{value: 100}(100);
        (, , int128 delegated, ) = ve.locked(user2);
        assertEq(delegated, 300);
        assertEq(ve.lockEnd(user1), block.timestamp + ve.LOCKTIME());
    }
}
