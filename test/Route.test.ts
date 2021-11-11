import { ethers } from "hardhat";
import { expect } from "chai";
import deployContract from "../scripts/utils/deploy";
import { BigNumber } from "@ethersproject/bignumber";
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

  it("calculates x to spend on better amm to approach the worse amm", async function () {
    const res = await this.route.howMuchXToSpendToLevelAmms(
      toStringMap([100 * TEN_TO_18, 200 * TEN_TO_18]),
      toStringMap([100 * TEN_TO_18, 180 * TEN_TO_18])
    );
    //TODO: how to match the results?
    console.log(res.toString(), "x to approach the worse amm in Solidity");
    console.log(
      howMuchXToSpendToLevelAmms(
        [100 * TEN_TO_18, 200 * TEN_TO_18],
        [100 * TEN_TO_18, 180 * TEN_TO_18]
      ),
      "x to approach the worse amm JS"
    );
  });

  it("leveledAmms get split correctly", async function () {
    const res = await this.route.howToSplitRoutingOnLeveledAmms(
      [
        toStringMap([100 * TEN_TO_18, 200 * TEN_TO_18]),
        toStringMap([200 * TEN_TO_18, 400 * TEN_TO_18]),
        toStringMap([10 * TEN_TO_18, 20 * TEN_TO_18]),
      ],
      `${31 * TEN_TO_18}`
    );
    const [p1, p2, p3]: number[] = res.map((v: BigNumber) => v.toNumber());
    expect(p2 / p1).to.equal(2);
    expect(p1 / p3).to.equal(10);
  });

  // it("Route runs", async function () {
  //   const tenToTheNine = Math.pow(10, 9);
  //   const amm = await this.route.route(
  //     [
  //       [2000 * tenToTheNine, 4000 * tenToTheNine],
  //       [1600 * tenToTheNine, 2000 * tenToTheNine],
  //       [1000 * tenToTheNine, 2000 * tenToTheNine],
  //     ],
  //     3 * tenToTheNine
  //   );
  //   console.log(amm.toString(), "ROUTE");
  // });
});

// helper functions for testing
const toStringMap = (nums: number[]) => nums.map((num) => `${num}`);

const howMuchXToSpendToLevelAmms = (
  betterAmm: number[],
  worseAmm: number[]
): number => {
  const [x1, y1] = betterAmm;
  const [x2, y2] = worseAmm;
  return (
    Math.floor(
      1002 * sqrt(x1 * y2 * (2.257 * Math.pow(10, -6) * x1 * y2 + x2 * y1)) -
        x1 * y2
    ) /
    (y2 * 1000)
  );
};

const sqrt = (x: number): number => {
  let z = Math.floor((x + 1) / 2);
  let y = x;
  while (z < y) {
    y = z;
    z = Math.floor((Math.floor(x / z) + z) / 2);
  }
  return y;
};
