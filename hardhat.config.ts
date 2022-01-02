/**
 * @type import('hardhat/config').HardhatUserConfig
 */
import "@nomiclabs/hardhat-waffle";
import "@openzeppelin/hardhat-upgrades";
import { mnemonic, url } from "./secret.json";

export default {
  solidity: {
    compilers: [
      {
        version: "0.8.3",
        settings: {
          optimizer: {
            enabled: true,
          },
        },
      },
      {
        version: "0.6.6",
        settings: {
          optimizer: {
            enabled: true,
          },
        },
      },
    ],
  },
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {
      chainId: 1,
      forking: {
        url: "https://speedy-nodes-nyc.moralis.io/0786eddbee701c23817a1112/eth/mainnet/archive",
        blockNumber: 13482613,
      },
    },
    ropsten: {
      url: url,
      accounts: { mnemonic: mnemonic },
    },
  },
};
