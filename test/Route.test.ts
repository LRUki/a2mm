import deployContract from "../scripts/utils/deploy";
import { ethers } from "hardhat";
import { expect } from "chai";
import { toStringMap } from "../scripts/utils/math";

describe("==================================== Route ====================================", function () {
  before(async function () {
    const sharedFunctionAddress = await deployContract("SharedFunctions");
    this.Route = await ethers.getContractFactory("Route", {
      libraries: { SharedFunctions: sharedFunctionAddress },
    });
  });
  beforeEach(async function () {
    this.route = await this.Route.deploy();
    await this.route.deployed();
  });

  it("Routing with no AMMs causes error", async function () {
    var throwsError = false;
    try {
      await this.route.routeWrapper([], `${ethers.utils.parseEther("0.4")}`);
    } catch (error) {
      throwsError = true;
    }
    expect(throwsError).to.equal(true);
  });

  it("When only one Amm is supplied for routing -> normal swap", async function () {
    const amm = await this.route.routeWrapper(
      [toStringMap([ethers.utils.parseEther("2"),ethers.utils.parseEther("4")])],
      `${ethers.utils.parseEther("0.4")}`
    );
    const exp = 6649991662 * Math.pow(10, 8);
    expect(Math.round((amm[1] - exp) / Math.pow(10, 8)).toString()).to.equal(
      (0).toString()
    );
  });

  it("if you don't sell enough x to level two Amms, swap only on one of them", async function () {
    const amm = await this.route.routeWrapper(
      [
        toStringMap([ethers.utils.parseEther("3"), ethers.utils.parseEther("4")]),
        toStringMap([ethers.utils.parseEther("2"), ethers.utils.parseEther("4")]),
      ],
      `${ethers.utils.parseEther("0.4")}`
    );
    const exp = 6649991662 * Math.pow(10, 8);
    expect(Math.round((amm[1] - exp) / Math.pow(10, 8)).toString()).to.equal(
      (0).toString()
    );
  });

  it("check that the sum of amount to spend on different amms eguals to amount spent", async function () {
    let xToSpend = BigInt(ethers.utils.parseEther("6").toString());
    const amm = await this.route.routeWrapper(
      [
        toStringMap([ethers.utils.parseEther("2"), ethers.utils.parseEther("3")]),
        toStringMap([ethers.utils.parseEther("0.2"), ethers.utils.parseEther("0.3")]),
        toStringMap([ethers.utils.parseEther("4"), ethers.utils.parseEther("6")]),
        toStringMap([ethers.utils.parseEther("2"), ethers.utils.parseEther("3")]),
      ],
      `${xToSpend}`
    );
    var sum = BigInt(0);
    for (let i = 0; i < amm[0].length; i++) {
      sum += BigInt(amm[0][i]);
    }

    expect(Math.abs(Number(sum) - Number(xToSpend))).to.lessThan(10);
  });
});
