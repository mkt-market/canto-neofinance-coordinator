// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {VotingEscrow} from "./VotingEscrow.sol";

/// @title  GaugeController
/// @author mkt.market
/// @notice Allows users to vote on distribution of CANTO that the contract receives from governance
contract GaugeController {
    // Events

    // State
    VotingEscrow votingEscrow;
    uint256 public constant WEEK = 7 days;

    /// @notice Initializes state
    /// @param _votingEscrow The voting escrow address
    constructor(address _votingEscrow) {
        votingEscrow = VotingEscrow(_votingEscrow);
    }
}
