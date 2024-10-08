// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// import "hardhat/console.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { SafeERC20 } from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import { Actuator } from "./Actuator.sol"; 
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

contract HEXTimeToken is ERC20 {
    uint256 public constant CREATION_FEE_RATE = 100; // 100 basis points tax, i.e., 1%
    uint256 private constant ACC_HTT_PRECISION = 1e22; // Original was 1e12. However, HEX has 8 decimals. So 1e22 is used to preserve the relative precision.

    // Info of each user.
    struct UserInfo {
        uint256 amount;     // How many ACTR tokens the user has deposited.
        uint256 rewardDebt; 
        uint256 capitalAdded; // deposit start time
    }

    Actuator public actr;
    uint256 public totalDeposits;
    uint256 public accHttPerShare;
    uint16 public maturity;
    address public httManager;

    // Info of each user that deposits ACTR.
    mapping (address => UserInfo) public userInfo;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event CollectFees(address indexed user, uint256 amount);

    constructor(
        uint16 _maturity,
        address actuatorAddress
    ) 
        ERC20(string.concat("HEX Time Token ", Strings.toString(_maturity)), string.concat("HTT-", Strings.toString(_maturity))) 
    {      
        actr = Actuator(actuatorAddress);
        maturity = _maturity;
        httManager = msg.sender;
    }

    modifier onlyHttManager() {
        require(msg.sender == httManager, "A036");
        _;
    }

    modifier onlyActuator() {
        require(msg.sender == address(actr), "A039");
        _;
    }

    function decimals() public view virtual override returns (uint8) {
        return 8;
    }

    /**
     * @dev Priveleged function for the HTT Manager to mint HEX Time Tokens (HTT) and collect a fee/tax.
     * @param to Recipient address.
     * @param amount Amount of HTTs to transfer.
    */
    function mint(address to, uint256 amount) external onlyHttManager {
        if (totalDeposits == 0) {
            _mint(to, amount);
            return;
        }

        uint256 taxAmount = calculateTax(amount);
        uint256 amountAfterTax = amount - taxAmount;
        accHttPerShare = accHttPerShare + (taxAmount * ACC_HTT_PRECISION / totalDeposits);
        _mint(address(this), taxAmount);
        _mint(to, amountAfterTax);
    }

    /**
     * @dev Priveleged function for the HTT Manager to burn HEX Time Tokens (HTT).
     * @param from Address to burn from.
     * @param amount Amount of HTTs to burn.
    */
    function burn(address from, uint256 amount) external onlyHttManager {
        _burn(from, amount);
    }

    /**
     * @dev Calculates the tax for a given input amount.
     * @param amount Amount of HTTs to apply tax.
    */
    function calculateTax(uint256 amount) public pure returns (uint256) {
        return amount * CREATION_FEE_RATE / 10000; // Assumes CREATION_FEE_RATE is in basis points
    }

    /**
     * @dev Deposit ACTR to collect HEX Time Token (HTT) tax.
     * @param account Address of the depositer.
     * @param _amount Amount of ACTR to deposit.
    */
    function deposit(address account, uint256 _amount) external onlyActuator returns (uint256) {
        UserInfo storage user = userInfo[account];

        totalDeposits += _amount;

        uint256 pending = (user.amount * accHttPerShare / ACC_HTT_PRECISION) - user.rewardDebt;

        user.amount = user.amount + _amount;
        user.rewardDebt = user.amount * accHttPerShare / ACC_HTT_PRECISION;
        user.capitalAdded = block.timestamp;

        if (pending > 0) {
            safeHttTransfer(account, pending);
            emit CollectFees(account, pending);
        }

        emit Deposit(account, _amount);

        return user.amount;
    }

    /**
     * @dev Withdraw ACTR from vault.
     * @param account Address of the depositer.
     * @param _amount Amount of ACTR to withdraw.
    */
    function withdraw(address account, uint256 _amount) external onlyActuator returns (uint256, uint256) {  
        UserInfo storage user = userInfo[account];

        require(user.amount >= _amount, "A037");

        totalDeposits -= _amount;

        uint256 pending = (user.amount * accHttPerShare / ACC_HTT_PRECISION) - user.rewardDebt;

        user.amount = user.amount - _amount;
        user.rewardDebt = user.amount * accHttPerShare / ACC_HTT_PRECISION;

        if (pending > 0) {
            safeHttTransfer(account, pending);
            emit CollectFees(account, pending);
        }
        
        emit Withdraw(account, _amount);

        return (user.amount, user.capitalAdded);
    }

    /**
     * @dev Collect accumulated HTT rewards from tax.
     * @return Amount of HTTs collected.
    */
    function collectFees() external returns (uint256) {  
        UserInfo storage user = userInfo[msg.sender];

        require(user.amount > 0, "A026");

        uint256 pending = (user.amount * accHttPerShare / ACC_HTT_PRECISION) - user.rewardDebt;
        
        user.rewardDebt = user.amount * accHttPerShare / ACC_HTT_PRECISION;

        if (pending > 0) {
            safeHttTransfer(msg.sender, pending);
            emit CollectFees(msg.sender, pending);
        }

        return pending;
    }

    /**
     * @dev Safe HTT transfer function, just in case if rounding error causes pool to not have enough HTT.
     * @param _to Recipient address.
     * @param _amount Amount of HTT tokens to transfer.
    */
    function safeHttTransfer(address _to, uint256 _amount) private {
        uint256 httBal = balanceOf(address(this));
        if (_amount > httBal) {
            _transfer(address(this), _to, httBal);
        } else {
            _transfer(address(this), _to, _amount);
        }
    }

}
