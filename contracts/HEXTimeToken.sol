// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { SafeERC20 } from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import { Ownable } from '@openzeppelin/contracts/access/Ownable.sol';
import { Actuator } from "./Actuator.sol"; 

contract HEXTimeToken is ERC20, Ownable {
    uint256 public constant CREATION_FEE_RATE = 75; // 75 basis points tax, i.e., 0.75%

    // Info of each user.
    struct UserInfo {
        uint256 amount;     // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        uint256 capitalAdded; // deposit start time
    }

    Actuator public actr;
    uint256 public totalDeposits;
    uint256 public accHttPerShare;
    uint16 public maturity;

    // Info of each user that stakes LP tokens.
    mapping (address => UserInfo) public userInfo;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event CollectFees(address indexed user, uint256 amount);

    constructor(
        uint16 _maturity,
        address actuatorAddress
    ) 
        ERC20(concatenate("HEX Time Token - Day ", uintToString(_maturity)), concatenate("HTT-", uintToString(_maturity))) 
        Ownable(msg.sender)
    {      
        actr = Actuator(actuatorAddress);
        maturity = _maturity;
    }

    function decimals() public view virtual override returns (uint8) {
        return 8;
    }

    function mint(address to, uint256 amount) external onlyOwner {
        if (totalDeposits == 0) {
            return _mint(to, amount);
        }

        uint256 taxAmount = calculateTax(amount);
        uint256 amountAfterTax = amount - taxAmount;
        accHttPerShare = accHttPerShare + (taxAmount * 1e12 / totalDeposits);
        _mint(address(this), taxAmount);
        return _mint(to, amountAfterTax);
    }

    function burn(address from, uint256 amount) external onlyOwner {
        _burn(from, amount);
    }

    function transferFromWithoutApproval(address _from, address _to, uint256 _amount) external onlyOwner returns (bool) {
        _transfer(_from, _to, _amount); // This is an internal function in the ERC20 standard that executes the transfer.
        return true;
    }

    function calculateTax(uint256 amount) public pure returns (uint256) {
        return amount * CREATION_FEE_RATE / 10000; // Assumes CREATION_FEE_RATE is in basis points
    }

    // Deposit LP tokens to MasterChef for ACT allocation.
    function deposit(address account, uint256 _amount) public returns (uint) {
        require(msg.sender == address(actr), "A036");

        UserInfo storage user = userInfo[account];

        totalDeposits += _amount;

        uint256 pending = (user.amount * accHttPerShare / 1e12) - user.rewardDebt;

        user.amount = user.amount + _amount;
        user.rewardDebt = user.amount * accHttPerShare / 1e12;
        user.capitalAdded = block.timestamp;

        if (pending > 0) {
            safeHttTransfer(account, pending);
        }
        // actr.transferFrom(address(account), address(this), _amount);

        emit Deposit(account, _amount);

        return user.amount;
    }

    function withdraw(address account, uint256 _amount) public returns (uint256, uint256) {  
        require(msg.sender == address(actr), "A036");
        UserInfo storage user = userInfo[account];

        require(user.amount >= _amount, "A037");

        totalDeposits -= _amount;

        uint256 pending = (user.amount * accHttPerShare / 1e12) - user.rewardDebt;

        user.amount = user.amount - _amount;
        user.rewardDebt = user.amount * accHttPerShare / 1e12;

        if (pending > 0) {
            safeHttTransfer(account, pending);
        }
        
        emit Withdraw(account, _amount);

        return (user.amount, user.capitalAdded);
    }

    function collectFees(address account) public returns (uint) {  
        require(msg.sender == address(actr), "Caller is not allowed");
        UserInfo storage user = userInfo[account];

        require(user.amount >= 0, "A026");

        uint256 pending = (user.amount * accHttPerShare / 1e12) - user.rewardDebt;
        
        user.rewardDebt = user.amount * accHttPerShare / 1e12;

        if (pending > 0) {
            safeHttTransfer(account, pending);
        }
        
        emit CollectFees(account, pending);

        return pending;
    }

    // Safe HTT transfer function, just in case if rounding error causes pool to not have enough ACTR.
    function safeHttTransfer(address _to, uint256 _amount) internal {
        uint256 httBal = balanceOf(address(this));
        if (_amount > httBal) {
            _transfer(address(this), _to, httBal);
        } else {
            _transfer(address(this), _to, _amount);
        }
    }

    function concatenate(string memory str1, string memory str2) 
        internal pure returns (string memory) 
    {
        return string(abi.encodePacked(str1, str2));
    }

    function uintToString(uint _i) internal pure returns (string memory) {
        uint256 j = _i;
        uint256 len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint256 k = len;
        while (_i != 0) {
            k = k-1;
            uint8 temp = (48 + uint8(_i % 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }

}
