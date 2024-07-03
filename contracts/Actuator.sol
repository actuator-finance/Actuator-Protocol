// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "hardhat/console.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { HEXTimeToken } from "./HEXTimeToken.sol";
import { HEXTimeTokenManager } from "./HEXTimeTokenManager.sol";

contract Actuator is ERC20, Ownable {
    uint256 public totalShares;
    uint256 public lastUpdate;
    uint256 public totalDividendPoints;
    uint256 pointMultiplier = 10e18;

    HEXTimeTokenManager private _httm;
    uint256 private constant MIN_STAKE_TIME = 90 days;

    mapping(address => uint72[]) public depositedMaturities;

    constructor(
        address _httmAddress
    ) 
        ERC20('Actuator', 'ACTR') 
        Ownable(msg.sender)
    {      
        _httm = HEXTimeTokenManager(_httmAddress);
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyOwner {
        _burn(from, amount);
    }

    function vaultCount(
        address user
    )
        public
        view
        returns (uint256)
    {
        return depositedMaturities[user].length;
    }

    function deposit(uint72 maturity, uint256 amount) external {
        (, address tokenAddress) = _httm.maturityToInfo(uint16(maturity));
        require(tokenAddress != address(0), "A033");
        uint72[] storage miners = depositedMaturities[msg.sender];
        miners.push(maturity);

        uint256 newAmount = HEXTimeToken(tokenAddress).deposit(msg.sender, amount);
        require(newAmount == amount, "A034");

        // bypass allowance
        _transfer(msg.sender, address(this), amount);
    }

    function increaseDeposit(uint256 index, uint256 amount) external {
        uint72 maturity = depositedMaturities[msg.sender][index];
        (, address tokenAddress) = _httm.maturityToInfo(uint16(maturity));
        uint256 newAmount = HEXTimeToken(tokenAddress).deposit(msg.sender, amount);
        require(newAmount == amount, "A035");
    }

    function collectFees(uint256 index) external {
        uint72 maturity = depositedMaturities[msg.sender][index];
        (, address tokenAddress) = _httm.maturityToInfo(uint16(maturity));
        HEXTimeToken(tokenAddress).collectFees(msg.sender);
    }

    function withdraw(uint256 index, uint256 amount) external {
        uint72 maturity = depositedMaturities[msg.sender][index];
        (, address tokenAddress) = _httm.maturityToInfo(uint16(maturity));
        (uint256 newAmount, uint256 capitalAdded) = HEXTimeToken(tokenAddress).withdraw(msg.sender, amount);

        if (newAmount == 0) {
            _pruneFeeMiners(msg.sender, index);
        }

        uint servedTime = block.timestamp - capitalAdded;        
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
        uint72[] storage list = depositedMaturities[account];
        uint256 lastIndex = list.length - 1;

        if (index != lastIndex) {
            list[index] = list[lastIndex];
        }

        list.pop();
    }

}
