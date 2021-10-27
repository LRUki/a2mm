import { expect } from "chai";
import { ethers } from "hardhat";
describe("TokenAddrs", function () {
  before(async function () {
    this.TokenAddrs = await ethers.getContractFactory("TokenAddrs");
  });

  beforeEach(async function () {
    this.tokenAddrs = await this.TokenAddrs.deploy();
    //console.log(this.tokenAddrs.Token);
    await this.tokenAddrs.deployed();
  });

  // Test case
  it("returns correct token addresses on ETH mainchain", async function () {
    //how to access the enum?
    //     const WETH_ADDR = await this.tokenAddrs.getAddr(0);
    //     expect(WETH_ADDR.toString()).to.equal(
    //       "0x0a180A76e4466bF68A7F86fB029BEd3cCcFaAac5"
    //     );
  });
});
