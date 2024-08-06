// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

interface IHEX {
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
    event Claim(
        uint256 data0,
        uint256 data1,
        bytes20 indexed btcAddr,
        address indexed claimToAddr,
        address indexed referrerAddr
    );
    event ClaimAssist(
        uint256 data0,
        uint256 data1,
        uint256 data2,
        address indexed senderAddr
    );
    event DailyDataUpdate(uint256 data0, address indexed updaterAddr);
    event ShareRateChange(uint256 data0, uint40 indexed stakeId);
    event StakeEnd(
        uint256 data0,
        uint256 data1,
        address indexed stakerAddr,
        uint40 indexed stakeId
    );
    event StakeGoodAccounting(
        uint256 data0,
        uint256 data1,
        address indexed stakerAddr,
        uint40 indexed stakeId,
        address indexed senderAddr
    );
    event StakeStart(
        uint256 data0,
        address indexed stakerAddr,
        uint40 indexed stakeId
    );
    event Transfer(address indexed from, address indexed to, uint256 value);
    event XfLobbyEnter(
        uint256 data0,
        address indexed memberAddr,
        uint256 indexed entryId,
        address indexed referrerAddr
    );
    event XfLobbyExit(
        uint256 data0,
        address indexed memberAddr,
        uint256 indexed entryId,
        address indexed referrerAddr
    );

    function allocatedSupply() external view returns (uint256);

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function balanceOf(address account) external view returns (uint256);

    function btcAddressClaim(
        uint256 rawSatoshis,
        bytes32[] memory proof,
        address claimToAddr,
        bytes32 pubKeyX,
        bytes32 pubKeyY,
        uint8 claimFlags,
        uint8 v,
        bytes32 r,
        bytes32 s,
        uint256 autoStakeDays,
        address referrerAddr
    ) external returns (uint256);

    function btcAddressClaims(bytes20) external view returns (bool);

    function btcAddressIsClaimable(
        bytes20 btcAddr,
        uint256 rawSatoshis,
        bytes32[] memory proof
    ) external view returns (bool);

    function btcAddressIsValid(
        bytes20 btcAddr,
        uint256 rawSatoshis,
        bytes32[] memory proof
    ) external pure returns (bool);

    function claimMessageMatchesSignature(
        address claimToAddr,
        bytes32 claimParamHash,
        bytes32 pubKeyX,
        bytes32 pubKeyY,
        uint8 claimFlags,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external pure returns (bool);

    function currentDay() external view returns (uint256);

    function dailyData(uint256)
        external
        view
        returns (
            uint72 dayPayoutTotal,
            uint72 dayStakeSharesTotal,
            uint56 dayUnclaimedSatoshisTotal
        );

    function dailyDataRange(uint256 beginDay, uint256 endDay)
        external
        view
        returns (uint256[] memory list);

    function dailyDataUpdate(uint256 beforeDay) external;

    function decimals() external view returns (uint8);

    function decreaseAllowance(address spender, uint256 subtractedValue)
        external
        returns (bool);

    function globalInfo() external view returns (uint256[13] memory);

    function globals()
        external
        view
        returns (
            uint72 lockedHeartsTotal,
            uint72 nextStakeSharesTotal,
            uint40 shareRate,
            uint72 stakePenaltyTotal,
            uint16 dailyDataCount,
            uint72 stakeSharesTotal,
            uint40 latestStakeId,
            uint128 claimStats
        );

    function increaseAllowance(address spender, uint256 addedValue)
        external
        returns (bool);

    function merkleProofIsValid(bytes32 merkleLeaf, bytes32[] memory proof)
        external
        pure
        returns (bool);

    function name() external view returns (string memory);

    function pubKeyToBtcAddress(
        bytes32 pubKeyX,
        bytes32 pubKeyY,
        uint8 claimFlags
    ) external pure returns (bytes20);

    function pubKeyToEthAddress(bytes32 pubKeyX, bytes32 pubKeyY)
        external
        pure
        returns (address);

    function stakeCount(address stakerAddr) external view returns (uint256);

    function stakeEnd(uint256 stakeIndex, uint40 stakeIdParam) external;

    function stakeGoodAccounting(
        address stakerAddr,
        uint256 stakeIndex,
        uint40 stakeIdParam
    ) external;

    function stakeLists(address, uint256)
        external
        view
        returns (
            uint40 stakeId,
            uint72 stakedHearts,
            uint72 stakeShares,
            uint16 lockedDay,
            uint16 stakedDays,
            uint16 unlockedDay,
            bool isAutoStake
        );

    function stakeStart(uint256 newStakedHearts, uint256 newStakedDays)
        external;

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

    function xfLobby(uint256) external view returns (uint256);

    function xfLobbyEnter(address referrerAddr) external payable;

    function xfLobbyEntry(address memberAddr, uint256 entryId)
        external
        view
        returns (uint256 rawAmount, address referrerAddr);

    function xfLobbyExit(uint256 enterDay, uint256 count) external;

    function xfLobbyFlush() external;

    function xfLobbyMembers(uint256, address)
        external
        view
        returns (uint40 headIndex, uint40 tailIndex);

    function xfLobbyPendingDays(address memberAddr)
        external
        view
        returns (uint256[2] memory words);

    function xfLobbyRange(uint256 beginDay, uint256 endDay)
        external
        view
        returns (uint256[] memory list);
}

