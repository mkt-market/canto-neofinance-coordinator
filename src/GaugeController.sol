// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {VotingEscrow} from "./VotingEscrow.sol";

/// @title  GaugeController
/// @author Curve Finance (MIT) - original concept and implementation in Vyper
///         mkt.market - Porting to Solidity with some modifications (this version)
/// @notice Allows users to vote on distribution of CANTO that the contract receives from governance. Modifications from Curve:
///         - Gauge types removed
contract GaugeController {
    // Constants
    uint256 public constant WEEK = 7 days;
    
    // Events
    event NewGauge(address indexed gauge_address);

    // State
    VotingEscrow public votingEscrow;
    address public governance;
    uint128 n_gauges;
    address[1000000000] public gauges;
    mapping(address => mapping(address => VotedSlope)) public vote_user_slopes;
    mapping(address => uint256) vote_user_power;
    mapping(address => mapping(address => uint256)) public last_user_vote;

    mapping(address => mapping(uint256 => Point)) public points_weight;
    mapping(address => mapping(uint256 => uint256)) public changes_weight;
    mapping(address => uint256) time_weight;

    mapping(uint256 => Point) points_sum;
    mapping(uint256 => uint256) changes_sum;

    mapping(uint256 => uint256) public points_total;
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

    modifier onlyGovernance() {
        require(msg.sender == governance);
        _;
    }

    /// @notice Initializes state
    /// @param _votingEscrow The voting escrow address
    constructor(address _votingEscrow) {
        votingEscrow = VotingEscrow(_votingEscrow);
        time_total = block.timestamp / WEEK * WEEK;
    }

    /// @notice Fill historic total weights week-over-week for missed checkins and return the total for the future week
    /// @return pt The total weight
    function _get_total() private returns (uint256 pt) {
        uint256 t = time_total;
        if (t > block.timestamp) t -= WEEK; // If we have already checkpointed - still need to change the value
        pt = points_total[t];
        for (uint256 i; i < 500; ++i) {
            if (t > block.timestamp) break;
            t += WEEK;
            pt = points_sum[t].bias;
            points_total[t] = pt;
            if (t > block.timestamp) time_total = t;
        }
    }

    ///     @notice Fill historic gauge weights week-over-week for missed checkins
    ///     and return the total for the future week
    ///     @param _gauge_addr Address of the gauge
    ///     @return Gauge weight
    function _get_weight(address _gauge_addr) private returns (uint256) {
        uint256 t = time_weight[_gauge_addr];
        if (t > 0) {
            Point memory pt = points_weight[_gauge_addr][t];
            for (uint256 i; i < 500; ++i) {
                if (t > block.timestamp) break;
                t += WEEK;
                uint256 d_bias = pt.slope * WEEK;
                if (pt.bias > d_bias) {
                    pt.bias -= d_bias;
                    uint256 d_slope = changes_weight[_gauge_addr][t];
                    pt.slope -= d_slope;
                } else {
                    pt.bias = 0;
                    pt.slope = 0;
                }
                points_weight[_gauge_addr][t] = pt;
                if (t > block.timestamp) time_weight[_gauge_addr] = t;
            }
            return pt.bias;
        } else {
            return 0;
        }
    }

    /// @notice Allows governance to add a new gauge
    /// @param _gauge The gauge address
    function add_gauge(address _gauge) public onlyGovernance {
        uint128 n = n_gauges;
        n_gauges = n + 1;
        gauges[n] = _gauge;
        emit NewGauge(_gauge);
    }
}
