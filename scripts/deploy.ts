import { ethers } from "hardhat";
import * as Const from "./constants";
import * as Util from "./util";

async function main() {
  const lock = await ethers.deployContract("HEXTimeTokenManager", [
    process.env.TEAM_ADDRESS, 
    process.env.PULSEX_FACTORY_ADDRESS,
    [0n], 
    1728432000,
    Const.FARM_EMISSION_SCHEDULE,
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
