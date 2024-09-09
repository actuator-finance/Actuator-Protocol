// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "hardhat/console.sol";
import { Actuator } from "../contracts/Actuator.sol"; 
import { MasterChef } from "../contracts/MasterChef.sol";

contract TimeLock {
    uint256 constant YEAR = 365 days;
    
    uint256[3] public teamEmissionSchedule;

    address private _teamAddress;
    uint256 private _lastTransfer;

    Actuator public actr;

    constructor(
        address actrAddress,
        address teamAddress,
        uint256[3] memory _teamEmissionSchedule
    ) {
        actr = Actuator(actrAddress);
        MasterChef masterChef = MasterChef(actr.masterChef());
        _lastTransfer = masterChef.startTime();
        teamEmissionSchedule = _teamEmissionSchedule;
        _teamAddress = teamAddress;
    }

    /**
     * @dev Public function to fetch the team ACTR emission amount within 2 timestamp. 
     * @param _from Start date to calculate emissions from.
     * @param _to End date to calculate emissions to.
     * @return Total ACTR Emissions.
    */
    function getTeamEmissions(uint256 _from, uint256 _to) public view returns (uint256) {
        uint256 startTime = MasterChef(actr.masterChef()).startTime();
        uint256 start = _from - startTime;
        uint256 end = _to - startTime;
        return _getEmissionsInTimeframe(start, end, teamEmissionSchedule);
    }

    /**
     * @dev Generic function to fetch the ACTR emission amount within 2 timestamps based on the provided emission schedule 
     * and assuming epoch is farm start.
     * @param start Start time to calculate emissions from.
     * @param end End time to calculate emissions to.
     * @param emissionSchedule Array of yearly ACTR emission amount.
     * @return Total ACTR Emissions.
     * 
    */
    function _getEmissionsInTimeframe(uint256 start, uint256 end, uint256[3] memory emissionSchedule) private pure returns (uint256) {
        uint256 amount = 0;
        for (uint256 year = 0; year < emissionSchedule.length; year++) {
            uint256 yearStart = year * YEAR;
            uint256 yearEnd = (year + 1) * YEAR;
            
            // Check for timeframe overlap
            if (end > yearStart && start < yearEnd) {
                uint256 effectiveStart = start > yearStart ? start : yearStart;
                uint256 effectiveEnd = end < yearEnd ? end : yearEnd;
                uint256 elapsed = effectiveEnd - effectiveStart;
                amount += (emissionSchedule[year] * elapsed) / YEAR;
            }
        }
        
        return amount;
    }

    /**
     * @dev Priveleged function to transfer the newly unlocked funds since previous transfer.
     * @return ACTR amount transfered.
     * 
    */
    function transferUnlockedFunds() external returns (uint256) {
        require(msg.sender == _teamAddress, "A025");
        
        uint256 nextTransfer = block.timestamp;
        if (nextTransfer <= _lastTransfer) {
            return 0;
        }

        uint256 amount = getTeamEmissions(_lastTransfer, nextTransfer);

        _lastTransfer = nextTransfer;

        safeActrTransfer(_teamAddress, amount);

        return amount;
    }

    /**
     * @dev Safe ACTR transfer function, just in case if rounding error causes contract to not have enough ACTR.
     * @param _to Recipient address.
     * @param _amount Amount of ACTR tokens to transfer.
    */
    function safeActrTransfer(address _to, uint256 _amount) private {
        uint256 actrBal = actr.balanceOf(address(this));
        if (_amount > actrBal) {
            actr.transfer(_to, actrBal);
        } else {
            actr.transfer(_to, _amount);
        }
    }

    /**
     * @dev Transfers team address to a new account.
     */
    function transferTeamAddress(address newTeamAddress) external {
        require(msg.sender == _teamAddress, "A025");
        _teamAddress = newTeamAddress;
    }
}
