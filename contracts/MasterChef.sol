// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// import "hardhat/console.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { SafeERC20 } from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import { Actuator } from "./Actuator.sol"; 
import { HEXTimeTokenManager } from "./HEXTimeTokenManager.sol"; 
import { IPulseXFactory } from "./interfaces/PulseXFactory.sol"; 

// Much of the code in this contract has been copied or adapted from SushiSwap's MasterChef contract.

contract MasterChef {
    using SafeERC20 for IERC20;

    uint256 constant YEAR = 365 days;
    
    address public immutable _hexAddress;
    uint256[3] public farmEmissionSchedule;
    uint256[3] public teamEmissionSchedule;

    address private _teamAddress;
    uint256 private _lastTeamMint;
    uint256 private _lastMassUpdate;

    // Info of each user.
    struct UserInfo {
        uint256 amount;     // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        //
        // We do some fancy math here. Basically, any point in time, the amount of ACTR
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accActrPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accActrPerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken;           // Address of LP token contract.
        uint256 allocPoint;       // How many allocation points assigned to this pool. ACTR to distribute per second.
        uint256 lastRewardTime;  // Last time that ACTR distribution occurs.
        uint256 accActrPerShare; // Accumulated ACTR per share, times 1e12. See below.
    }

    Actuator public actr;

    IPulseXFactory public factory;
    
    HEXTimeTokenManager public _httManager;

    uint256 public constant MaxAllocPoint = 5000;

    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping (uint256 => mapping (address => UserInfo)) public userInfo;
    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // The block time when ACTR mining starts.
    uint256 public immutable startTime;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event CollectEmissions(address indexed user, uint256 amount);

    constructor(
        address hexAddress,
        address teamAddress,
        address _factoryAddress,
        uint256 _startTime,
        uint256[3] memory _farmEmissionSchedule,
        uint256[3] memory _teamEmissionSchedule
    ) {
        _httManager = HEXTimeTokenManager(msg.sender);
        actr = new Actuator(msg.sender);
        startTime = _startTime;
        _lastTeamMint = _startTime;
        farmEmissionSchedule = _farmEmissionSchedule;
        teamEmissionSchedule = _teamEmissionSchedule;
        _teamAddress = teamAddress;
        _hexAddress = hexAddress;
        factory = IPulseXFactory(_factoryAddress);
    }

    /**
     * @dev Retreives the number of farm pools.
     * @return Number of pools.
     */
    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    /**
     * @dev Add a new lp to the pool. 
     * @param _allocPoint The allocation points to assign to the pool.
     * @param _lpToken LP Address of the pool to add.
    */
    function _add(uint256 _allocPoint, IERC20 _lpToken) private {
        require(_allocPoint <= MaxAllocPoint, "A029");

        uint256 lastRewardTime = block.timestamp > startTime ? block.timestamp : startTime;
        totalAllocPoint = totalAllocPoint + _allocPoint;
        poolInfo.push(PoolInfo({
            lpToken: _lpToken,
            allocPoint: _allocPoint,
            lastRewardTime: lastRewardTime,
            accActrPerShare: 0
        }));
    }

    /**
     * @dev Update the given pool's ACTR allocation point. 
     * @param _pid Internal ID of the pool to update.
     * @param _allocPoint Updated allocation points to assign to the pool.
    */
    function _set(uint256 _pid, uint256 _allocPoint) private {
        if (poolInfo[_pid].allocPoint > _allocPoint) {
            require(totalAllocPoint - (poolInfo[_pid].allocPoint - _allocPoint) > 0, "A032");
        }
        require(_allocPoint <= MaxAllocPoint, "A031");

        totalAllocPoint = totalAllocPoint - poolInfo[_pid].allocPoint + _allocPoint;
        poolInfo[_pid].allocPoint = _allocPoint;
    }

    /**
     * @dev Public function to fetch the farm ACTR emission amount within 2 timestamp. 
     * @param _from Start date to calculate emissions from.
     * @param _to End date to calculate emissions to.
     * @return Total ACTR Emissions.
    */
    function getFarmEmissions(uint256 _from, uint256 _to) external view returns (uint256) {
        return _getFarmEmissions(_from, _to);
    }

    /**
     * @dev Private function to fetch the farm ACTR emission amount within 2 timestamps. 
     * @param _from Start date to calculate emissions from.
     * @param _to End date to calculate emissions to.
     * @return Total ACTR Emissions.
    */
    function _getFarmEmissions(uint256 _from, uint256 _to) private view returns (uint256) {
        return _getEmissions(_from, _to, farmEmissionSchedule);
    }

    /**
     * @dev Public function to fetch the team ACTR emission amount within 2 timestamp. 
     * @param _from Start date to calculate emissions from.
     * @param _to End date to calculate emissions to.
     * @return Total ACTR Emissions.
    */
    function getTeamEmissions(uint256 _from, uint256 _to) public view returns (uint256) {
        return _getEmissions(_from, _to, teamEmissionSchedule);
    }

    /**
     * @dev Generic function to fetch the ACTR emission amount within 2 dates based on the provided emission schedule.
     * @param _from Start date to calculate emissions from.
     * @param _to End date to calculate emissions to.
     * @param emissionSchedule Array of yearly ACTR emission amount.
     * @return Total ACTR Emissions.
     * 
    */
    function _getEmissions(uint256 _from, uint256 _to, uint256[3] memory emissionSchedule) private view returns (uint256) {
        uint256 start = _from - startTime;
        uint256 end = _to - startTime;
        return _getEmissionsInTimeframe(start, end, emissionSchedule);
    }

    /**
     * @dev Generic function to fetch the ACTR emission amount within 2 timestamps based on the provided emission schedule 
     * and assuming epoch is farm start.
     * @param start Start time to calculate emissions from.
     * @param end End time to calculate emissions to.
     * @param emissionSchedule Array of yearly ACTR emission amount.
     * @return Total ACTR Emissions.
     * 
    */
    function _getEmissionsInTimeframe(uint256 start, uint256 end, uint256[3] memory emissionSchedule) private pure returns (uint256) {
        uint256 mintAmount = 0;
        for (uint256 year = 0; year < emissionSchedule.length; year++) {
            uint256 yearStart = year * YEAR;
            uint256 yearEnd = (year + 1) * YEAR;
            
            // Check for timeframe overlap
            if (end > yearStart && start < yearEnd) {
                uint256 effectiveStart = start > yearStart ? start : yearStart;
                uint256 effectiveEnd = end < yearEnd ? end : yearEnd;
                uint256 elapsed = effectiveEnd - effectiveStart;
                mintAmount += (emissionSchedule[year] * elapsed) / YEAR;
            }
        }
        
        return mintAmount;
    }

    /**
     * @dev Priveleged function to mint the accrued team allocation since previous mint.
     * @return ACTR amount minted.
     * 
    */
    function mintTeamAllocation() external returns (uint256) {
        require(msg.sender == _teamAddress, "A025");
        
        uint256 currentTeamMint = block.timestamp;
        if (currentTeamMint <= _lastTeamMint) {
            return 0;
        }

        uint256 mintAmount = getTeamEmissions(_lastTeamMint, currentTeamMint);

        _lastTeamMint = currentTeamMint;

        actr.mint(_teamAddress, mintAmount);

        return mintAmount;
    }

    /**
     * @dev View function to see pending ACTR on frontend.
     * @return Pending ACTR amount.
     * 
    */
    function pendingActr(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accActrPerShare = pool.accActrPerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (block.timestamp > pool.lastRewardTime && lpSupply != 0) {
            uint256 totalRewards = _getFarmEmissions(pool.lastRewardTime, block.timestamp);
            uint256 actrReward = totalRewards * pool.allocPoint / totalAllocPoint;
            accActrPerShare = accActrPerShare + (actrReward * 1e12 / lpSupply);
        }
        return (user.amount * accActrPerShare / 1e12) - user.rewardDebt;
    }

    /**
     * @dev Update all pools to the latest predefined allocation points. 
     * 
    */
    function massUpdatePools() external {
        for (uint256 pid = 0; pid < poolInfo.length; ++pid) {
            updatePool(pid);
        }

        if (_lastMassUpdate == 0) {
            address pairAddressHTT3000 = factory.getPair(_hexAddress, _httManager.getOrCreateHEXTimeToken(2999));
            address pairAddressHTT5000 = factory.getPair(_hexAddress, _httManager.getOrCreateHEXTimeToken(4999));
            address pairAddressHTT7000 = factory.getPair(_hexAddress, _httManager.getOrCreateHEXTimeToken(6999));
            require(pairAddressHTT3000 != address(0), "A038");
            require(pairAddressHTT5000 != address(0), "A038");
            require(pairAddressHTT7000 != address(0), "A038");

            _add(1000, IERC20(pairAddressHTT3000));
            _add(2000, IERC20(pairAddressHTT5000));
            _add(5000, IERC20(pairAddressHTT7000));
        } else if (_lastMassUpdate < startTime + YEAR && block.timestamp >= startTime + YEAR) {
            address pairAddressHTT4000 = factory.getPair(_hexAddress, _httManager.getOrCreateHEXTimeToken(3999));
            address pairAddressHTT6000 = factory.getPair(_hexAddress, _httManager.getOrCreateHEXTimeToken(5999));
            require(pairAddressHTT4000 != address(0), "A038");
            require(pairAddressHTT6000 != address(0), "A038");
            _set(0, 1000);
            _set(1, 3000);
            _set(2, 5000);

            _add(2000, IERC20(pairAddressHTT4000));
            _add(4000, IERC20(pairAddressHTT6000));
        } else if (_lastMassUpdate < startTime + (YEAR * 2) && block.timestamp >= startTime + (YEAR * 2)) {
            address pairAddressHTT8000 = factory.getPair(_hexAddress, _httManager.getOrCreateHEXTimeToken(7999));
            require(pairAddressHTT8000 != address(0), "A038");
            _set(0, 0);
            _set(3, 1000);
            _set(1, 2000);
            _set(4, 3000);
            _set(2, 4000);
            
            _add(5000, IERC20(pairAddressHTT8000));
        }

        _lastMassUpdate = block.timestamp;
    }

    /**
     * @dev Update reward variables of the given pool to be up-to-date.
     * @param _pid Internal ID of the pool.
    */
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.timestamp <= pool.lastRewardTime) {
            return;
        }
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0) {
            pool.lastRewardTime = block.timestamp;
            return;
        }
        uint256 totalRewards = _getFarmEmissions(pool.lastRewardTime, block.timestamp);
        uint256 actrReward = totalRewards * pool.allocPoint / totalAllocPoint;

        actr.mint(address(this), actrReward);

        pool.accActrPerShare = pool.accActrPerShare + (actrReward * 1e12 / lpSupply);
        pool.lastRewardTime = block.timestamp;
    }

    /**
     * @dev Deposit LP tokens to MasterChef for ACTR allocation.
     * @param _pid ID of the pool.
     * @param _amount Amount of LP tokens to deposit.
    */
    function deposit(uint256 _pid, uint256 _amount) external {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        updatePool(_pid);

        uint256 pending = (user.amount * pool.accActrPerShare / 1e12) - user.rewardDebt;

        user.amount = user.amount + _amount;
        user.rewardDebt = user.amount * pool.accActrPerShare / 1e12;

        if (pending > 0) {
            safeActrTransfer(msg.sender, pending);
            emit CollectEmissions(msg.sender, pending);
        }
        pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);

        emit Deposit(msg.sender, _pid, _amount);
    }

    /**
     * @dev Withdraw LP tokens from MasterChef.
     * @param _pid ID of the pool.
     * @param _amount Amount of LP tokens to withdraw.
    */
    function withdraw(uint256 _pid, uint256 _amount) external {  
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        require(user.amount >= _amount, "A030");

        updatePool(_pid);

        uint256 pending = (user.amount * pool.accActrPerShare / 1e12) - user.rewardDebt;

        user.amount = user.amount - _amount;
        user.rewardDebt = user.amount * pool.accActrPerShare / 1e12;

        if (pending > 0) {
            safeActrTransfer(msg.sender, pending);
            emit CollectEmissions(msg.sender, pending);
        }
        pool.lpToken.safeTransfer(address(msg.sender), _amount);
        
        emit Withdraw(msg.sender, _pid, _amount);
    }

    /**
     * @dev Collect accumulated ACTR emissions.
     * @param _pid ID of the pool.
    */
    function collectEmissions(uint256 _pid) external returns (uint256) {  
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        require(user.amount > 0, "A044");
        
        updatePool(_pid);

        uint256 pending = (user.amount * pool.accActrPerShare / 1e12) - user.rewardDebt;

        user.rewardDebt = user.amount * pool.accActrPerShare / 1e12;

        if (pending > 0) {
            safeActrTransfer(msg.sender, pending);
            emit CollectEmissions(msg.sender, pending);
        }

        return pending;
    }

    /**
     * @dev Safe ACTR transfer function, just in case if rounding error causes pool to not have enough ACTR.
     * @param _to Recipient address.
     * @param _amount Amount of ACTR tokens to transfer.
    */
    function safeActrTransfer(address _to, uint256 _amount) private {
        uint256 actrBal = actr.balanceOf(address(this));
        if (_amount > actrBal) {
            actr.transfer(_to, actrBal);
        } else {
            actr.transfer(_to, _amount);
        }
    }

    /**
     * @dev Transfers team address to a new account.
     */
    function transferTeamAddress(address newTeamAddress) external {
        require(msg.sender == _teamAddress, "A025");
        _teamAddress = newTeamAddress;
    }
}
