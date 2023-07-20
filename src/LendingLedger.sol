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

    /// @notice Fill in gaps in the user market balances history (if any exist)
    /// @param _market Address of the market
    /// @param _lender Address of the lender
    /// @param _forwardTimestampLimit Until which epoch (provided as timestamp) should the update be applied. If it is higher than the current epoch timestamp, this will be used.
    function _checkpoint_lender(
        address _market,
        address _lender,
        uint256 _forwardTimestampLimit
    ) private {
        uint256 currEpoch = (block.timestamp / WEEK) * WEEK;
        uint256 lastUserUpdateEpoch = lendingMarketBalancesEpoch[_market][_lender];
        uint256 updateUntilEpoch = Math.min(currEpoch, _forwardTimestampLimit);
        if (lastUserUpdateEpoch > 0 && lastUserUpdateEpoch < currEpoch) {
            // Fill in potential gaps in the user balances history
            uint256 lastUserBalance = lendingMarketBalances[_market][_lender][lastUserUpdateEpoch];
            for (uint256 i = lastUserUpdateEpoch; i <= updateUntilEpoch; i += WEEK) {
                lendingMarketBalances[_market][_lender][i] = lastUserBalance;
            }
        }
        lendingMarketBalancesEpoch[_market][_lender] = updateUntilEpoch;
    }

    /// @notice Fill in gaps in the market total balances history (if any exist)
    /// @param _market Address of the market
    /// @param _forwardTimestampLimit Until which epoch (provided as timestamp) should the update be applied. If it is higher than the current epoch timestamp, this will be used.
    function _checkpoint_market(address _market, uint256 _forwardTimestampLimit) private {
        uint256 currEpoch = (block.timestamp / WEEK) * WEEK;
        uint256 lastMarketUpdateEpoch = lendingMarketTotalBalanceEpoch[_market];
        uint256 updateUntilEpoch = Math.min(currEpoch, _forwardTimestampLimit);
        if (lastMarketUpdateEpoch > 0 && lastMarketUpdateEpoch < currEpoch) {
            // Fill in potential gaps in the market total balances history
            uint256 lastMarketBalance = lendingMarketTotalBalance[_market][lastMarketUpdateEpoch];
            for (uint256 i = lastMarketUpdateEpoch; i <= updateUntilEpoch; i += WEEK) {
                lendingMarketTotalBalance[_market][i] = lastMarketBalance;
            }
        }
        lendingMarketTotalBalanceEpoch[_market] = updateUntilEpoch;
    }

    /// @notice Trigger a checkpoint explicitly.
    ///    Never needs to be called explicitly, but could be used to ensure the checkpoints within the other functions consume less gas (because they need to forward less epochs)
    /// @param _market Address of the market
    /// @param _forwardTimestampLimit Until which epoch (provided as timestamp) should the update be applied. If it is higher than the current epoch timestamp, this will be used.
    function checkpoint_market(address _market, uint256 _forwardTimestampLimit) external {
        require(lendingMarketTotalBalanceEpoch[_market] > 0, "No deposits for this market");
        _checkpoint_market(_market, _forwardTimestampLimit);
    }

    /// @param _market Address of the market
    /// @param _lender Address of the lender
    /// @param _forwardTimestampLimit Until which epoch (provided as timestamp) should the update be applied. If it is higher than the current epoch timestamp, this will be used.
    function checkpoint_lender(
        address _market,
        address _lender,
        uint256 _forwardTimestampLimit
    ) external {
        require(lendingMarketBalancesEpoch[_market][_lender] > 0, "No deposits for this lender in this market");
        _checkpoint_lender(_market, _lender, _forwardTimestampLimit);
    }

    /// @notice Function that is called by the lending market on cNOTE deposits / withdrawals
    /// @param _lender The address of the lender
    /// @param _delta The amount of cNote deposited (positive) or withdrawn (negative)
    function sync_ledger(address _lender, int256 _delta) external {
        address lendingMarket = msg.sender; // TODO: Validate

        _checkpoint_lender(lendingMarket, _lender, type(uint256).max);
        uint256 currEpoch = (block.timestamp / WEEK) * WEEK;
        // TODO Maybe sanity check that no underflow happens, although this should be enforced by the lending market
        lendingMarketBalances[lendingMarket][_lender][currEpoch] = uint256(
            int256(lendingMarketBalances[lendingMarket][_lender][currEpoch]) + _delta
        );

        _checkpoint_market(lendingMarket, type(uint256).max);
        // TODO Maybe sanity check that no underflow happens, although this should be enforced by the lending market
        lendingMarketTotalBalance[lendingMarket][currEpoch] = uint256(
            int256(lendingMarketTotalBalance[lendingMarket][currEpoch]) + _delta
        );
    }
}
