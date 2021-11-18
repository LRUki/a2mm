import { ethers } from "hardhat";
import { expect } from "chai";
import deployContract from "../scripts/utils/deploy";
import { Token, tokenToDecimal } from "../scripts/utils/Token";
describe("==================================== UniV3PriceFeed ====================================", function () {
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
    const ethAmount = `${Math.pow(10, tokenToDecimal[Token.WETH])}`;

    const tx = await this.uniV3PriceFeed.getPrice(
      Token.WETH,
      Token.USDT,
      ethAmount
    );
    const txStatus = await tx.wait();
    expect(txStatus.events).to.have.lengthOf(1);
    expect(txStatus.events[0].event).to.equal("GetPrice");
    const { tokenIn, tokenOut, amountIn, amountOut } = txStatus.events[0].args;
    expect(tokenIn).to.equal("0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2");
    expect(tokenOut).to.equal("0xdAC17F958D2ee523a2206206994597C13D831ec7");
    expect(amountIn.toString()).equal(ethAmount);
    expect(amountOut.toString()).equal("4069872621");
  });
});
