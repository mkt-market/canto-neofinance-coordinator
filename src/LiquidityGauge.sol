// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {VotingEscrow} from "./VotingEscrow.sol";
import {GaugeController} from "./GaugeController.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract LiquidityGauge is ERC20, ERC20Burnable {
    using SafeERC20 for IERC20;

    address public lendingLedger;

    modifier onlyLedger() {
        require(msg.sender == lendingLedger);
        _;
    }

    constructor(address _tokenAddress, address _lendingLedger) ERC20(
        string.concat(ERC20(_tokenAddress).symbol(), "NeoFinance Gauge"),
        string.concat(ERC20(_tokenAddress).symbol(), "-gauge")
    ) {
        lendingLedger = _lendingLedger;
    }

    function setLedger(address _lendingLedger) external onlyLedger {
        lendingLedger = _lendingLedger;
    }

    function mint(address to, uint256 amount) public onlyLedger {
        _mint(to, amount);
    }
}


