import { HardhatUserConfig } from 'hardhat/config';
import '@nomicfoundation/hardhat-toolbox';
import '@nomicfoundation/hardhat-viem';
import '@nomicfoundation/hardhat-verify';
import 'dotenv/config';

const PRIVATE_KEY = process.env.PRIVATE_KEY || '';
const MANTLE_RPC_URL = process.env.MANTLE_RPC_URL || 'https://rpc.mantle.xyz';
const MANTLE_TESTNET_RPC_URL =
  process.env.MANTLE_TESTNET_RPC_URL || 'https://rpc.sepolia.mantle.xyz';
const MANTLESCAN_API_KEY = process.env.MANTLESCAN_API_KEY || '';

const config: HardhatUserConfig = {
  solidity: {
    version: '0.8.26',
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
      viaIR: false,
      evmVersion: 'cancun',
    },
  },
  paths: {
    sources: './src',
    tests: './test',
    cache: './cache_hardhat',
    artifacts: './artifacts',
  },
  networks: {
    hardhat: {
      chainId: 31337,
      forking: {
        url: MANTLE_TESTNET_RPC_URL,
        enabled: false,
      },
    },
    localhost: {
      url: 'http://127.0.0.1:8545',
      chainId: 31337,
    },
    mantleTestnet: {
      url: MANTLE_TESTNET_RPC_URL,
      chainId: 5003,
      accounts: PRIVATE_KEY ? [PRIVATE_KEY] : [],
      gasPrice: 1000000000, // 1 gwei
    },
    mantle: {
      url: MANTLE_RPC_URL,
      chainId: 5000,
      accounts: PRIVATE_KEY ? [PRIVATE_KEY] : [],
      gasPrice: 1000000000, // 1 gwei
    },
  },
  etherscan: {
    apiKey: {
      mantleTestnet: MANTLESCAN_API_KEY,
      mantle: MANTLESCAN_API_KEY,
    },
    customChains: [
      {
        network: 'mantleTestnet',
        chainId: 5003,
        urls: {
          apiURL: 'https://explorer.sepolia.mantle.xyz/api',
          browserURL: 'https://explorer.sepolia.mantle.xyz',
        },
      },
      {
        network: 'mantle',
        chainId: 5000,
        urls: {
          apiURL: 'https://explorer.mantle.xyz/api',
          browserURL: 'https://explorer.mantle.xyz',
        },
      },
    ],
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS !== undefined,
    currency: 'USD',
    coinmarketcap: process.env.COINMARKETCAP_API_KEY,
  },
  mocha: {
    timeout: 100000,
  },
};

export default config;
