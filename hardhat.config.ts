import * as dotenv from "dotenv";
dotenv.config();

import "solidity-coverage";
import "@nomicfoundation/hardhat-toolbox";
import { HardhatUserConfig } from "hardhat/config";

const POLYGON_MUMBAI_PRIVATE_KEY = process.env.POLYGON_MUMBAI_PRIVATE_KEY!;

const POLYGON_PRIVATE_KEY = process.env.POLYGON_PRIVATE_KEY!;

const MAINNET_PRIVATE_KEY = process.env.MAINNET_PRIVATE_KEY!;

const optimizedComilerSettings = {
  version: "0.8.17",
  settings: {
    optimizer: { enabled: true, runs: 1000000 },
    viaIR: true,
  },
};
const entrypointRelatedComilerSettings = {
  version: "0.8.15",
  settings: {
    optimizer: { enabled: true, runs: 1000000 },
    viaIR: true,
  },
};

/** @type import('hardhat/config').HardhatUserConfig */
const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: "0.8.17",
        settings: {
          optimizer: {
            enabled: true,
            runs: 50000,
          },
          viaIR: true,
        },
      },
    ],
    overrides: {
      "contracts/entrypoint/EntryPoint.sol": optimizedComilerSettings,
      "contracts/utils/Exec.sol": entrypointRelatedComilerSettings,
    },
  },
  typechain: {
    outDir: "src/types",
    target: "ethers-v5",
    alwaysGenerateOverloads: false, // should overloads with full signatures like deposit(uint256) be generated always, even if there are no overloads?
    externalArtifacts: ["externalArtifacts/*.json"], // optional array of glob patterns with external artifacts to process (for example external libs from node_modules)
    dontOverrideCompile: false, // defaults to false
  },
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {
      allowUnlimitedContractSize: true,
      accounts: {
        mnemonic: "test test test test test test test test test test test junk",
        initialIndex: 0,
        accountsBalance: "10000000000000000000000000", // 10,000,000 ETH
      },
    },
    localhost: {
      allowUnlimitedContractSize: true,
    },
    mumbai: {
      url: process.env.POLYGON_MUMBAI_PROVIDER || "",
      accounts: [POLYGON_MUMBAI_PRIVATE_KEY],
      gasPrice: "auto",
      timeout: 1000000,
    },
    polygon: {
      url: process.env.POLYGON_PROVIDER || "",
      accounts: [POLYGON_PRIVATE_KEY],
      gasPrice: "auto",
      timeout: 1000000,
    },
    mainnet: {
      url: process.env.ETH_MAINNET_PROVIDER || "",
      accounts: [MAINNET_PRIVATE_KEY],
      gasPrice: "auto",
      timeout: 1000000,
    },
  },
  etherscan: {
    apiKey: {
      polygon: process.env.POLYGONSCAN_API_KEY || "",
      mainnet: process.env.ETHERSCAN_API_KEY || "",
      mumbai: process.env.POLYGON_MUMBAI_POLYGONSCAN_API_KEY || "",
    },
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts",
  },
  gasReporter: {
    currency: "USD",
    coinmarketcap: process.env.COINMARKETCAP_API_KEY || "",
    enabled: true,
  },
  mocha: {
    timeout: 100000000,
  },
};

export default config;
