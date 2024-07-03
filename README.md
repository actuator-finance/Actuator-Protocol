# Actuator

Actuator is a collection of Ethereum / PulseChain smart contracts that build upon the Hedron and Hex smart contracts to provide additional functionality. 

The following smart contract is **UNLICENSED, All rights are reserved**. 

    ./contracts/auxiliary/HEXTimeTokenManager.sol

This repository provided for auditing, research, and interfacing purposes only. Copying any **UNLICENSED** smart contract is strictly prohibited.

## Contracts of Interest

**HEXTimeTokenManager.sol** - Contract used for managing delegated HEX stake instances and the HEX Time Tokens minted against them.

**HEXTimeToken.sol** - Multi-instance ERC20 contract representing HEX Time Tokens.
 
**Actuator.sol** - ERC20 contract responsible for creating and staking ACTR tokens.

**MasterChef.sol** - Contract responsible for managing ACTR liquidity farms.

# Getting Started
To set up the project, follow these steps:
1. Clone the repository
```shell
git clone https://github.com/actuator-finance/actuator.git
```
2. Clone the repository
```shell
npm install
```
3. Run Test
```shell
npm run test
```
