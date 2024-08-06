// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

// import "hardhat/console.sol";
import { HEXTimeToken } from "./HEXTimeToken.sol";
import { IHEX } from "./interfaces/HEX.sol";
import { HEXStake } from "./declarations/Types.sol";
import { IHEXStakeInstance } from "./interfaces/HEXStakeInstance.sol";
import { IHEXStakeInstanceManager } from "./interfaces/HEXStakeInstanceManager.sol";
import { IHedron } from "./interfaces/Hedron.sol";
import { MasterChef } from "./MasterChef.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Actuator } from "./Actuator.sol"; 

contract HEXTimeTokenManager {
    uint256 private constant LATE_PENALTY_GRACE_WEEKS = 2;
    uint256 private constant LATE_PENALTY_GRACE_DAYS = LATE_PENALTY_GRACE_WEEKS * 7;
    uint256 private constant LATE_PENALTY_SCALE_WEEKS = 100;
    uint256 private constant LATE_PENALTY_SCALE_DAYS = LATE_PENALTY_SCALE_WEEKS * 7;
    uint256 private constant MAX_REDEMPTION_DEFERMENT = LATE_PENALTY_SCALE_DAYS - (LATE_PENALTY_SCALE_DAYS / 10); 
    uint256 private constant PAYOUT_RESOLUTION = 1e18;
    uint256 private constant RESERVE_FACTOR_SCALE = 1e5;
    uint256 private constant BASE_RESERVE_FACTOR = 1e6;
    uint256 private constant PAYOUT_START_DAY = 800;
    uint256 private constant SUBSIDY_GRACE_DAYS = 3;
    uint256 private constant HEX_LAUNCH = 1575331200;
    address private constant HEX_ADDRESS = 0x2b591e99afE9f32eAA6214f7B7629768c40Eeb39;
    address private constant HSIM_ADDRESS = 0x8BD3d1472A656e312E94fB1BbdD599B8C51D18e3;
    address private constant HEDRON_ADDRESS = 0x3819f64f282bf135d62168C1e513280dAF905e06;
    uint256 private constant EARLY_PENALTY_MIN_DAYS = 90;

    struct Collateral { 
        uint72 amount; 
        uint16 maturity; 
        address owner; 
    }

    struct MaturityInfo { 
        uint72 hexBalance; 
        address tokenAddress; 
    }

    struct MultiEndStakeParams {
        address hsiAddress;
        uint256 hsiIndex;
        uint256 collateralIndex;
        uint256 hedronHsiIndex;
    }

    address public actuatorAddress;
    address public masterChefAddress;
    address private _creator;
    IHEX private _hx;
    IHEXStakeInstanceManager private _hsim;
    IHedron private _hedron;

    uint72[] public payouts;

    mapping(address => address[]) public hsiLists;
    mapping(uint16 => MaturityInfo) public maturityToInfo;
    mapping(address => Collateral) public hsiToCollateral;
    mapping(uint16 => address[]) public maturityToCollateralizedHsiList;

    event DailyDataUpdate(address indexed updaterAddr, uint16 beforeDay, bool isAuto);
    event CreateHEXTimeToken(uint16 indexed maturity);
    event MintHEXTimeTokens(address indexed user, address indexed hsiAddress, uint16 indexed maturity, uint256 amount);
    event RetireHEXTimeTokens(address indexed user, address indexed hsiAddress, uint16 indexed maturity, uint256 amount);
    event RedeemHEXTimeTokens(address indexed user, uint16 indexed maturity, uint256 amount);
    event DelegateHSI(address indexed user, uint256 indexed tokenId, address indexed hsiAddress);
    event RevokeHSI(address indexed user, uint256 indexed tokenId, address indexed hsiAddress);
    event StartStake(address indexed user, address indexed hsiAddress);
    event EndStake(address indexed user, address indexed hsiAddress);
    event EndCollateralizedStake(address indexed user, address indexed hsiAddress);

    constructor(
        address teamAddress,
        address factoryAddress,
        uint72[] memory initialPayouts,
        uint256 farmStartTime,
        uint256[3] memory _farmSupplySchedule,
        uint256[3] memory _teamSupplySchedule,
        uint256[14] memory _poolPointSchedule
    ) {
        _hx = IHEX(HEX_ADDRESS);
        _hsim = IHEXStakeInstanceManager(HSIM_ADDRESS);
        _hedron = IHedron(HEDRON_ADDRESS);
        MasterChef masterChef = new MasterChef(teamAddress, factoryAddress, farmStartTime, _farmSupplySchedule, _teamSupplySchedule, _poolPointSchedule);
        actuatorAddress = address(masterChef.actr());
        masterChefAddress = address(masterChef);
        payouts = initialPayouts;
    }

    /**
     * @dev Calculates the current HEX day.
     * @return Number representing the current HEX day.
     */
    function _currentDay()
        private
        view
        returns (uint256)
    {
        return (block.timestamp - HEX_LAUNCH) / 1 days;
    }
    
    /**
     * @dev Update daily payout data.
     */
    function updateDailyData(uint256 beforeDay) external {
        _updateDailyData(beforeDay, false);
    }

    /**
     * @dev Update daily payout data.
     */
    function _updateDailyDataAuto(uint256 beforeDay) private {
        _updateDailyData(beforeDay, true);
    }

    /**
     * @dev Update daily payout data.
     */
    function _updateDailyData(uint256 beforeDay, bool isAuto) private {
        uint256 day = PAYOUT_START_DAY + payouts.length;
        if (day >= beforeDay) return;

        _hx.dailyDataUpdate(beforeDay);

        uint256 dayPayoutPerTShare;
        uint256 dayPayoutTotal;
        uint256 dayStakeSharesTotal;
        uint72 lastPayout = payouts.length > 0 ? payouts[payouts.length - 1] : 0;
        while (day < beforeDay) {
            (dayPayoutTotal, dayStakeSharesTotal,) = _hx.dailyData(day);
            if (dayStakeSharesTotal > 0) {
              dayPayoutPerTShare = dayPayoutTotal * PAYOUT_RESOLUTION / dayStakeSharesTotal;
            } else {
              dayPayoutPerTShare = 0;
            }

            lastPayout = uint72(dayPayoutPerTShare + lastPayout);
            payouts.push(lastPayout);
            day++;
        }

        emit DailyDataUpdate(msg.sender, uint16(beforeDay), isAuto); 
    }

    /**
     * @dev Get HEX Time Token or create token if it doesn't already exist.
     * @param maturity The HEX day the token is redeemable for HEX.
     * @return Address of the HEX Time Token.
     */
    function getOrCreateHEXTimeToken(uint16 maturity) public returns (address) {
        if (maturityToInfo[maturity].tokenAddress == address(0)) {
            ERC20 newToken = new HEXTimeToken(maturity + 1, actuatorAddress);
            maturityToInfo[maturity].tokenAddress = address(newToken);
            emit CreateHEXTimeToken(maturity);
        }
        return maturityToInfo[maturity].tokenAddress;
    }

    /**
     * @dev Creates a new HEX stake instance (HSI) and delegates control to the HEXTimeTokenManager. 
     * @param amount Number of HEX ERC20 tokens to be staked.
     * @param length Number of days the HEX ERC20 tokens will be staked.
     * @return Address of the newly created HSI contract.
     */
    function hexStakeStart(uint256 amount, uint256 length) external returns (address) {
        require(_hx.transferFrom(msg.sender, address(this), amount), "A016");

        _hx.increaseAllowance(HSIM_ADDRESS, amount);       

        address hsiAddress = _hsim.hexStakeStart(amount, length);

        hsiLists[msg.sender].push(hsiAddress);

        emit StartStake(msg.sender, hsiAddress);

        return hsiAddress;
    }

    /**
     * @dev Transfers control of the tokenized HSI to the HEXTimeTokenManager and detokenizes.
     * @param tokenId ID of the HSI ERC721 token to be converted.
     * @return Address of the detokenized HSI contract.
     */
    function delegateHSI(uint256 tokenId) external returns (address) {
        _hsim.transferFrom(msg.sender, address(this), tokenId);

        address hsiAddress = _hsim.hexStakeDetokenize(tokenId);

        hsiLists[msg.sender].push(hsiAddress);

        emit DelegateHSI(msg.sender, tokenId, hsiAddress);

        return hsiAddress;
    }

    /**
     * @dev Mints HEX Maturity tokens (HTTs) against an HSI's underlying HEX. 
     *      When maturity day is after end stake day, extractable HTT quantity is lowered by the maximum possible end stake HEX penalty. 
     * @param hsiIndex Index of the HSI address in the caller's HSI list.
     * @param amount Quanity of HTTs to mint.
     * @param maturity The Hex day which the HTTs mature.
     * @return Address of the HTT token.
     */
    function mintHEXTimeTokens (
        uint256 hsiIndex,
        uint256 amount,
        uint256 maturity
    ) 
        external 
        returns (address) 
    {
        require(amount > 0, "A023");
        require(hsiIndex < hsiLists[msg.sender].length, "A012");
        address hsiAddress = hsiLists[msg.sender][hsiIndex];
        Collateral storage collateral = hsiToCollateral[hsiAddress];
        require(collateral.maturity == 0 || collateral.maturity == maturity, "A013");

        _updateDailyDataAuto(_currentDay());
        uint256 extractableAmount = getExtractableAmount(hsiAddress, maturity);
        require(collateral.amount + amount <= extractableAmount, "A002");

        if (collateral.amount == 0) {
            maturityToCollateralizedHsiList[uint16(maturity)].push(hsiAddress);
            collateral.maturity = uint16(maturity);
            collateral.owner = msg.sender;
        } 
        collateral.amount += uint72(amount);

        address tokenAddress = getOrCreateHEXTimeToken(uint16(maturity));
        HEXTimeToken(tokenAddress).mint(msg.sender, amount);

        emit MintHEXTimeTokens(msg.sender, hsiAddress, uint16(maturity), amount);

        return tokenAddress;
    }

    /**
     * @dev Mints Hedron ERC20 (HDRN) tokens to the sender using a HEX stake instance (HSI) backing.
     * @param hsiIndex Index of the HSI address in the caller's HSI list.
     * @param hedronHsiIndex Index of the HSI address stored in Hedron's HSI list.
     * @return Amount of HDRN ERC20 tokens minted.
     */
    function mintInstanced(
        uint256 hsiIndex,
        uint256 hedronHsiIndex
    ) 
        external
        returns (uint256)
    {
        require(hsiIndex < hsiLists[msg.sender].length, "A012");

        address hsiAddress = hsiLists[msg.sender][hsiIndex];
        uint256 amount = _hedron.mintInstanced(hedronHsiIndex, hsiAddress);
        _hedron.transfer(msg.sender, amount);
        return amount;
    }

    /**
     * @dev Burns Hex Maturity Tokens (HTTs) previously minted against a HSI 
     *      and returns control of the collateralized underlying HEX back to the staker.
     * @param hsiIndex Index of the HSI address in the caller's HSI list.
     * @param collateralIndex Index of the HSI address in the collateralized HSI list.
     * @param amount Number of HTTs to retire.
     */
    function retireHEXTimeTokens(
        uint256 hsiIndex,
        uint256 collateralIndex,
        uint256 amount
    ) 
        external 
    {
        require(hsiIndex < hsiLists[msg.sender].length, "A012");
        require(amount > 0, "A024");
        
        address hsiAddress = hsiLists[msg.sender][hsiIndex];
        Collateral storage collateral = hsiToCollateral[hsiAddress];
        uint16 maturity = collateral.maturity; // stash before prune

        require(hsiAddress == maturityToCollateralizedHsiList[maturity][collateralIndex], "A006");
        require(_currentDay() < maturity, "A003");
        require(amount <= collateral.amount, "A001");

        if (collateral.amount - amount == 0) {
            _pruneCollateralizedHSI(maturity, collateralIndex); 
            delete hsiToCollateral[hsiAddress]; // order matters
        } else {
            collateral.amount -= uint72(amount);
        }

        HEXTimeToken(maturityToInfo[maturity].tokenAddress).burn(msg.sender, amount);

        emit RetireHEXTimeTokens(msg.sender, hsiAddress, maturity, amount);
    }

    /**
     * @dev Tokenizes the HSI and transfers control of the tokenized HSI to caller.
     * @param hsiIndex Index of the HSI address in the caller's HSI list.
     * @param hedronHsiIndex Index of the HSI address stored in Hedron's HSI list.
     * @return Token ID of the HSI ERC721 token.
     */
    function revokeHSIDelegation(uint256 hsiIndex, uint256 hedronHsiIndex) external returns (uint256) {
        address[] storage hsiList = hsiLists[msg.sender];
        require(hsiIndex < hsiList.length, "A012");

        address hsiAddress = hsiList[hsiIndex];
        require(hsiToCollateral[hsiAddress].amount == 0, "A000");

        _pruneHSI(hsiList, hsiIndex);

        uint256 tokenId = _hsim.hexStakeTokenize(hedronHsiIndex, hsiAddress);

        _hsim.transferFrom(address(this), msg.sender, tokenId);

        emit RevokeHSI(msg.sender, tokenId, hsiAddress);

        return tokenId;
    }

    /**
     * @dev Unlocks the stake.
     * @param hsiIndex Index of the HSI address in the caller's HSI list.
     * @param hedronHsiIndex Index of the HSI address stored in Hedron's HSI list.
     */
    function endHEXStake(
        uint256 hsiIndex,
        uint256 hedronHsiIndex
    ) 
        external 
        returns (uint256)
    {
        address[] storage hsiList = hsiLists[msg.sender];
        require(hsiIndex < hsiList.length, "A012");

        address hsiAddress = hsiList[hsiIndex];
        require(hsiToCollateral[hsiAddress].amount == 0, "A019");

        _pruneHSI(hsiList, hsiIndex);

        uint256 hsiBalance = _hsim.hexStakeEnd(hedronHsiIndex, hsiAddress);

        if (hsiBalance > 0) require(_hx.transfer(msg.sender, hsiBalance), "A010");

        emit EndStake(msg.sender, hsiAddress);

        return hsiBalance;
    }

    /**
     * @dev Allows the stake owner to unlock the collateralized HSI once fully served, 
     *      otherwise anyone can unlock once minted HTTs are redeemable.
     * @param hsiAddress Address of the HSI.
     * @param hsiIndex Index of the HSI address in the caller's HSI list.
     * @param collateralIndex Index of the HSI address in the collateralized HSI list.
     * @param hedronHsiIndex Index of the HSI address stored in Hedron's HSI list.
     */
    function endCollateralizedHEXStake(
        address hsiAddress,
        uint256 hsiIndex,
        uint256 collateralIndex,
        uint256 hedronHsiIndex
    ) 
        public 
    {
        Collateral memory collateral = hsiToCollateral[hsiAddress];
        uint256 collateralAmount = collateral.amount;
        uint16 maturity = collateral.maturity;
        address owner = collateral.owner;

        require(collateralAmount > 0, "A018");
        require(hsiAddress == hsiLists[owner][hsiIndex], "A004");
        require(hsiAddress == maturityToCollateralizedHsiList[maturity][collateralIndex], "A006");

        uint256 currentDay = _currentDay(); 
        (,, uint256 stakeShares, uint16 lockedDay, uint16 stakedDays,,) = _hx.stakeLists(hsiAddress, 0);

        if (currentDay < maturity) {
            // stake owner can end stake once fully served
            require(owner == msg.sender && currentDay >= lockedDay + stakedDays, "A022");
        } 

        _pruneHSI(hsiLists[owner], hsiIndex);
        _pruneCollateralizedHSI(maturity, collateralIndex);
        delete hsiToCollateral[hsiAddress];

        _updateDailyDataAuto(currentDay);

        uint256 hsiBalance = _hsim.hexStakeEnd(hedronHsiIndex, hsiAddress);

        // End staker gets 1st priority of unlocked HEX (in event of late end stake)
        if (hsiBalance > 0) {
            uint256 effectiveStakedDays = maturity - lockedDay < stakedDays? maturity - lockedDay: stakedDays;
            uint256 endStakeSubsidy = calcEndStakeSubsidy(lockedDay, effectiveStakedDays, maturity, currentDay, stakeShares);
            if (endStakeSubsidy > 0) {
                endStakeSubsidy = endStakeSubsidy < hsiBalance? endStakeSubsidy: hsiBalance;
                hsiBalance -= endStakeSubsidy;
                require(_hx.transfer(msg.sender, endStakeSubsidy), "A010");
            }
        }
                
        // HTT holders get 2nd priority of unlocked HEX (in event of late end stake)
        if (hsiBalance > 0) {
            collateralAmount = collateralAmount < hsiBalance? collateralAmount: hsiBalance;
            maturityToInfo[uint16(maturity)].hexBalance += uint72(collateralAmount); 
            hsiBalance -= collateralAmount;
        }

        // Stake creator gets last priority of unlocked HEX (in event of late end stake)
        if (hsiBalance > 0) require(_hx.transfer(owner, hsiBalance), "A010");

        emit EndCollateralizedStake(msg.sender, hsiAddress);
    }

    /**
     * @dev Allows any address to unlock a fully matured collateralized stake and subsequently redeem HTTs.
     * @param maturity The maturity of the HTT to redeem.
     * @param amount The amount of HTTs to redeem.
     */
    function endHEXStakesAndRedeem(
        uint256 maturity, 
        uint256 amount, 
        MultiEndStakeParams[] memory data
    ) 
        external 
    {
        endHEXStakes(data);
        redeemHEXTimeTokens(maturity, amount);
    }

    /**
     * @dev Allows any address to unlock fully matured collateralized stakes and subsequently redeem HTTs.
     * @param data The relevant stake data needed to unlock.
     */
    function endHEXStakes(MultiEndStakeParams[] memory data) public {
        for (uint256 i = 0; i < data.length; i++) {
            endCollateralizedHEXStake(data[i].hsiAddress, data[i].hsiIndex, data[i].collateralIndex, data[i].hedronHsiIndex);
        }
    }

    /**
     * @dev Redeem HEX Maturity tokens (HTT) for HEX. 
     * @param maturity Maturity day of the HTT.
     * @param amount Number of HTTs to redeem.
     */
    function redeemHEXTimeTokens(uint256 maturity, uint256 amount) public {
        MaturityInfo storage info = maturityToInfo[uint16(maturity)];

        HEXTimeToken token = HEXTimeToken(info.tokenAddress);

        require(_currentDay() >= maturity, "A009");
        require(amount <= token.balanceOf(msg.sender), "A008");
        require(amount <= info.hexBalance, "A007");

        info.hexBalance -= uint72(amount);

        token.burn(msg.sender, amount);

        require(_hx.transfer(msg.sender, amount), "A010");

        emit RedeemHEXTimeTokens(msg.sender, uint16(maturity), amount);
    }

    /**
     * @dev Removes a HEX stake instance (HSI) address from an individual owner's HSI List.
     * @param hsiList A mapped list of HSI contract addresses.
     * @param hsiIndex The index of the HSI address which will be removed.
     */
    function _pruneHSI(address[] storage hsiList, uint256 hsiIndex) private {
        uint256 lastIndex = hsiList.length - 1;

        if (hsiIndex != lastIndex) {
            hsiList[hsiIndex] = hsiList[lastIndex];
        }

        hsiList.pop();
    }

    /**
     * @dev Removes a HEX stake instance (HSI) address from the collateralized HSI List.
     * @param maturity A mapped list of HSI contract addresses.
     * @param collateralIndex Index of the collateralized HSI address which will be removed.
     */
    function _pruneCollateralizedHSI(uint16 maturity, uint256 collateralIndex) private {
        address[] storage collateralizedHsiList = maturityToCollateralizedHsiList[maturity];

        uint256 lastIndex = collateralizedHsiList.length - 1;

        if (collateralIndex != lastIndex) {
            collateralizedHsiList[collateralIndex] = collateralizedHsiList[lastIndex];
        }

        collateralizedHsiList.pop();
    }

    /**
     * @dev Calculates the total quantity of extractable HEX Maturity Tokens (HTT) from a stake.
     * @param hsiAddress Address of the HSI.
     * @param maturity maturity of the HTT to extract.
     * @return Total quantity of extractable HTT.
     */
    function getExtractableAmount(
        address hsiAddress,
        uint256 maturity
    ) 
        public 
        view
        returns (uint256) 
    {
        (,uint256 stakeValue, uint72 stakeShares, uint256 lockedDay, uint16 stakedDays,,) = _hx.stakeLists(hsiAddress, 0);
        uint256 endStakeDay = lockedDay + stakedDays;
        uint256 currentDay = _currentDay();

        if (maturity < endStakeDay) {
            require(currentDay < maturity, "A045");
            uint256 penaltyDays = (stakedDays + 1) / 2;
            require(penaltyDays >= EARLY_PENALTY_MIN_DAYS, "A046");

            uint256 penaltyEndDay = lockedDay + penaltyDays;
            uint256 effectiveStakedDays = maturity - lockedDay;
            uint256 reserveDay = getReserveDay(lockedDay, effectiveStakedDays, maturity);
            require(reserveDay >= penaltyEndDay, "A047");
            stakeValue += calculateRewards(penaltyEndDay, currentDay < reserveDay? currentDay: reserveDay, stakeShares);
        } else {
            require(currentDay < endStakeDay, "A014");
            require(maturity - endStakeDay < MAX_REDEMPTION_DEFERMENT, "A017");

            uint256 reserveDay = getReserveDay(lockedDay, stakedDays, maturity);
            // only calculate rewards up to the earlier of the current day or the reserve day
            stakeValue += calculateRewards(lockedDay, currentDay < reserveDay? currentDay: reserveDay, stakeShares);

            if (endStakeDay < maturity) {
                // assume worst case scenario and subtract maximal possible late penalty from extractable amount
                stakeValue -= calcLatePenalty(lockedDay, stakedDays, maturity + LATE_PENALTY_GRACE_DAYS, stakeValue);
            }
        }

        return stakeValue;
    }

    /**
     * @dev Finds the index of the HSI address in Hedron's HSI list.
     * @param hsiAddress Address of the HSI.
     * @return Index of the HSI address in Hedron's HSI list.
     */
    function findHedronHSIIndex(address hsiAddress) external view returns (int) {
        uint256 count = _hsim.hsiCount(address(this));
        for (uint256 i = 0; i < count; i++) {
            address addr = _hsim.hsiLists(address(this), i);
            if (addr == hsiAddress) return int(i);
        }
        return -1; 
    }

    /**
     * @dev Finds the index of the HSI address in the individual owner's HSI list.
     *      This function only works on collateralized HSIs.
     * @param hsiAddress Address of the HSI.
     * @return Index of the HSI address in the HSI list.
     */
    function findHSIIndex(address hsiAddress) external view returns (int) {
        address owner = hsiToCollateral[hsiAddress].owner;
        for (uint256 i = 0; i < hsiLists[owner].length; i++) {
            address addr = hsiLists[owner][i];
            if (addr == hsiAddress) return int(i);
        }
        return -1; 
    }

    /**
     * @dev Finds all underlying HSI addresses backing HTTs for the given maturity.
     * @param maturity maturity of the HTT
     * @param start range start
     * @param end range end (non-inclusive)
     * @return list array of HSI addresses
     */
    function hsiListRange(
        uint256 maturity, 
        uint256 start, 
        uint256 end
    ) 
        external 
        view 
        returns (address[] memory list) 
    {
        address[] memory hsiList = maturityToCollateralizedHsiList[uint16(maturity)];
        end = end > hsiList.length? hsiList.length: end;
        if (end - start == 0) return list;

        list = new address[](end - start);  

        uint256 dst;
        uint256 i = start;
        do {
            list[dst++] = hsiList[i];
        } while (++i < end);

        return list;
    }

    /**
     * @dev Finds all underlying HSI data backing HTTs for the given maturity.
     * @param maturity Maturity of the HTT
     * @param start Range start
     * @param end Range end (non-inclusive)
     * @return list Array of packed HSI/collateral data
     */
    function hsiDataListRange(
        uint256 maturity, 
        uint256 start, 
        uint256 end
    ) 
        external 
        view 
        returns (uint256[] memory list) 
    {
        address[] memory hsiList = maturityToCollateralizedHsiList[uint16(maturity)];
        end = end > hsiList.length? hsiList.length: end;
        if (end - start == 0) return list;

        list = new uint256[](end - start);  

        uint256 i = start;
        uint256 dst;
        uint256 v;
        do {
            address hsiAddress = hsiList[i];
            (,, uint72 stakeShares, uint16 lockedDay, uint16 stakedDays,,) = _hx.stakeLists(hsiAddress, 0);
            Collateral memory collateral = hsiToCollateral[hsiAddress];
            v = uint256(collateral.amount) << (72 * 2);
            v |= uint256(stakeShares) << 72;
            v |= uint256(lockedDay) << 16;
            v |= uint256(stakedDays);

            list[dst++] = v;
        } while (++i < end);

        return list;
    }

    /**
     * @dev Finds all cumulative payouts within the range. 
     * @param beginDay First day of data range
     * @param endDay Last day (non-inclusive) of data range
     * @return list Array of cumulative payouts
     */
    function dailyDataRange(uint256 beginDay, uint256 endDay) external view returns (uint256[] memory list) {
        list = new uint256[](endDay - beginDay);

        uint256 src = beginDay;
        uint256 dst;
        do {
            list[dst++] = payouts[src - PAYOUT_START_DAY];
        } while (++src < endDay);

        return list;
    }

    /**
     * @dev function to pull stake and collateral data.
     * @param owner Address used to retrieve the HSI list.
     * @param hsiIndex Index of the HSI address in the owner's HSI list.
     */
    function shareLists(
        address owner, 
        uint256 hsiIndex
    ) 
        external 
        view
        returns (
            uint40 stakeId, 
            uint72 stakedHearts, 
            uint72 stakeShares, 
            uint16 lockedDay, 
            uint16 stakedDays, 
            uint256 collateralAmount, 
            uint256 maturity, 
            address hsiAddress
        )
    {
        hsiAddress = hsiLists[owner][hsiIndex];
        (stakeId, stakedHearts, stakeShares, lockedDay, stakedDays,,) = _hx.stakeLists(hsiAddress, 0);

        collateralAmount = hsiToCollateral[hsiAddress].amount;
        maturity = hsiToCollateral[hsiAddress].maturity;

        return (
            stakeId, 
            stakedHearts, 
            stakeShares, 
            lockedDay, 
            stakedDays, 
            collateralAmount, 
            maturity, 
            hsiAddress
        );
    }

    /**
     * @dev Retreives the number of HSI elements for the given user's HSI list.
     * @param user Address used to retrieve the HSI list.
     * @return Number of HSI elements found in the user's HSI list.
     */
    function hsiCount(
        address user
    ) 
        public
        view 
        returns (uint256) 
    {
        return hsiLists[user].length;
    }

    /**
     * @dev Wrapper for hsiCount allowing for HEX-based apps to fetch stake data.
     * @param user Address used to retrieve the HSI list.
     * @return Number of HSI elements found in the user's HSI list.
    */
    function stakeCount(
        address user
    )
        external
        view
        returns (uint256)
    {
        return hsiCount(user);
    }

    /**
     * @dev Wrapper for hsiLists allowing for HEX-based apps to fetch stake data.
     * @param user Address used to retrieve the HSI list.
     * @param hsiIndex Index of the HSI address in the user's HSI list.
     * @return HEX stake data. 
     */
    function stakeLists(
        address user,
        uint256 hsiIndex
    )
        external
        view
        returns (HEXStake memory)
    {
        address[] storage hsiList = hsiLists[user];

        IHEXStakeInstance hsi = IHEXStakeInstance(hsiList[hsiIndex]);

        return hsi.stakeDataFetch();
    }

    /**
     * @dev Calculates accrued HEX rewards for a given range and share amount. 
     * @param beginDay begin day (inclusive).
     * @param endDay end day (exclusive).
     * @param stakeShares Number of shares.
     * @return Rewards amount.
     */
    function calculateRewards(
        uint256 beginDay, 
        uint256 endDay, 
        uint256 stakeShares
    ) 
        public 
        view 
        returns (uint256) 
    {
        if (beginDay >= endDay) return 0;

        uint256 start = payouts[beginDay - 1 - PAYOUT_START_DAY];
        uint256 end = payouts[endDay - 1 - PAYOUT_START_DAY];

        uint256 rewards = (end - start) * stakeShares / PAYOUT_RESOLUTION;

        // hex contract has less precision for rewards and results up to 1 heart of precision per day loss when calculating rewards
        // thus we assume worst case scenario and subtract the maximal possible precision loss from the rewards (i.e. 1 heart per day)
        uint256 precisionLoss = endDay - beginDay;
        return precisionLoss < rewards? rewards - precisionLoss: 0;
    }

    /**
     * @dev Calculates the subsidy for unlocking a stake. 
     * @param lockedDay begin day (inclusive)
     * @param stakedDays Number of days staked
     * @param maturity Maturity day of the HTTs minted against the stake
     * @param unlockedDay Day the stake is unlocked
     * @param stakeShares Number of shares
     * @return Subsidy amount.
     */
    function calcEndStakeSubsidy(
        uint256 lockedDay, 
        uint256 stakedDays,
        uint256 maturity,
        uint256 unlockedDay, 
        uint256 stakeShares
    ) 
        public 
        view 
        returns (uint256) 
    {
        if (unlockedDay <= maturity + SUBSIDY_GRACE_DAYS) return 0;

        uint256 endDay = lockedDay + stakedDays; 

        uint256 reserveDay = getReserveDay(lockedDay, stakedDays, maturity); 
        uint256 reserves = calculateRewards(reserveDay, endDay, stakeShares);
        uint256 maxSubsidy = reserves - calcLatePenalty(lockedDay, stakedDays, unlockedDay, reserves);

        uint256 daysLate = unlockedDay - maturity - SUBSIDY_GRACE_DAYS;
        uint256 factor = daysLate < 10? daysLate: 10;
        return maxSubsidy * factor / 10;
    }

    /**
     * @dev Calculates the first HEX day to begin reserving stake rewards in the event of an unlock subsidy. 
     * @param lockedDay begin day (inclusive)
     * @param stakedDays Number of days staked
     * @param maturity Maturity day of the HTTs minted against the stake
     * @return Reserve day
     */
    function getReserveDay(
        uint256 lockedDay, 
        uint256 stakedDays,
        uint256 maturity 
    ) 
        public 
        pure 
        returns (uint256) 
    {
        uint256 endDay = lockedDay + stakedDays;
        uint256 factor = BASE_RESERVE_FACTOR; // reserveDays defaults to 10% of stakedDays

        if (maturity > endDay) {
            // scale up reserveDays as potential late penalty increases
            uint256 unpenalizedDays = LATE_PENALTY_SCALE_DAYS - (maturity - endDay);
            factor = factor * LATE_PENALTY_SCALE_DAYS / unpenalizedDays;
        }

        uint256 denominator = 100 * RESERVE_FACTOR_SCALE;
        uint256 reserveDays = (stakedDays * factor + denominator - 1) / denominator;
        return endDay - reserveDays;
    }

    /**
     * @dev Calculates the late end stake penalty enforced by the HEX protocol late penalty calculation.
     * @param lockedDay begin day (inclusive)
     * @param stakedDays Number of days staked
     * @param stakeValue The value of the stake in HEX
     * @return Late penalty
     */
    function calcLatePenalty(
        uint256 lockedDay, 
        uint256 stakedDays,
        uint256 unlockedDay, 
        uint256 stakeValue
    ) 
        public 
        pure 
        returns (uint256) 
    {
        uint256 maxUnlockedDay = lockedDay + stakedDays + LATE_PENALTY_GRACE_DAYS;
        if (unlockedDay <= maxUnlockedDay) return 0;

        return stakeValue * (unlockedDay - maxUnlockedDay) / LATE_PENALTY_SCALE_DAYS;
    }

    /**
     * @dev Calls the HEX function "stakeGoodAccounting" against the HEX stake held within the HSI.
     */
    function stakeGoodAccounting(address hsiAddress)
        external
    {
        IHEXStakeInstance hsi = IHEXStakeInstance(hsiAddress);
        hsi.goodAccounting();
    }
}