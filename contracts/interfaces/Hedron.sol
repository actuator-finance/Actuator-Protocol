// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { HEXStakeMinimal } from "../declarations/Types.sol";

interface IHedron {
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
    event Claim(uint256 data, address indexed claimant, uint40 indexed stakeId);
    event LoanEnd(
        uint256 data,
        address indexed borrower,
        uint40 indexed stakeId
    );
    event LoanLiquidateBid(
        uint256 data,
        address indexed bidder,
        uint40 indexed stakeId,
        uint40 indexed liquidationId
    );
    event LoanLiquidateExit(
        uint256 data,
        address indexed liquidator,
        uint40 indexed stakeId,
        uint40 indexed liquidationId
    );
    event LoanLiquidateStart(
        uint256 data,
        address indexed borrower,
        uint40 indexed stakeId,
        uint40 indexed liquidationId
    );
    event LoanPayment(
        uint256 data,
        address indexed borrower,
        uint40 indexed stakeId
    );
    event LoanStart(
        uint256 data,
        address indexed borrower,
        uint40 indexed stakeId
    );
    event Mint(uint256 data, address indexed minter, uint40 indexed stakeId);
    event Transfer(address indexed from, address indexed to, uint256 value);

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function balanceOf(address account) external view returns (uint256);

    function calcLoanPayment(
        address borrower,
        uint256 hsiIndex,
        address hsiAddress
    ) external view returns (uint256, uint256);

    function calcLoanPayoff(
        address borrower,
        uint256 hsiIndex,
        address hsiAddress
    ) external view returns (uint256, uint256);

    function claimInstanced(
        uint256 hsiIndex,
        address hsiAddress,
        address hsiStarterAddress
    ) external;

    function claimNative(uint256 stakeIndex, uint40 stakeId)
        external
        returns (uint256);

    function currentDay() external view returns (uint256);

    function dailyDataList(uint256)
        external
        view
        returns (
            uint72 dayMintedTotal,
            uint72 dayLoanedTotal,
            uint72 dayBurntTotal,
            uint32 dayInterestRate,
            uint8 dayMintMultiplier
        );

    function decimals() external view returns (uint8);

    function decreaseAllowance(address spender, uint256 subtractedValue)
        external
        returns (bool);

    function hsim() external view returns (address);

    function increaseAllowance(address spender, uint256 addedValue)
        external
        returns (bool);

    function liquidationList(uint256)
        external
        view
        returns (
            uint256 liquidationStart,
            address hsiAddress,
            uint96 bidAmount,
            address liquidator,
            uint88 endOffset,
            bool isActive
        );

    function loanInstanced(uint256 hsiIndex, address hsiAddress)
        external
        returns (uint256);

    function loanLiquidate(
        address owner,
        uint256 hsiIndex,
        address hsiAddress
    ) external returns (uint256);

    function loanLiquidateBid(uint256 liquidationId, uint256 liquidationBid)
        external
        returns (uint256);

    function loanLiquidateExit(uint256 hsiIndex, uint256 liquidationId)
        external
        returns (address);

    function loanPayment(uint256 hsiIndex, address hsiAddress)
        external
        returns (uint256);

    function loanPayoff(uint256 hsiIndex, address hsiAddress)
        external
        returns (uint256);

    function loanedSupply() external view returns (uint256);

    function mintInstanced(uint256 hsiIndex, address hsiAddress)
        external
        returns (uint256);

    function mintNative(uint256 stakeIndex, uint40 stakeId)
        external
        returns (uint256);

    function name() external view returns (string memory);

    function proofOfBenevolence(uint256 amount) external;

    function shareList(uint256)
        external
        view
        returns (
            HEXStakeMinimal memory stake,
            uint16 mintedDays,
            uint8 launchBonus,
            uint16 loanStart,
            uint16 loanedDays,
            uint32 interestRate,
            uint8 paymentsMade,
            bool isLoaned
        );

    function symbol() external view returns (string memory);

    function totalSupply() external view returns (uint256);

    function transfer(address recipient, uint256 amount)
        external
        returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);
}