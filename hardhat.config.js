import "@nomicfoundation/hardhat-toolbox";
import "@openzeppelin/hardhat-upgrades";
import "dotenv/config";

/** @type import('hardhat/config').HardhatUserConfig */
export default {
  solidity: {
    version: "0.8.26",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  networks: {
    polygon: {
      url: process.env.POLYGON_RPC_URL || "https://polygon-rpc.com",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
      chainId: 137,
      // Aggressive Gas Settings for Reliability
      gasPrice: 500000000000, // 500 Gwei (Network is at 410, we bid higher)
      timeout: 200000, // 200 Seconds
    },
    amoy: {
      url: "https://rpc-amoy.polygon.technology",
      chainId: 80002,
    },
  },
  etherscan: {
    apiKey: process.env.POLYGONSCAN_API_KEY,  // Single key for Etherscan API V2
  },
  sourcify: {
    enabled: true  // Backup verification via Sourcify
  },
};
