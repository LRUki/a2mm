import { ethers } from "hardhat";
import { expect } from "chai";
import { Token, tokenToAddress } from "../scripts/utils/Token";
describe("==================================== ReserveFeed ====================================", function () {
  before(async function () {
    this.ReserveFeed = await ethers.getContractFactory("ReserveFeed");
  });
  beforeEach(async function () {
    this.reserveFeed = await this.ReserveFeed.deploy();
    await this.reserveFeed.deployed();
  });

  it("ReserveFeed fetches coorrect reserves from Sushi", async function () {
    const [reserveIn, reserveOut] = await this.reserveFeed.getSushiReserves(
      tokenToAddress[Token.WETH],
      tokenToAddress[Token.USDT]
    );
    expect(reserveIn.toString()).to.equal("29364268457386578591426");
    expect(reserveOut.toString()).to.equal("119932108135609");
  });

  it("ReserveFeed fetches correct reserves from Uni", async function () {
    const [reserveIn, reserveOut] = await this.reserveFeed.getUniV2Reserves(
      tokenToAddress[Token.WETH],
      tokenToAddress[Token.USDT]
    );
    expect(reserveIn.toString()).to.equal("18262402920424041436553");
    expect(reserveOut.toString()).to.equal("74581172364512");
  });
});
