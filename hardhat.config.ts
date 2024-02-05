import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
const fs = require("fs");

const privateKey = fs.readFileSync(".secret").toString("utf-8");
const infuraKey = fs.readFileSync(".infura").toString("utf-8");

const config: HardhatUserConfig = {
  etherscan: {
    apiKey: {
      blast_sepolia: "blast_sepolia", // apiKey is not required, just set a placeholder
    },
    customChains: [
      {
        network: "blast_sepolia",
        chainId: 168587773,
        urls: {
          apiURL: "https://api.routescan.io/v2/network/testnet/evm/168587773/etherscan",
          browserURL: "https://testnet.blastscan.io"
        }
      }
    ]
  },
  networks: {
    mumbai: {
      url: "https://polygon-mumbai.infura.io/v3/" + infuraKey,
      accounts: [privateKey],
      timeout: 1000000,
      gas: 8000000,
      gasPrice: 8000000000,
    },
    blast_sepolia: {
      url: "https://sepolia.blast.io",
      accounts: [privateKey],
      gasPrice: 1000000000,
    },
  },
  solidity: {
    compilers: [
      {
        version: "0.8.9",
      },
      {
        version: "0.8.20",
        settings: {
          optimizer: {
            enabled: true,
            runs: 10000,
          },
        },
      },
    ],
  },
};

export default config;
