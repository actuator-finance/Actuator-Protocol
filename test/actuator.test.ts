require('dotenv').config();
import 'solidity-coverage';
import {
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";
import { HEXTimeTokenManager } from '../typechain-types/contracts/HEXTimeTokenManager'
import { Actuator } from '../typechain-types/contracts/Actuator'
import { MasterChef } from '../typechain-types/contracts/MasterChef'
import * as Const from "../scripts/constants";
import * as Util from "../scripts/util";
import hre from "hardhat";
import FACTORY_ABI from '../abi/factoryABI.json';
import BASE_TOKEN_ABI from "../abi/baseTokenABI.json"
import ROUTER_ABI from '../abi/routerABI.json';

const SECS_PER_DAY = 86400;

type UnwrapPromise<T> = T extends Promise<infer U> ? U : T;

describe("Actuator Protocol", function () {
  let tx: any
  let httManager: HEXTimeTokenManager;
  let httManagerAddress: string;
  let masterChef: MasterChef;
  let actr: Actuator;
  let hex: any;

  async function exec(trans: any) {
    tx = await trans
    return await tx.wait()
  }

  async function currentDay() {
    const hex = await ethers.getContractAt("IHEX", Const.HEX_ADDRESS);
    return Number(await hex.currentDay());
  }  

  async function matBalance(address: string, maturity: number) {
    const tokenAddr = (await httManager.maturityToInfo(maturity)).tokenAddress
    const tokenContract = await ethers.getContractAt("HEXTimeToken", tokenAddr)
    return await tokenContract.balanceOf(address)
  }  

  async function advanceDays(days: number) {
    await ethers.provider.send("evm_increaseTime", [SECS_PER_DAY * days]);
    await ethers.provider.send("evm_mine"); 
    tx = await httManager.updateDailyData(await currentDay());
    await tx.wait();
  }  

  async function getHTTContract(maturity: bigint) {
    const tokenAddress0 = (await httManager.maturityToInfo(maturity)).tokenAddress
    return await ethers.getContractAt("HEXTimeToken", tokenAddress0)
  }  

  async function init() {
    const [owner1, owner2, owner3, owner4, owner5, owner6, owner7] = await ethers.getSigners();
    
    const Token = await ethers.getContractFactory("HEXTimeTokenManager");

    const currentTime = (await ethers.provider.getBlock('latest')).timestamp + SECS_PER_DAY * 10;

    httManager = await Token.deploy(
      Const.HEX_ADDRESS, 
      Const.HSIM_ADDRESS, 
      Const.HEDRON_ADDRESS, 
      owner1.address, 
      Const.AMM_FACTORY_ADDRESS,
      [0n], 
      // await Util.getPayouts(), 
      currentTime,
      Const.FARM_EMISSION_SCHEDULE,
      Const.TEAM_EMISSION_SCHEDULE,  
      Const.POOL_POINT_SCHEDULE,
    );
    httManagerAddress = await httManager.getAddress()

    const actuatorAddress = await httManager.actuatorAddress()
    actr = await ethers.getContractAt("Actuator", actuatorAddress);

    const masterChefAddress = await httManager.masterChefAddress();
    masterChef = await ethers.getContractAt("MasterChef", masterChefAddress);

    const hsim = await ethers.getContractAt("IHEXStakeInstanceManager", Const.HSIM_ADDRESS);
    await exec(hsim.connect(owner1).setApprovalForAll(httManagerAddress, true))
    await exec(hsim.connect(owner2).setApprovalForAll(httManagerAddress, true))
    await exec(hsim.connect(owner3).setApprovalForAll(httManagerAddress, true))
    await exec(hsim.connect(owner4).setApprovalForAll(httManagerAddress, true))
    await exec(hsim.connect(owner5).setApprovalForAll(httManagerAddress, true))
    await exec(hsim.connect(owner6).setApprovalForAll(httManagerAddress, true))
    await exec(hsim.connect(owner7).setApprovalForAll(httManagerAddress, true))

    hex = await ethers.getContractAt("IHEX", Const.HEX_ADDRESS);
    await hre.network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [Const.HEX_HOLDER],
    });

    const hexHolderSigner = await ethers.getSigner(Const.HEX_HOLDER);
    await exec(hex.connect(hexHolderSigner).transfer(owner1.address, 100000000000000n))
    await exec(hex.connect(hexHolderSigner).transfer(owner2.address, 100000000000000n))
    await exec(hex.connect(hexHolderSigner).transfer(owner3.address, 100000000000000n))
    await exec(hex.connect(hexHolderSigner).transfer(owner4.address, 100000000000000n))
    await exec(hex.connect(hexHolderSigner).transfer(owner5.address, 100000000000000n))
    await exec(hex.connect(hexHolderSigner).transfer(owner6.address, 100000000000000n))
    await exec(hex.connect(hexHolderSigner).transfer(owner7.address, 100000000000000n))

    await exec(hex.connect(owner1).approve(httManagerAddress, 100000000000000n))
    await exec(hex.connect(owner2).approve(httManagerAddress, 100000000000000n))
    await exec(hex.connect(owner3).approve(httManagerAddress, 100000000000000n))
    await exec(hex.connect(owner4).approve(httManagerAddress, 100000000000000n))
    await exec(hex.connect(owner5).approve(httManagerAddress, 100000000000000n))
    await exec(hex.connect(owner6).approve(httManagerAddress, 100000000000000n))
    await exec(hex.connect(owner7).approve(httManagerAddress, 100000000000000n))
    await exec(hex.connect(owner1).approve(Const.HSIM_ADDRESS, 100000000000000n))

    return { owner1, owner2, owner3, hsim, owners: [owner1, owner2, owner3, owner4, owner5, owner6, owner7] };
  }

  type Props = UnwrapPromise<ReturnType<typeof init>>;

  const setup = async () => await loadFixture(init);

  async function createStakes(props: Props, stakedDays = 100, stakedHearts = 1000000n) {
    const lockedDay = (await currentDay()) + 1
    const endDay = lockedDay + stakedDays
    await exec(httManager.connect(props.owner1).hexStakeStart(stakedHearts, stakedDays))
    await exec(httManager.connect(props.owner2).hexStakeStart(stakedHearts, stakedDays))
    const hsiAddress1 = await httManager.hsiLists(props.owner1.address, 0)
    const hsiAddress2 = await httManager.hsiLists(props.owner2.address, 0)
    const share = await httManager.shareLists(props.owner1.address, 0)
    return {hsiAddress1, hsiAddress2, stakedHearts, endDay, stakeShares: share.stakeShares, lockedDay, stakedDays}
  }

  async function createHSI(props: Props, amount: bigint) {
    await exec(props.hsim.connect(props.owner1).hexStakeStart(amount, 10))
    const hsiAddress = await props.hsim.hsiLists(props.owner1.address, 0);
    await exec(props.hsim.hexStakeTokenize(0, hsiAddress));
    return hsiAddress
  }

  it("Lifecycle", async function () {
    const props = await setup();
    const {hsiAddress1, stakedHearts, endDay, lockedDay, stakeShares, stakedDays} =  await createStakes(props, 100)
    await exec(httManager.connect(props.owner1).mintHEXTimeTokens(0, stakedHearts, endDay))

    await advanceDays(stakedDays / 2)
    const day = await currentDay()
    const rewards = await httManager.calculateRewards(lockedDay, day, stakeShares);
    await exec(httManager.connect(props.owner1).mintHEXTimeTokens(0, rewards, endDay))

    const balance = await matBalance(props.owner1.address, endDay)
    const retireAmount = balance / 2n
    await exec(httManager.connect(props.owner1).retireHEXTimeTokens(0n, 0n, retireAmount))
    let balancePost = await matBalance(props.owner1.address, endDay)
    expect(balancePost).to.equal(balance - retireAmount);

    await advanceDays(endDay - (await currentDay()))
    const preHexBalance = await hex.balanceOf(props.owner1.address)
    const hedronHsiIndex = await httManager.findHedronHSIIndex(hsiAddress1)
    tx = await httManager.connect(props.owner1).endCollateralizedHEXStake(hsiAddress1, 0, 0, hedronHsiIndex);
    await tx.wait();
    const postHexBalance = await hex.balanceOf(props.owner1.address)
    expect(postHexBalance).to.be.greaterThan(preHexBalance);

    const balancePre = await matBalance(props.owner1.address, endDay)
    await exec(httManager.connect(props.owner1).redeemHEXTimeTokens(endDay, balancePre))
    balancePost = await matBalance(props.owner1.address, endDay)
    expect(balancePost).to.be.equal(0n);
  })

  it("Late End Stake", async function () {
    const props = await setup();
    const {hsiAddress1, stakedHearts, endDay, lockedDay, stakeShares, stakedDays} =  await createStakes(props, 100)
    await advanceDays(100)
    const reserveDay = await httManager.getReserveDay(lockedDay, stakedDays, endDay);
    const rewards = await httManager.calculateRewards(lockedDay, reserveDay, stakeShares);
    const mintedAmount = stakedHearts + rewards
    const maturity = endDay
    await httManager.connect(props.owner1).mintHEXTimeTokens(0, mintedAmount, maturity);

    const tokenAddress = (await httManager.maturityToInfo(maturity)).tokenAddress
    const token = await ethers.getContractAt("HEXTimeToken", tokenAddress);
    await token.connect(props.owner1).transfer(props.owner2.address, mintedAmount);

    await advanceDays(14)
    const curDay = await currentDay()

    const preBalance = await hex.balanceOf(props.owner2.address)
    await httManager.connect(props.owner2).endHEXStakesAndRedeem(maturity, mintedAmount, [[hsiAddress1, 0, 0, 0]] as any);
    const postBalance = await hex.balanceOf(props.owner2.address)
    const latePayout = await httManager.calcEndStakeSubsidy(lockedDay, stakedDays, maturity, curDay, stakeShares)
    expect(latePayout).to.be.greaterThan(0n);
    expect(postBalance - preBalance).to.be.equal(mintedAmount + latePayout);
  });

  it("Multiple End Stake", async function () {
    const props = await setup();
    const {hsiAddress1, hsiAddress2, stakedHearts, endDay, stakeShares, stakedDays} =  await createStakes(props, 10)
    const maturity = endDay
    await httManager.connect(props.owner1).mintHEXTimeTokens(0, stakedHearts, maturity);
    await httManager.connect(props.owner2).mintHEXTimeTokens(0, stakedHearts, maturity);

    const tokenAddress = (await httManager.maturityToInfo(maturity)).tokenAddress
    const token = await ethers.getContractAt("HEXTimeToken", tokenAddress);
    await token.connect(props.owner1).transfer(props.owner2.address, stakedHearts);

    await advanceDays(stakedDays + 1)

    await httManager.connect(props.owner2).endHEXStakesAndRedeem(maturity, stakedHearts*2n, [[hsiAddress1, 0, 0, 0], [hsiAddress2, 0, 0, 0]] as any);
  });
    
  it("Overly Late End Stake", async function () {
    const props = await setup();
    const {hsiAddress1, stakedHearts, endDay, stakeShares, stakedDays} =  await createStakes(props, 10)
    const maturity = endDay
    await httManager.connect(props.owner1).mintHEXTimeTokens(0, stakedHearts, maturity);

    const tokenAddress = (await httManager.maturityToInfo(maturity)).tokenAddress
    const token = await ethers.getContractAt("HEXTimeToken", tokenAddress);
    await token.connect(props.owner1).transfer(props.owner2.address, stakedHearts);

    await advanceDays(stakedDays + 200)

    await httManager.connect(props.owner2).endCollateralizedHEXStake(hsiAddress1, 0, 0, 0);
  });
    
  describe("Maturity <> End Stake Day", async function () {
    let props: UnwrapPromise<ReturnType<typeof setup>>
    beforeEach(async function () {
      props = await setup()
    })
    
    it("Lifecycle", async function () {
      const {stakedHearts, endDay, lockedDay, stakeShares, stakedDays} =  await createStakes(props, 100)
      await advanceDays(50)
      const curDay = await currentDay()
      const rewards = await httManager.calculateRewards(lockedDay, curDay, stakeShares);
      let amount = stakedHearts + rewards
      await expect(httManager.connect(props.owner1).mintHEXTimeTokens(0, amount, endDay + 1)).to.be.revertedWith('A002');
      const dayDiff = 400
      amount = stakedHearts * (700n - BigInt(dayDiff))/700n
      await httManager.connect(props.owner1).mintHEXTimeTokens(0, amount, endDay + dayDiff);
    });

    it("Late End Stake", async function () {
      const {hsiAddress1, stakedHearts, endDay, lockedDay, stakeShares, stakedDays} =  await createStakes(props, 100)
      await advanceDays(100)
      const maturityDiff = 100
      const reserveDay = await httManager.getReserveDay(lockedDay, stakedDays, endDay + maturityDiff);
      let rewards = await httManager.calculateRewards(lockedDay, reserveDay, stakeShares);
      let mintedAmount = (stakedHearts + rewards) * (700n - BigInt(maturityDiff))/700n
      const maturity = endDay + maturityDiff
      await httManager.connect(props.owner1).mintHEXTimeTokens(0, mintedAmount, maturity);

      const tokenAddress = (await httManager.maturityToInfo(maturity)).tokenAddress
      const token = await ethers.getContractAt("HEXTimeToken", tokenAddress);
      await token.connect(props.owner1).transfer(props.owner2.address, mintedAmount);
      const balanceTemp = await token.balanceOf(props.owner2.address)

      await advanceDays(maturityDiff+12)
      const curDay = await currentDay()
      rewards = await httManager.calculateRewards(lockedDay, lockedDay + stakedDays, stakeShares);

      const preBalance = await hex.balanceOf(props.owner2.address)
      await httManager.connect(props.owner2).endHEXStakesAndRedeem(maturity, mintedAmount, [[hsiAddress1, 0, 0, 0]] as any);
      const postBalance = await hex.balanceOf(props.owner2.address)
      const latePayout = await httManager.calcEndStakeSubsidy(lockedDay, stakedDays, maturity, curDay, stakeShares)
      expect(postBalance - preBalance).to.be.equal(mintedAmount + latePayout);
    });

  })
  
  describe("Delegation", async function () {
    let props: UnwrapPromise<ReturnType<typeof init>>
    let hsiAddress: string
    let stakedHearts = 1000000n
    before(async function () {
      props = await setup();
      hsiAddress = await createHSI(props, stakedHearts)
    })

    it("Delegate HSI", async function () {
      const tokenId = await props.hsim.tokenOfOwnerByIndex(props.owner1.address, 0);

      await exec(httManager.connect(props.owner1).delegateHSI(tokenId));

      const endCount = await httManager.hsiCount(props.owner1)
      expect(endCount).to.equal(1);
    });

    it("Mint against Delegated HSI", async function () {
      const resp = await httManager.shareLists(props.owner1.address, 0);
      const lockedDay = resp[3]
      const stakedDays = resp[4]
      const endDay = lockedDay + stakedDays
      const maturity = endDay
  
      await httManager.connect(props.owner1).mintHEXTimeTokens(0, stakedHearts, maturity)
    });

    it("Revoke HSI Delegation ", async function () {
      const hedronHsiIndex = await httManager.findHedronHSIIndex(hsiAddress)
      await expect(httManager.connect(props.owner1).revokeHSIDelegation(0, hedronHsiIndex)).to.be.revertedWith('A000');

      await exec(httManager.connect(props.owner1).retireHEXTimeTokens(0n, 0n, stakedHearts))

      await httManager.connect(props.owner1).revokeHSIDelegation(0, hedronHsiIndex);

      const stakeCount = await httManager.hsiCount(props.owner1.address)
      expect(stakeCount).to.equal(0);
    });
  });

  it("Liquidity Mining", async function () {
    const props = await setup();
    let day = Number(await hex.currentDay())
    // console.log('day: ', day);
    const stakedDays0 = 2998 - day 
    const stakedDays1 = 2998 - day 
    const stakedDays2 = 3998 - day 
    const stakedDays3 = 4998 - day 
    const stakedDays4 = 5998 - day 
    const stakedDays5 = 6998 - day 
    await httManager.connect(props.owners[0]).hexStakeStart(10000000n, stakedDays0)
    await httManager.connect(props.owners[1]).hexStakeStart(10000000n, stakedDays1)
    await httManager.connect(props.owners[2]).hexStakeStart(10000000n, stakedDays2)
    await httManager.connect(props.owners[3]).hexStakeStart(10000000n, stakedDays3)
    await httManager.connect(props.owners[4]).hexStakeStart(10000000n, stakedDays4)
    await httManager.connect(props.owners[5]).hexStakeStart(10000000n, stakedDays5)

    await httManager.connect(props.owners[0]).mintHEXTimeTokens(0, 10000000n, day + stakedDays0 + 1)
    await httManager.connect(props.owners[1]).mintHEXTimeTokens(0, 10000000n, day + stakedDays1 + 1)
    await httManager.connect(props.owners[2]).mintHEXTimeTokens(0, 10000000n, day + stakedDays2 + 1)
    await httManager.connect(props.owners[3]).mintHEXTimeTokens(0, 10000000n, day + stakedDays3 + 1)
    await httManager.connect(props.owners[4]).mintHEXTimeTokens(0, 10000000n, day + stakedDays4 + 1)
    await httManager.connect(props.owners[5]).mintHEXTimeTokens(0, 10000000n, day + stakedDays5 + 1)
    
    // get maturity token info
    const tokens = [
      await getHTTContract(BigInt(day + stakedDays0 + 1)),
      await getHTTContract(BigInt(day + stakedDays1 + 1)),
      await getHTTContract(BigInt(day + stakedDays2 + 1)),
      await getHTTContract(BigInt(day + stakedDays3 + 1)),
      await getHTTContract(BigInt(day + stakedDays4 + 1)),
      await getHTTContract(BigInt(day + stakedDays5 + 1)),
    ]

    // approve token transfers
    await tokens[0].connect(props.owners[0]).approve(Const.ROUTER_ADDRESS, 100000000000000n)
    await hex.connect(props.owners[0]).approve(Const.ROUTER_ADDRESS, 100000000000000n)
    await tokens[1].connect(props.owners[1]).approve(Const.ROUTER_ADDRESS, 100000000000000n)
    await hex.connect(props.owners[1]).approve(Const.ROUTER_ADDRESS, 100000000000000n)
    await tokens[2].connect(props.owners[2]).approve(Const.ROUTER_ADDRESS, 100000000000000n)
    await hex.connect(props.owners[2]).approve(Const.ROUTER_ADDRESS, 100000000000000n)
    await tokens[3].connect(props.owners[3]).approve(Const.ROUTER_ADDRESS, 100000000000000n)
    await hex.connect(props.owners[3]).approve(Const.ROUTER_ADDRESS, 100000000000000n)
    await tokens[4].connect(props.owners[4]).approve(Const.ROUTER_ADDRESS, 100000000000000n)
    await hex.connect(props.owners[4]).approve(Const.ROUTER_ADDRESS, 100000000000000n)
    await tokens[5].connect(props.owners[5]).approve(Const.ROUTER_ADDRESS, 100000000000000n)
    await hex.connect(props.owners[5]).approve(Const.ROUTER_ADDRESS, 100000000000000n)
    
    // add liquidity
    const routerContract = new ethers.Contract(Const.ROUTER_ADDRESS, ROUTER_ABI) as any
    await routerContract.connect(props.owners[0]).addLiquidity(
      await tokens[0].getAddress(), 
      Const.HEX_ADDRESS, 
      1000000n, 
      100000n, 
      0n, 0n, 
      props.owners[0].address, 
      99999999999n
    )
    await routerContract.connect(props.owners[1]).addLiquidity(
      await tokens[1].getAddress(), 
      Const.HEX_ADDRESS, 
      1000000n, 
      100000n, 
      0n, 0n, 
      props.owners[1].address, 
      99999999999n
    )
    await routerContract.connect(props.owners[2]).addLiquidity(
      await tokens[2].getAddress(), 
      Const.HEX_ADDRESS, 
      1000000n / 2n, 
      100000n / 2n, 
      0n, 0n, 
      props.owners[2].address, 
      99999999999n
    )
    await routerContract.connect(props.owners[3]).addLiquidity(
      await tokens[3].getAddress(), 
      Const.HEX_ADDRESS, 
      1000000n, 
      100000n, 
      0n, 0n, 
      props.owners[3].address, 
      99999999999n
    )
    await routerContract.connect(props.owners[4]).addLiquidity(
      await tokens[4].getAddress(), 
      Const.HEX_ADDRESS, 
      1000000n, 
      100000n, 
      0n, 0n, 
      props.owners[4].address, 
      99999999999n
    )
    await routerContract.connect(props.owners[5]).addLiquidity(
      await tokens[5].getAddress(), 
      Const.HEX_ADDRESS, 
      1000000n / 2n, 
      100000n / 2n, 
      0n, 0n, 
      props.owners[5].address, 
      99999999999n
    )


    let pairFactory = new ethers.Contract(Const.AMM_FACTORY_ADDRESS, FACTORY_ABI, props.owners[0].provider) as any
    let pairAddress = await pairFactory.connect(props.owners[0]).getPair(await tokens[0].getAddress(), Const.HEX_ADDRESS)
    const lpToken0 = new ethers.Contract(pairAddress, BASE_TOKEN_ABI, props.owners[0].provider) as any;
    pairFactory = new ethers.Contract(Const.AMM_FACTORY_ADDRESS, FACTORY_ABI, props.owners[1].provider) as any
    pairAddress = await pairFactory.connect(props.owners[1]).getPair(await tokens[1].getAddress(), Const.HEX_ADDRESS)
    const lpToken1 = new ethers.Contract(pairAddress, BASE_TOKEN_ABI, props.owners[1].provider) as any;
    pairFactory = new ethers.Contract(Const.AMM_FACTORY_ADDRESS, FACTORY_ABI, props.owners[2].provider) as any
    pairAddress = await pairFactory.connect(props.owners[2]).getPair(await tokens[2].getAddress(), Const.HEX_ADDRESS)
    const lpToken2 = new ethers.Contract(pairAddress, BASE_TOKEN_ABI, props.owners[2].provider) as any;
    pairFactory = new ethers.Contract(Const.AMM_FACTORY_ADDRESS, FACTORY_ABI, props.owners[3].provider) as any
    pairAddress = await pairFactory.connect(props.owners[3]).getPair(await tokens[3].getAddress(), Const.HEX_ADDRESS)
    const lpToken3 = new ethers.Contract(pairAddress, BASE_TOKEN_ABI, props.owners[3].provider) as any;
    pairFactory = new ethers.Contract(Const.AMM_FACTORY_ADDRESS, FACTORY_ABI, props.owners[4].provider) as any
    pairAddress = await pairFactory.connect(props.owners[4]).getPair(await tokens[4].getAddress(), Const.HEX_ADDRESS)
    const lpToken4 = new ethers.Contract(pairAddress, BASE_TOKEN_ABI, props.owners[4].provider) as any;
    pairFactory = new ethers.Contract(Const.AMM_FACTORY_ADDRESS, FACTORY_ABI, props.owners[5].provider) as any
    pairAddress = await pairFactory.connect(props.owners[5]).getPair(await tokens[5].getAddress(), Const.HEX_ADDRESS)
    const lpToken5 = new ethers.Contract(pairAddress, BASE_TOKEN_ABI, props.owners[5].provider) as any;

    await advanceDays(10)
    await masterChef.massUpdatePools()

    // owner 0 deposit
    const liquidity0 = await lpToken0.balanceOf(props.owners[0])
    await lpToken0.connect(props.owners[0]).approve(await masterChef.getAddress(), liquidity0)
    await masterChef.connect(props.owners[0]).deposit(0, liquidity0)

    // .5 yrs
    await advanceDays(182.5)
    
    // owner 1 deposit
    const liquidity1 = await lpToken1.balanceOf(props.owners[1])
    await lpToken1.connect(props.owners[1]).approve(await masterChef.getAddress(), liquidity1)
    await masterChef.connect(props.owners[1]).deposit(0, liquidity1)
    
    // owner 3 deposit
    const liquidity3 = await lpToken3.balanceOf(props.owners[3])
    await lpToken3.connect(props.owners[3]).approve(await masterChef.getAddress(), liquidity3)
    await masterChef.connect(props.owners[3]).deposit(1, liquidity3)
    
    // 1 yrs
    await advanceDays(182.5)
    await masterChef.massUpdatePools()

    // owner 2 deposit
    const liquidity2 = await lpToken2.balanceOf(props.owners[2])
    await lpToken2.connect(props.owners[2]).approve(await masterChef.getAddress(), liquidity2)
    await masterChef.connect(props.owners[2]).deposit(3, liquidity2)
    
    
    // owner 5 deposit
    const liquidity5 = await lpToken5.balanceOf(props.owners[5])
    await lpToken5.connect(props.owners[5]).approve(await masterChef.getAddress(), liquidity5)
    await masterChef.connect(props.owners[5]).deposit(2, liquidity5)
    
    // await masterChef.connect(props.owners[0]).add(2000, pairAddress) ============
    
    // 1.5 yrs
    await advanceDays(182.5)
    
    // owner 4 deposit
    const liquidity4 = await lpToken4.balanceOf(props.owners[4])
    await lpToken4.connect(props.owners[4]).approve(await masterChef.getAddress(), liquidity4)
    await masterChef.connect(props.owners[4]).deposit(4, liquidity4)
    
    // 2 yrs
    await advanceDays(182.5)
    await advanceDays(100) // need to ensure final farm token maturity is reachable within 5555 stake
    
    day = Number(await hex.currentDay())
    const stakedDays6 = 7998 - day 
    await httManager.connect(props.owners[6]).hexStakeStart(10000000n, stakedDays6)
    
    await httManager.connect(props.owners[6]).mintHEXTimeTokens(0, 10000000n, day + stakedDays6 + 1)
    tokens.push(await getHTTContract(BigInt(day + stakedDays6 + 1)))
    await tokens[6].connect(props.owners[6]).approve(Const.ROUTER_ADDRESS, 100000000000000n)
    await hex.connect(props.owners[6]).approve(Const.ROUTER_ADDRESS, 100000000000000n)
    await routerContract.connect(props.owners[6]).addLiquidity(
      await tokens[6].getAddress(), 
      Const.HEX_ADDRESS, 
      1000000n / 2n, 
      100000n / 2n, 
      0n, 0n, 
      props.owners[6].address, 
      99999999999n
    )
    pairFactory = new ethers.Contract(Const.AMM_FACTORY_ADDRESS, FACTORY_ABI, props.owners[6].provider) as any
    pairAddress = await pairFactory.connect(props.owners[6]).getPair(await tokens[6].getAddress(), Const.HEX_ADDRESS)
    const lpToken6 = new ethers.Contract(pairAddress, BASE_TOKEN_ABI, props.owners[6].provider) as any;
    
    // owner 6 deposit
    const liquidity6 = await lpToken6.balanceOf(props.owners[6])
    await lpToken6.connect(props.owners[6]).approve(await masterChef.getAddress(), liquidity6)
    await masterChef.massUpdatePools()
    await masterChef.connect(props.owners[6]).deposit(5, liquidity6)
    
    // 2.5 yrs
    await advanceDays(182.5)

    const pendingActr = await masterChef.pendingActr(0, props.owners[0])
    await masterChef.connect(props.owners[0]).withdraw(0, 0) // collect emissions
    await masterChef.connect(props.owners[0]).withdraw(0, liquidity0)
    const balance = await actr.balanceOf(props.owners[0])
    expect(pendingActr).to.be.equal(balance);
    
    // 3 yrs
    await advanceDays(182.5)
    
    await masterChef.connect(props.owners[1]).withdraw(0, liquidity1)
    await masterChef.connect(props.owners[2]).withdraw(3, liquidity2)
    await masterChef.connect(props.owners[3]).withdraw(1, liquidity3)
    await masterChef.connect(props.owners[4]).withdraw(4, liquidity4)
    await masterChef.connect(props.owners[5]).withdraw(2, liquidity5)
    await masterChef.connect(props.owners[6]).withdraw(5, liquidity6)
  });

  it("Mint Team Allocation", async function () {
    const props = await setup();
    await masterChef.connect(props.owners[0]).mintTeamAllocation();
    const bal = await actr.balanceOf(props.owners[0].address)
    expect(bal).to.be.equal(0n);

    await advanceDays(400)
    await masterChef.connect(props.owners[0]).mintTeamAllocation();

    await advanceDays(400)
    await masterChef.connect(props.owners[0]).transferTeamAddress(props.owners[1]);
    tx = masterChef.connect(props.owners[0]).mintTeamAllocation();
    await expect(tx).to.be.revertedWith('A025')
    await masterChef.connect(props.owners[1]).mintTeamAllocation();    

    await advanceDays(400)
    await masterChef.connect(props.owners[1]).mintTeamAllocation();
  });

  it("ACTR Emissions", async function () {
    await setup();
    const startTime = await masterChef.startTime();
    let value = await masterChef.getFarmEmissions(
      startTime, 
      startTime + (86400n * 365n * 4n)
    )    
    const totalFarmEmissions = Const.FARM_EMISSION_SCHEDULE.reduce((a, b) => a + b, 0n)
    expect(value).to.be.equal(totalFarmEmissions);

    value = await masterChef.getTeamEmissions(
      startTime, 
      startTime + (86400n * 365n * 4n)
    )    
    const totalTeamEmissions = Const.TEAM_EMISSION_SCHEDULE.reduce((a, b) => a + b, 0n)
    expect(value).to.be.equal(totalTeamEmissions);
  });

  it("Actuator Staking", async function () {
    const props = await setup();
    await httManager.connect(props.owners[0]).hexStakeStart(10000000n, 100n)
    await httManager.connect(props.owners[1]).hexStakeStart(10000000n, 100n)
    await httManager.connect(props.owners[2]).hexStakeStart(10000000n, 100n)
    let shares = await getUpdatedShares(props)

    const maturity0 = shares[0].lockedDay + shares[0].stakedDays
    const maturity1 = shares[0].lockedDay + shares[0].stakedDays + 100n
    await httManager.connect(props.owners[0]).mintHEXTimeTokens(0, shares[0].stakeShares / 2n, maturity0);
    await httManager.connect(props.owners[1]).mintHEXTimeTokens(0, shares[1].stakeShares / 2n, maturity1);

    await advanceDays(100)
    let tx = masterChef.connect(props.owners[1]).mintTeamAllocation();
    await expect(tx).to.be.revertedWith('A025');

    await masterChef.connect(props.owners[0]).mintTeamAllocation()
    await actr.connect(props.owners[0]).transfer(props.owners[1], 10000000000000n)
    await actr.connect(props.owners[0]).transfer(props.owners[2], 50000000000000n)

    await actr.connect(props.owners[0]).deposit(maturity1, 800n);
    tx = actr.connect(props.owners[0]).deposit(maturity1, 200n);
    await expect(tx).to.be.revertedWith('A034');
    await actr.connect(props.owners[0]).increaseDeposit(0, 200n);

    const depositMultiple = 5n
    const deposit1 = 10000000000000n
    const deposit2 = deposit1 * depositMultiple
    await actr.connect(props.owners[1]).deposit(maturity0, deposit1);
    await actr.connect(props.owners[2]).deposit(maturity0, deposit2);
    
    // trigger fees
    await httManager.connect(props.owners[0]).mintHEXTimeTokens(0, shares[0].stakeShares / 3n, maturity0);

    // deposit after HTT creation and thus miss out on fees
    await actr.connect(props.owners[0]).deposit(maturity0, 1000n);
    await actr.connect(props.owners[0]).withdraw(0, 1000n);

    const htt0 = await getHTTContract(BigInt(maturity0))
    await htt0.connect(props.owners[1]).collectFees();

    await advanceDays(20)
    await actr.connect(props.owners[1]).withdraw(0, deposit1);
    await advanceDays(70)
    await actr.connect(props.owners[2]).withdraw(0, deposit2);
    const balance1 = await htt0.balanceOf(props.owners[1].address)
    const balance2 = await htt0.balanceOf(props.owners[2].address)

    // ensure proportional rewards from fees
    expect(balance1 * depositMultiple).to.be.equal(balance2);

    await actr.connect(props.owners[0]).withdraw(0, 1000n);
  });

  it("endHEXStake", async function () {
    const props = await setup();
    const {hsiAddress1, stakedDays, stakedHearts, endDay: maturity} =  await createStakes(props, 10)
    await advanceDays(stakedDays + 1)
    await httManager.connect(props.owner1).endHEXStake(0, 0);
  });

  it("Min Stake Size", async function () {
    const props = await setup();
    const {hsiAddress1, endDay} =  await createStakes(props, 1, 4n)
    await httManager.connect(props.owner1).mintHEXTimeTokens(0, 1n, endDay + 629);
    await advanceDays(629)
    const hedronHsiIndex = await httManager.findHedronHSIIndex(hsiAddress1)
    await httManager.connect(props.owner1).endCollateralizedHEXStake(hsiAddress1, 0, 0, hedronHsiIndex);
  });

  it("End fully served collateralized stake before maturity", async function () {
    const props = await setup();
    const {hsiAddress1, stakedDays, stakedHearts, endDay} =  await createStakes(props)
    await httManager.connect(props.owner1).mintHEXTimeTokens(0, stakedHearts / 2n, endDay + 10);
    await advanceDays(stakedDays + 1)
    const hedronHsiIndex = await httManager.findHedronHSIIndex(hsiAddress1)
    await httManager.connect(props.owner1).endCollateralizedHEXStake(hsiAddress1, 0, 0, hedronHsiIndex);
  });

  it("revert updateDailyData", async function () {
    const props = await setup();
    await expect(httManager.connect(props.owner1).updateDailyData(10000)).to.be.revertedWith('HEX: beforeDay cannot be in the future');
  });

  it("Mint Hedron", async function () {
    const props = await setup();
    const {stakedDays} =  await createStakes(props)
    await advanceDays(stakedDays)
    await httManager.mintInstanced(0, 0)
  });

  it("Good Accounting", async function () {
    const props = await setup();
    const {hsiAddress1, stakedDays, stakedHearts, endDay} =  await createStakes(props)
    await httManager.connect(props.owner1).mintHEXTimeTokens(0, stakedHearts, endDay);
    await advanceDays(stakedDays + 1)
    await httManager.stakeGoodAccounting(hsiAddress1)
    await advanceDays(100)
    // ensure all minted tokens are redeemable after goodAccounting
    await httManager.connect(props.owner1).endHEXStakesAndRedeem(endDay, stakedHearts, [[hsiAddress1, 0, 0, 0]] as any);
  });

  it("external functions", async function () {
    const props = await setup();
    const {hsiAddress1, stakedHearts, endDay: maturity} =  await createStakes(props, 100)
    await httManager.connect(props.owner1).mintHEXTimeTokens(0, stakedHearts, maturity);
    await httManager.findHSIIndex(hsiAddress1);
    await httManager.findHedronHSIIndex(hsiAddress1);
    await httManager.dailyDataRange(800, 1500);
    await httManager.hsiListRange(maturity, 0, 1);
    await httManager.hsiDataListRange(maturity, 0, 1);
    await httManager.stakeLists(props.owner1, 0);
  });

  const getUpdatedShares = async (props: Awaited<ReturnType<typeof setup>>) => {
    let shares: Awaited<ReturnType<typeof httManager.shareLists>>[] = []
    shares[0] = await httManager.shareLists(props.owners[0].address, 0)
    shares[1] = await httManager.shareLists(props.owners[1].address, 0)
    shares[2] = await httManager.shareLists(props.owners[2].address, 0)
    return shares
  }

  it("Sanity checks", async function () {
    const props = await setup();
    const stakedDays = 100n
    const day = await hex.currentDay();
    const endStake = day + stakedDays + 1n
    await httManager.connect(props.owners[0]).hexStakeStart(10000000n, stakedDays)
    await httManager.connect(props.owners[1]).hexStakeStart(10000000n, stakedDays)
    await httManager.connect(props.owners[2]).hexStakeStart(10000000n, stakedDays)

    let shares = await getUpdatedShares(props)

    await httManager.connect(props.owners[0]).mintHEXTimeTokens(0, shares[0].stakedHearts, endStake)
    await httManager.connect(props.owners[1]).mintHEXTimeTokens(0, shares[1].stakedHearts, endStake)
    await httManager.connect(props.owners[2]).mintHEXTimeTokens(0, shares[2].stakedHearts / 2n, endStake + 100n)

    shares = await getUpdatedShares(props)
    
    // hsiAddress and collateral index must match
    let tx = httManager.connect(props.owners[0]).retireHEXTimeTokens(0, 1, shares[0].stakedHearts)
    await expect(tx).to.be.revertedWith('A006');
        
    // ensure proper pruning
    await httManager.connect(props.owners[0]).retireHEXTimeTokens(0, 0, shares[0].stakedHearts / 2n)
    await httManager.connect(props.owners[0]).retireHEXTimeTokens(0, 0, shares[0].stakedHearts / 2n)
    await httManager.connect(props.owners[1]).retireHEXTimeTokens(0, 0, shares[1].stakedHearts)
    await httManager.connect(props.owners[2]).retireHEXTimeTokens(0, 0, shares[2].stakedHearts / 2n)

    // can't mint on an out of range hsiIndex
    tx = httManager.connect(props.owners[1]).mintHEXTimeTokens(1, shares[1].stakedHearts, endStake)
    await expect(tx).to.be.revertedWith('A012');

    // can't mint 0 tokens
    tx = httManager.connect(props.owners[1]).mintHEXTimeTokens(0, 0, endStake + 200n)
    await expect(tx).to.be.revertedWith('A023');

    // HTT redemption day can't be before end stake
    tx = httManager.connect(props.owners[1]).mintHEXTimeTokens(0, 10n, endStake - 1n)
    await expect(tx).to.be.revertedWith('A015');
    
    // can't mint tokens more than 629 days after end stake
    tx = httManager.connect(props.owners[1]).mintHEXTimeTokens(0, 10n, endStake + 630n)
    await expect(tx).to.be.revertedWith('A017');
    
    // hsiIndex and hedronHsiIndex must correspond to same hsiAddress
    tx = httManager.connect(props.owners[0]).revokeHSIDelegation(0, 1)
    await expect(tx).to.be.revertedWith('HSIM: HSI index address mismatch');

    await httManager.connect(props.owners[0]).mintHEXTimeTokens(0, shares[1].stakedHearts, endStake)
    await httManager.connect(props.owners[1]).mintHEXTimeTokens(0, shares[1].stakedHearts / 2n, endStake + 200n)

    shares = await getUpdatedShares(props)
    
    // (50% of the stake is served)
    await advanceDays(Number(stakedDays / 2n))
    let extractable = await httManager.getExtractableAmount(shares[0].hsiAddress, shares[0].maturity)
    await httManager.connect(props.owners[0]).mintHEXTimeTokens(0, extractable - shares[0].collateralAmount, endStake)

    shares = await getUpdatedShares(props)

    // (1 day until fully served)
    await advanceDays(Number(stakedDays / 2n))
    extractable = await httManager.getExtractableAmount(shares[0].hsiAddress, shares[0].maturity)
    await httManager.connect(props.owners[0]).mintHEXTimeTokens(0, extractable - shares[0].collateralAmount, endStake)

    shares = await getUpdatedShares(props)

    // (fully served)
    await advanceDays(Number(1n))

    // cannot revoke an HSI that has outstanding HTT
    tx = httManager.connect(props.owners[1]).revokeHSIDelegation(0, 0)
    await expect(tx).to.be.revertedWith('A000');

    // cannot have multiple outstanding HTT with distinct maturities 
    tx = httManager.connect(props.owners[1]).mintHEXTimeTokens(0, 10n, endStake + 201n)
    await expect(tx).to.be.revertedWith('A013');

    // retirement amount must be greater than 0
    tx = httManager.connect(props.owners[1]).retireHEXTimeTokens(0, 0, 0)
    await expect(tx).to.be.revertedWith('A024');

    // can't retire more token than you have 
    tx = httManager.connect(props.owners[1]).retireHEXTimeTokens(0, 0, (shares[1].stakedHearts / 2n) + 1n)
    await expect(tx).to.be.revertedWith('A001');

    // can't mint tokens on a fully served stake even if it's not matured
    tx = httManager.connect(props.owners[2]).mintHEXTimeTokens(0, shares[2].stakedHearts / 2n, shares[2].lockedDay + shares[2].stakedDays)
    await expect(tx).to.be.revertedWith('A014');

    // only the owner can unlock a fully served collateralized stake
    const hedronHsiIndex = await httManager.findHedronHSIIndex(shares[1].hsiAddress)
    tx = httManager.connect(props.owners[0]).endCollateralizedHEXStake(shares[1].hsiAddress, 0n, 0n, hedronHsiIndex)
    await expect(tx).to.be.revertedWith('A022');

    // ensure owner can unlock a fully served collateralized stake
    await httManager.connect(props.owners[1]).endCollateralizedHEXStake(shares[1].hsiAddress, 0n, 0n, hedronHsiIndex)

    // ensure correct hsi index
    tx = httManager.connect(props.owners[1]).endHEXStake(0, hedronHsiIndex + 1n)
    await expect(tx).to.be.revertedWith('A012');
  });

});
