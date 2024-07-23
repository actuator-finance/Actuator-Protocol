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

    uint256 private constant MIN_STAKE_TIME = 90 days;

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

    function vaultCount(
        address user
    )
        external
        view
        returns (uint256)
    {
        return depositedMaturities[user].length;
    }

    function deposit(uint16 maturity, uint256 amount) external {
        require(amount > 0, "A040");
        
        (, address tokenAddress) = _httm.maturityToInfo(maturity);
        require(tokenAddress != address(0), "A033");
        
        uint16[] storage miners = depositedMaturities[msg.sender];
        miners.push(maturity);

        uint256 newAmount = HEXTimeToken(tokenAddress).deposit(msg.sender, amount);
        require(newAmount == amount, "A034");

        // bypass allowance
        _transfer(msg.sender, address(this), amount);
    }

    function increaseDeposit(uint256 index, uint256 amount) external {
        require(amount > 0, "A040");
        uint16 maturity = depositedMaturities[msg.sender][index];
        
        (, address tokenAddress) = _httm.maturityToInfo(uint16(maturity));
        uint256 newAmount = HEXTimeToken(tokenAddress).deposit(msg.sender, amount);
        require(newAmount > amount, "A035");

        // bypass allowance
        _transfer(msg.sender, address(this), amount);
    }

    function withdraw(uint256 index, uint256 amount) external {
        require(amount > 0, "A041");
        uint16 maturity = depositedMaturities[msg.sender][index];
        (, address tokenAddress) = _httm.maturityToInfo(uint16(maturity));
        (uint256 newAmount, uint256 capitalAdded) = HEXTimeToken(tokenAddress).withdraw(msg.sender, amount);

        if (newAmount == 0) {
            _pruneFeeMiners(msg.sender, index);
        }

        uint256 servedTime = block.timestamp - capitalAdded;        
        if (servedTime < MIN_STAKE_TIME) {
            // Penalty for early withdrawal
            uint256 remainder = amount * servedTime / MIN_STAKE_TIME;
            _burn(address(this), amount - remainder);
            _transfer(address(this), msg.sender, remainder);
        } else {
            _transfer(address(this), msg.sender, amount);
        }
    }

    /**
     * @dev Removes a HEX stake instance (HSI) contract address from an address mapping.
     * @param account A mapped list of HSI contract addresses.
     * @param index The index of the matuirty which will be removed.
     */
    function _pruneFeeMiners(
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
