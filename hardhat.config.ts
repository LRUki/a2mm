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
      },
      {
        version: "0.6.6",
      },
    ],
  },
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {
      //https://hardhat.org/hardhat-network/guides/mainnet-forking.html
      forking: {
        url: `https://eth-mainnet.alchemyapi.io/v2/${process.env.ALCHEMY_KEY}`,
        blockNumber: 13482613,
      },
    },
    ropsten: {
      url: url,
      accounts: { mnemonic: mnemonic },
    },
  },
};
