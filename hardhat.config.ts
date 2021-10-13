/**
 * @type import('hardhat/config').HardhatUserConfig
 */
import "@nomiclabs/hardhat-waffle";
import "@openzeppelin/hardhat-upgrades";
import { url, mnemonic } from "./secret.json";

export default {
  solidity: "0.8.4",
  networks: {
    ropsten: {
      url,
      accounts: { mnemonic: mnemonic },
    },
  },
};
