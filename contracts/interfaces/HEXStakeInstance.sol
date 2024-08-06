// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { HEXStakeMinimal, HEXStake } from "../declarations/Types.sol";

interface IHEXStakeInstance {
    /**
     * @dev Calls the HEX function "stakeGoodAccounting" against the
     *      HEX stake held within the HSI.
     */
    function share() external view returns (
      HEXStakeMinimal memory stake,
      uint16          mintedDays,
      uint8           launchBonus,
      uint16          loanStart,
      uint16          loanedDays,
      uint32          interestRate,
      uint8           paymentsMade,
      bool            isLoaned
    );

    /**
     * @dev Calls the HEX function "stakeGoodAccounting" against the
     *      HEX stake held within the HSI.
     */
    function goodAccounting() external;

    /**
     * @dev Fetches stake data from the HEX contract.
     * @return A "HEXStake" object containg the HEX stake data. 
     */
    function stakeDataFetch() external view returns(HEXStake memory);
}
