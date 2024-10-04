import { ethers } from "hardhat";
import * as Const from "./constants";

async function main() {
  const actuatorAddress = ''
  const lock = await ethers.deployContract("TimeLock", [
    actuatorAddress,
    process.env.TEAM_ADDRESS_2 as string, 
    Const.TEAM_EMISSION_SCHEDULE,  
  ]);

  await lock.waitForDeployment();

  console.log(`Deployed TimeLock to ${lock.target}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
