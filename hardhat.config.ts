require('dotenv').config();
import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "hardhat-gas-reporter"

const config: HardhatUserConfig = {
  solidity: "0.8.26",
  networks: {
    hardhat: {
      initialBaseFeePerGas: 0, // https://github.com/NomicFoundation/hardhat/issues/3089#issuecomment-1366428941
      allowUnlimitedContractSize: true,
      blockGasLimit: 1000000000,
      forking: {
        url: process.env.ALCHEMY_URL as string,
        blockNumber: 20000000,
      },
    },
    localhost: {
      timeout: 1200000,
    },
    pulsechain_testnet: {
      url: 'https://rpc.v4.testnet.pulsechain.com',
      accounts: [process.env.DEV_DEPLOYMENT_PRIVATE_KEY as string]
    },
    dev_remote: {
      url: `http://${process.env.DEV_REMOTE_URL}`,
      initialBaseFeePerGas: 0, 
      allowUnlimitedContractSize: true,
      blockGasLimit: 1000000000,
    },
  },
  mocha: {
    timeout: 6000000,
    bail: true
  },
  gasReporter: {
    enabled: false,
  }
};

export default config;
