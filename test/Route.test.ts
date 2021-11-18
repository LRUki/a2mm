import deployContract from "../scripts/utils/deploy";
import { ethers } from "hardhat";
import { expect } from "chai";
import {TEN_TO_18, toStringMap} from "./HelperFunctions";

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

  it("Routing with an empty array causes error", async function () {
    var throwsError = false;
    try {
      const amm = await this.route.routeWrapper(
        [],
        `${0.4 * TEN_TO_18}`
      );
    }
    catch(error){
      throwsError = true;
    }
    expect(throwsError).to.equal(true);
  });

  it("When only one Amm is supplied for routing -> normal swap", async function () {
    const amm = await this.route.routeWrapper(
      [
        toStringMap([2 * TEN_TO_18, 4 * TEN_TO_18]),
      ],
      `${0.4 * TEN_TO_18}`
    );
    const exp = 6649991662 * Math.pow(10, 8);
    expect(Math.round((amm[1]-exp)/(Math.pow(10,8))).toString()).to.equal((0).toString());
  });

  it("if you don't sell enough x to level two Amms, swap only on one of them", async function () {
    const amm = await this.route.routeWrapper(
      [
        toStringMap([3 * TEN_TO_18, 4 * TEN_TO_18]),
        toStringMap([2 * TEN_TO_18, 4 * TEN_TO_18]),
      ],
      `${0.4 * TEN_TO_18}`
    );
    const exp = 6649991662 * Math.pow(10, 8);
    expect(Math.round((amm[1]-exp)/(Math.pow(10,8))).toString()).to.equal((0).toString());
  });

  it("check that the sum of amount to spend on different amms eguals to amount spent", async function () {
    let xToSpend = BigInt(6 * TEN_TO_18);
    const amm = await this.route.routeWrapper(
      [
        toStringMap([2 * TEN_TO_18, 3 * TEN_TO_18]),
        toStringMap([0.2 * TEN_TO_18, 0.3 * TEN_TO_18]),
        toStringMap([4 * TEN_TO_18, 6 * TEN_TO_18]),
        toStringMap([2 * TEN_TO_18, 3 * TEN_TO_18]),
      ],
      `${xToSpend}`
    );
    var sum = BigInt(0);
    for (let i = 0; i < amm[0].length; i++) {
        sum += BigInt(amm[0][i])
    }

    expect(Math.abs(Number(sum) - Number(xToSpend))).to.lessThan(10);
  });
});
