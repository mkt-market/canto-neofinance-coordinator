// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {VotingEscrow} from "./VotingEscrow.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract LendingLeder {
    // Constants
    uint256 public constant WEEK = 7 days;

    // State
    /// @dev Lending Market => Lender => Epoch => Balance
    mapping(address => mapping(address => mapping(uint256 => uint256))) lendingMarketBalances; // cNote balances of users within the lending markets, indexed by epoch
    /// @dev Lending Market => Lender => Epoch
    mapping(address => mapping(address => uint256)) lendingMarketBalancesEpoch; // Epoch when the last update happened
    /// @dev Lending Market => Epoch => Balance
    mapping(address => mapping(uint256 => uint256)) lendingMarketTotalBalance; // Total balance locked within the market, i.e. sum of lendingMarketBalances for all
    /// @dev Lending Market => Epoch
    mapping(address => uint256) lendingMarketTotalBalanceEpoch; // Epoch when the last update happened

    /// @notice Function that is called by the lending market on cNOTE deposits / withdrawals
    /// @param lender The address of the lender
    /// @param delta The amount of cNote deposited (positive) or withdrawn (negative)
    function syncLedger(address lender, int256 delta) external {
        address lendingMarket = msg.sender; // TODO: Validate
        uint256 currEpoch = (block.timestamp / WEEK) * WEEK;
        uint256 lastUserUpdateEpoch = lendingMarketBalancesEpoch[lendingMarket][lender];
        if (lastUserUpdateEpoch > 0 && lastUserUpdateEpoch < currEpoch) {
            // Fill in potential gaps in the user balances history
            uint256 lastUserBalance = lendingMarketBalances[lendingMarket][lender][lastUserUpdateEpoch];
            for (uint256 i = lastUserUpdateEpoch; i <= currEpoch; i += WEEK) {
                lendingMarketBalances[lendingMarket][lender][i] = lastUserBalance;
            }
        }
        // TODO Maybe sanity check that no underflow happens, although this should be enforced by the lending market
        lendingMarketBalances[lendingMarket][lender][currEpoch] = uint256(
            int256(lendingMarketBalances[lendingMarket][lender][currEpoch]) + delta
        );
        lendingMarketBalancesEpoch[lendingMarket][lender] = currEpoch;

        uint256 lastMarketUpdateEpoch = lendingMarketTotalBalanceEpoch[lendingMarket];
        if (lastMarketUpdateEpoch > 0 && lastMarketUpdateEpoch < currEpoch) {
            // Fill in potential gaps in the market total balances history
            uint256 lastMarketBalance = lendingMarketTotalBalance[lendingMarket][lastMarketUpdateEpoch];
            for (uint256 i = lastMarketUpdateEpoch; i <= currEpoch; i += WEEK) {
                lendingMarketTotalBalance[lendingMarket][i] = lastMarketBalance;
            }
        }
        // TODO Maybe sanity check that no underflow happens, although this should be enforced by the lending market
        lendingMarketTotalBalance[lendingMarket][currEpoch] = uint256(
            int256(lendingMarketTotalBalance[lendingMarket][currEpoch]) + delta
        );
        lendingMarketTotalBalanceEpoch[lendingMarket] = currEpoch;
    }
}
