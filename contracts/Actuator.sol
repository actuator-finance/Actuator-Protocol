// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// import "hardhat/console.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { HEXTimeToken } from "./HEXTimeToken.sol";
import { HEXTimeTokenManager } from "./HEXTimeTokenManager.sol";

contract Actuator is ERC20 {
    uint256 public totalShares;
    uint256 public lastUpdate;
    uint256 public totalDividendPoints;
    uint256 pointMultiplier = 10e18;

    uint256 private constant MIN_VAULT_TIME = 90 days;

    HEXTimeTokenManager public _httm;
    address public masterChef;
    mapping(address => uint16[]) public depositedMaturities;

    constructor(
        address _httmAddress
    ) 
        ERC20('Actuator', 'ACTR') 
    {      
        _httm = HEXTimeTokenManager(_httmAddress);
        masterChef = msg.sender;
    }

    modifier onlyMasterChef() {
        require(msg.sender == masterChef, "A042");
        _;
    }

    function mint(address to, uint256 amount) external onlyMasterChef {
        _mint(to, amount);
    }

    /**
     * @dev Retreives the number of vaults the user has deposited into.
     * @return Number of vaults.
     */
    function vaultCount(
        address user
    )
        external
        view
        returns (uint256)
    {
        return depositedMaturities[user].length;
    }

    /**
     * @dev Deposit ACTR into vault to collect the given HEX Time Token (HTT) tax.
     * @param maturity HTT maturity day to stake against.
     * @param amount Amount of ACTR to deposit.
    */
    function deposit(uint16 maturity, uint256 amount) external {
        require(amount > 0, "A040");
        
        (, address tokenAddress) = _httm.maturityToInfo(maturity);
        require(tokenAddress != address(0), "A033");
        
        uint16[] storage maturities = depositedMaturities[msg.sender];
        maturities.push(maturity);

        uint256 newAmount = HEXTimeToken(tokenAddress).deposit(msg.sender, amount);
        require(newAmount == amount, "A034");

        // bypass allowance
        _transfer(msg.sender, address(this), amount);
    }

    /**
     * @dev Increase deposited ACTR.
     * @param index Index of the user's vaults.
     * @param amount Amount of ACTR to deposit.
    */
    function increaseDeposit(uint256 index, uint256 amount) external {
        require(amount > 0, "A040");
        uint16 maturity = depositedMaturities[msg.sender][index];
        
        (, address tokenAddress) = _httm.maturityToInfo(uint16(maturity));
        uint256 newAmount = HEXTimeToken(tokenAddress).deposit(msg.sender, amount);
        require(newAmount > amount, "A035");

        // bypass allowance
        _transfer(msg.sender, address(this), amount);
    }

    /**
     * @dev Withdraw ACTR from vault.
     * @param index Index of the user's vaults.
     * @param amount Amount of ACTR to withdraw.
    */
    function withdraw(uint256 index, uint256 amount) external {
        require(amount > 0, "A041");
        uint16 maturity = depositedMaturities[msg.sender][index];
        (, address tokenAddress) = _httm.maturityToInfo(uint16(maturity));
        (uint256 newAmount, uint256 capitalAdded) = HEXTimeToken(tokenAddress).withdraw(msg.sender, amount);

        if (newAmount == 0) {
            _pruneDepositedMaturities(msg.sender, index);
        }

        uint256 servedTime = block.timestamp - capitalAdded;        
        if (servedTime < MIN_VAULT_TIME) {
            // Penalty for early withdrawal
            uint256 remainder = amount * servedTime / MIN_VAULT_TIME;
            _burn(address(this), amount - remainder);
            _transfer(address(this), msg.sender, remainder);
        } else {
            _transfer(address(this), msg.sender, amount);
        }
    }

    /**
     * @dev Removes a vault from the user's individual vault list.
     * @param account The relevant user.
     * @param index The index of the vault to remove.
     */
    function _pruneDepositedMaturities(
        address account,
        uint256 index
    )
        private
    {
        uint16[] storage list = depositedMaturities[account];
        uint256 lastIndex = list.length - 1;

        if (index != lastIndex) {
            list[index] = list[lastIndex];
        }

        list.pop();
    }

}
