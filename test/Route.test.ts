import deployContract from "../scripts/utils/deploy";
import { ethers } from "hardhat";
import { expect } from "chai";
const TEN_TO_18 = Math.pow(10, 18);
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
      console.error(error);
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
    console.log("----------------------------------------")
    console.log(amm[0][0].toString())
    console.log(amm[1].toString())
    console.log("----------------------------------------")
    expect(amm[1].toString()).to.not.equal("0");
  });

  it("if you don't sell enough x to level two Amms, swap only on one of them", async function () {
    const amm = await this.route.routeWrapper(
      [
        toStringMap([3 * TEN_TO_18, 4 * TEN_TO_18]),
        toStringMap([2 * TEN_TO_18, 4 * TEN_TO_18]),
      ],
      `${0.4 * TEN_TO_18}`
    );
    console.log("----------------------------------------")
    console.log(amm[0][0].toString())
    console.log(amm[0][1].toString())
    console.log(amm[1].toString())
    console.log("----------------------------------------")

    expect(amm[1].toString()).to.not.equal("0");
  });

});

// helper functions for testing
const toStringMap = (nums: number[]) => nums.map((num) => `${num}`);
