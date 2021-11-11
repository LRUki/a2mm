import { ethers } from "hardhat";
import { expect } from "chai";
import { Token, tokenToAddress, tokenToDecimal } from "../scripts/utils/Token";
import { Factory, factoryToAddress } from "../scripts/utils/Factory";
describe("==================================== DexProvider ====================================", function () {
  before(async function () {
    this.DexProvider = await ethers.getContractFactory("DexProvider");
  });
  beforeEach(async function () {
    this.dexProvider = await this.DexProvider.deploy();
    await this.dexProvider.deployed();
  });

  it("ReserveFeed fetches coorrect reserves from Sushi", async function () {
    const [reserveIn, reserveOut] = await this.dexProvider.getSushiReserves(
      tokenToAddress[Token.WETH],
      tokenToAddress[Token.USDT]
    );
    expect(reserveIn.toString()).to.equal("29364268457386578591426");
    expect(reserveOut.toString()).to.equal("119932108135609");
  });

  it("ReserveFeed fetches correct reserves from Uni", async function () {
    const [reserveIn, reserveOut] = await this.dexProvider.getUniV2Reserves(
      tokenToAddress[Token.WETH],
      tokenToAddress[Token.USDT]
    );
    expect(reserveIn.toString()).to.equal("18262402920424041436553");
    expect(reserveOut.toString()).to.equal("74581172364512");
  });

  // it("Swaps at uni", async function () {
  //   let [reserveIn, reserveOut] = await this.dexProvider.getUniV2Reserves(
  //     tokenToAddress[Token.WETH],
  //     tokenToAddress[Token.USDT]
  //   );
  //   console.log(reserveIn.toString(), reserveOut.toString(), "Before");
  //   this.dexProvider.executeSwap(
  //     factoryToAddress[Factory.UNIV2],
  //     tokenToAddress[Token.WETH],
  //     tokenToAddress[Token.USDT],
  //     10 * tokenToDecimal[Token.WETH]
  //   );

  //   [reserveIn, reserveOut] = await this.dexProvider.getUniV2Reserves(
  //     tokenToAddress[Token.WETH],
  //     tokenToAddress[Token.USDT]
  //   );
  //   console.log(reserveIn.toString(), reserveOut.toString(), "After");
  // });
});
