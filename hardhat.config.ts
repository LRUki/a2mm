/**
 * @type import('hardhat/config').HardhatUserConfig
 */
import "@nomiclabs/hardhat-waffle";
import "@openzeppelin/hardhat-upgrades";

import { mnemonic, url } from "./secret.json";

export default {
  solidity: "0.8.4",
  networks: {
    ropsten: {
      url: url,
      accounts: { mnemonic: mnemonic },
    },
  },
};
