import { ethers } from "hardhat";
import * as Const from "./constants";
import HEX_ABI from "../abi/hexABI.json";
import _ from 'lodash'
import fs from "fs";

export const getPayouts = async () => {
  const [owner] = await ethers.getSigners();
  const hexContract = new ethers.Contract(Const.HEX_ADDRESS, HEX_ABI, owner);
  const currentDay = await hexContract.currentDay()
  
  const payoutsRaw: string[] = JSON.parse(await fs.readFileSync('./scripts/payouts.json', 'utf8'))
  const payouts = payoutsRaw.map(p => BigInt(p))
  if ((payouts.length + Const.PAYOUT_START_DAY) < currentDay) {
    const tx = await hexContract.dailyDataUpdate(currentDay);
    await tx.wait();
  
    for (let i = (payouts.length + Const.PAYOUT_START_DAY); i < currentDay; i++) {
      const data = await hexContract.dailyData(i);
      const dayPayoutTotal = data[0];
      const dayStakeSharesTotal = data[1];
      let dailyReward = 0n;
      if (dayStakeSharesTotal !== 0n && dayPayoutTotal !== 0n) {
        dailyReward = (dayPayoutTotal * Const.PAYOUT_RESOLUTION) / dayStakeSharesTotal;
      }
  
      payouts.push(payouts[payouts.length - 1] + dailyReward)
    }

    const data = JSON.stringify(payouts.map(p => p.toString()), null, 2);
    await fs.writeFileSync('./scripts/payouts.json', data)
  }

  return payouts
}

export function getRandomNumber(min: number, max: number) {
  return Math.floor(Math.random() * (max - min + 1)) + min;
}

export const nullish = (val: any) => {
  return val === null || val === undefined
}

