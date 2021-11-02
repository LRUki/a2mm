import { ethers } from "hardhat";
import deployContract from "../scripts/utils/deploy";
import { Token, tokenToDecimal } from "../scripts/utils/Token";
describe("UniV3PriceFeed", function () {
  before(async function () {
    const tokenAddrsLibraryAddress = await deployContract("TokenAddrs");
    this.UniV3PriceFeed = await ethers.getContractFactory("UniV3PriceFeed", {
      libraries: { TokenAddrs: tokenAddrsLibraryAddress },
    });
  });

  beforeEach(async function () {
    this.uniV3PriceFeed = await this.UniV3PriceFeed.deploy();
    await this.uniV3PriceFeed.deployed();
  });

  // Test case
  it("getPrice emits the correct WETH:USDT price", async function () {
    const getPriceTxn = await this.uniV3PriceFeed.getPrice(
      Token.WETH,
      Token.USDT,
      `${Math.pow(10, tokenToDecimal[Token.WETH])}`
    );
    await getPriceTxn.wait();
  });
});
