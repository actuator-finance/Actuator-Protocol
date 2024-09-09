import { ethers } from "hardhat";
import * as Const from "./constants";

async function main() {
  const actuatorAddress = '0x08B2A0BCc821730C1f7c36CC89B1F7393Db61cc7'
  const lock = await ethers.deployContract("TimeLock", [
    actuatorAddress,
    process.env.TEAM_ADDRESS as string, 
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
