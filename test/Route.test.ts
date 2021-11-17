import deployContract from "../scripts/utils/deploy";
import { ethers } from "hardhat";
import { expect } from "chai";
import whatPrecision from "./Arbitrage.test";

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
    console.log("----------------------------------------")
    console.log(amm[0][0].toString())
    console.log(amm[0][1].toString())
    console.log(amm[1].toString())
    console.log("----------------------------------------")
    expect(Math.round((amm[1]-exp)/(Math.pow(10,8))).toString()).to.equal((0).toString());
  });

  // it(" check that sum_{i in amms} (x_{i}^{new} - x_{i}^{old}) ~= x_{spent}", async function () {
    // const amm = await this.route.routeWrapper(
    //   [
    //     toStringMap([2 * TEN_TO_18, 3 * TEN_TO_18]),
    //     toStringMap([0.2 * TEN_TO_18, 0.3 * TEN_TO_18]),
    //     toStringMap([4 * TEN_TO_18, 6 * TEN_TO_18]),
    //     toStringMap([2 * TEN_TO_18, 3 * TEN_TO_18]),
    //   ],
    //   `${4 * TEN_TO_18}`
    // );
    // var sum = BigInt(0);
    // for (let i = 0; i < amm[0].length; i++) {
    //     sum += BigInt(amm[0][i])
    // }
    // console.log(sum.toString());
    // console.log(amm[0].toString());
    

    //expect(sum.toString()).to.equal(amm[0].toString());
  // });
});

// helper functions for testing
const toStringMap = (nums: number[]) => nums.map((num) => `${num}`);
