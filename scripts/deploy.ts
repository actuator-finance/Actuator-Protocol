import { ethers } from "hardhat";
import * as Const from "./constants";

async function main() {
  const currentTime = Math.floor(Date.now() / 1000);
  const lock = await ethers.deployContract("HEXTimeTokenManager", [
    process.env.TEAM_ADDRESS, 
    Const.AMM_FACTORY_ADDRESS,
    [0n], 
    currentTime,
    Const.FARM_EMISSION_SCHEDULE,
    Const.TEAM_EMISSION_SCHEDULE,
    Const.POOL_POINT_SCHEDULE,
  ]);

  await lock.waitForDeployment();

  console.log(`Deployed to ${lock.target}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
