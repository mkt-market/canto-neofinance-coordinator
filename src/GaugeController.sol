// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {VotingEscrow} from "./VotingEscrow.sol";

/// @title  GaugeController
/// @author Curve Finance (MIT) - original concept and implementation in Vyper
///         mkt.market - Porting to Solidity with some modifications (this version)
/// @notice Allows users to vote on distribution of CANTO that the contract receives from governance. Modifications from Curve:
///         - Gauge types removed
contract GaugeController {
    // Events

    // State
    VotingEscrow public votingEscrow;
    uint256 public constant WEEK = 7 days;
    address public governance;
    uint128 n_gauges;
    address[1000000000] public gauges;
    mapping(address => mapping(address => VotedSlope)) public vote_user_slopes;
    mapping(address => uint256) vote_user_power;
    mapping(address => mapping(address => uint256)) public last_user_vote;

    mapping(address => mapping(uint256 => Point)) public points_weight;
    mapping(address => mapping(uint256 => uint256)) public changes_weight;
    mapping(address => uint256) time_weight;

    mapping(uint256 => uint256) public points;
    uint256 public time_total;

    struct Point {
        uint256 bias;
        uint256 slope;
    }

    struct VotedSlope {
        uint256 slope;
        uint256 power;
        uint256 end;
    }

    /// @notice Initializes state
    /// @param _votingEscrow The voting escrow address
    constructor(address _votingEscrow) {
        votingEscrow = VotingEscrow(_votingEscrow);
    }
}
