// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {VotingEscrow} from "./VotingEscrow.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/// @title  GaugeController
/// @author Curve Finance (MIT) - original concept and implementation in Vyper
///         mkt.market - Porting to Solidity with some modifications (this version)
/// @notice Allows users to vote on distribution of CANTO that the contract receives from governance. Modifications from Curve:
///         - Gauge types removed
contract GaugeController {
    // Constants
    uint256 public constant WEEK = 7 days;
    uint256 public constant MULTIPLIER = 10**18;

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
    uint256 public time_sum;

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
        uint256 last_epoch = (block.timestamp / WEEK) * WEEK;
        time_total = last_epoch;
        time_sum = last_epoch;
    }

    /// @notice Fill historic gauge weights week-over-week for missed checkins and return the sum for the future week
    /// @return Sum of weights
    function _get_sum() internal returns (uint256) {
        uint256 t = time_sum;
        Point memory pt = points_sum[t];
        for (uint256 i; i < 500; ++i) {
            if (t > block.timestamp) break;
            t += WEEK;
            uint256 d_bias = pt.slope * WEEK;
            if (pt.bias > d_bias) {
                pt.bias -= d_bias;
                uint256 d_slope = changes_sum[t];
                pt.slope -= d_slope;
            } else {
                pt.bias = 0;
                pt.slope = 0;
            }
            points_sum[t] = pt;
            if (t > block.timestamp) time_sum = t;
        }
        return pt.bias;
    }

    /// @notice Fill historic total weights week-over-week for missed checkins and return the total for the future week
    /// @return pt The total weight
    function _get_total() private returns (uint256 pt) {
        // TODO: Can be replaced with points_sum...
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

    /// @notice Fill historic gauge weights week-over-week for missed checkins
    /// and return the total for the future week
    /// @param _gauge_addr Address of the gauge
    /// @return Gauge weight
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
    function add_gauge(address _gauge) external onlyGovernance {
        uint128 n = n_gauges;
        n_gauges = n + 1;
        gauges[n] = _gauge;
        emit NewGauge(_gauge);
    }

    /// @notice Checkpoint to fill data common for all gauges
    function checkpoint() external {
        _get_total();
    }

    /// @notice Checkpoint to fill data for both a specific gauge and common for all gauges
    /// @param _gauge The gauge address
    function checkpoint_gauge(address _gauge) external {
        _get_weight(_gauge);
        _get_total();
    }

    /// @notice Get Gauge relative weight (not more than 1.0) normalized to 1e18
    ///     (e.g. 1.0 == 1e18). Inflation which will be received by it is
    ///     inflation_rate * relative_weight / 1e18
    /// @param _gauge Gauge address
    /// @param _time Relative weight at the specified timestamp in the past or present
    /// @return Value of relative weight normalized to 1e18
    function _gauge_relative_weight(address _gauge, uint256 _time) private view returns (uint256) {
        uint256 t = (_time / WEEK) * WEEK;
        uint256 total_weight = points_total[t];
        if (total_weight > 0) {
            uint256 gauge_weight = points_weight[_gauge][t].bias;
            return (MULTIPLIER * gauge_weight) / total_weight;
        } else {
            return 0;
        }
    }

    /// @notice Get Gauge relative weight (not more than 1.0) normalized to 1e18
    ///     (e.g. 1.0 == 1e18). Inflation which will be received by it is
    ///     inflation_rate * relative_weight / 1e18
    /// @param _gauge Gauge address
    /// @param _time Relative weight at the specified timestamp in the past or present
    /// @return Value of relative weight normalized to 1e18
    function gauge_relative_weight(address _gauge, uint256 _time) external view returns (uint256) {
        return _gauge_relative_weight(_gauge, _time);
    }

    /// @notice Get gauge weight normalized to 1e18 and also fill all the unfilled
    ///     values for type and gauge records
    /// @dev Any address can call, however nothing is recorded if the values are filled already
    /// @param _gauge Gauge address
    /// @param _time Relative weight at the specified timestamp in the past or present
    /// @return Value of relative weight normalized to 1e18
    function gauge_relative_weight_write(address _gauge, uint256 _time) external returns (uint256) {
        _get_weight(_gauge);
        _get_total();
        return _gauge_relative_weight(_gauge, _time);
    }

    /// @notice Overwrite gauge weight
    /// @param _gauge Gauge address
    /// @param _weight New weight
    function _change_gauge_weight(address _gauge, uint256 _weight) internal {
        uint256 old_gauge_weight = _get_weight(_gauge);
        uint256 total_weight = _get_total();
        uint256 next_time = ((block.timestamp + WEEK) / WEEK) * WEEK;

        points_weight[_gauge][next_time].bias = _weight;
        time_weight[_gauge] = next_time;

        // TODO: Update points_sum here?

        total_weight = total_weight - old_gauge_weight + _weight;
        points_total[next_time] = total_weight;
        time_total = next_time;
    }

    /// @notice Allows governance to overwrite gauge weights
    /// @param _gauge Gauge address
    /// @param _weight New weight
    function change_gauge_weight(address _gauge, uint256 _weight) external onlyGovernance {
        _change_gauge_weight(_gauge, _weight);
    }

    /// @notice Allocate voting power for changing pool weights
    /// @param _gauge_addr Gauge which `msg.sender` votes for
    /// @param _user_weight Weight for a gauge in bps (units of 0.01%). Minimal is 0.01%. Ignored if 0
    function vote_for_gauge_weights(address _gauge_addr, uint256 _user_weight) external {
        // TODO: Validate gauge_addr
        require(_user_weight >= 0 && _user_weight <= 10_000, "Invalid user weight");
        VotingEscrow ve = votingEscrow;
        (
            ,
            /*int128 bias*/
            int128 slope_, /*uint256 ts*/

        ) = ve.getLastUserPoint(msg.sender);
        require(slope_ >= 0, "Invalid slope");
        uint256 slope = uint256(uint128(slope_));
        uint256 lock_end = ve.lockEnd(msg.sender);
        uint256 next_time = ((block.timestamp + WEEK) / WEEK) * WEEK;
        require(lock_end > next_time, "Lock expires too soon");
        VotedSlope memory old_slope = vote_user_slopes[msg.sender][_gauge_addr];
        uint256 old_dt = 0;
        if (old_slope.end > next_time) old_dt = old_slope.end - next_time;
        uint256 old_bias = old_slope.slope * old_dt;
        VotedSlope memory new_slope = VotedSlope({
            slope: (slope * _user_weight) / 10_000,
            end: lock_end,
            power: _user_weight
        });
        uint256 new_dt = lock_end - next_time;
        uint256 new_bias = new_slope.slope * new_dt;

        // Check and update powers (weights) used
        uint256 power_used = vote_user_power[msg.sender];
        power_used = power_used + new_slope.power - old_slope.power;
        require(power_used >= 0 && power_used <= 10_000, "Used too much power");
        vote_user_power[msg.sender] = power_used;

        // Remove old and schedule new slope changes
        // Remove slope changes for old slopes
        // Schedule recording of initial slope for next_time
        uint256 old_weight_bias = _get_weight(_gauge_addr);
        uint256 old_weight_slope = points_weight[_gauge_addr][next_time].slope;
        uint256 old_sum_bias = _get_sum(); // TODO
        uint256 old_sum_slope = points_sum[next_time].slope;

        points_weight[_gauge_addr][next_time].bias = Math.max(old_weight_bias + new_bias, old_bias) - old_bias;
        points_sum[next_time].bias = Math.max(old_sum_bias + new_bias, old_sum_bias) - old_bias;
        if (old_slope.end > next_time) {
            points_weight[_gauge_addr][next_time].slope =
                Math.max(old_weight_slope + new_slope.slope, old_slope.slope) -
                old_slope.slope;
            points_sum[next_time].slope = Math.max(old_sum_slope + new_slope.slope, old_slope.slope) - old_slope.slope;
        } else {
            points_weight[_gauge_addr][next_time].slope += new_slope.slope;
            points_sum[next_time].slope += new_slope.slope;
        }
        if (old_slope.end > block.timestamp) {
            // Cancel old slope changes if they still didn't happen
            changes_weight[_gauge_addr][old_slope.end] -= old_slope.slope;
            changes_sum[old_slope.end] -= old_slope.slope;
        }
        // Add slope changes for new slopes
        changes_weight[_gauge_addr][new_slope.end] += new_slope.slope;
        changes_sum[new_slope.end] += new_slope.slope;

        _get_total(); // TODO Can probably be removed

        vote_user_slopes[msg.sender][_gauge_addr] = new_slope;

        // Record last action time
        last_user_vote[msg.sender][_gauge_addr] = block.timestamp;
    }

    /// @notice Get current gauge weight
    /// @param _gauge Gauge address
    /// @return Gauge weight
    function get_gauge_weight(address _gauge) external view returns (uint256) {
        return points_weight[_gauge][time_weight[_gauge]].bias;
    }

    /// @notice Get total weight
    /// @return Total weight
    function get_total_weight() external view returns (uint256) {
        return points_total[time_total];
    }
}
