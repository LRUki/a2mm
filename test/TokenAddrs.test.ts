import { expect } from "chai";
import { ethers } from "hardhat";
describe("TokenAddrs", function () {
  before(async function () {
    this.TokenAddrs = await ethers.getContractFactory("TokenAddrs");
  });

  beforeEach(async function () {
    this.tokenAddrs = await this.TokenAddrs.deploy();
    await this.tokenAddrs.deployed();
  });

  // Test case
  // it("returns correct token addresses on ETH mainchain", async function () {
  // const WETH_ADDR = await this.tokenAddrs.getAddr(0);
  // expect(WETH_ADDR.toString()).to.equal(
  //   "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"
  // );
  // });
});
