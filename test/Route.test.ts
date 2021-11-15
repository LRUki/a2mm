import deployContract from "../scripts/utils/deploy";
import { ethers } from "hardhat";
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

  it("Route runs", async function () {
    //TODO: test this properly
    const amm = await this.route.routeWrapper(
      [
        toStringMap([1 * TEN_TO_18, 2 * TEN_TO_18]),
        toStringMap([2 * TEN_TO_18, 4 * TEN_TO_18]),
        toStringMap([0.1 * TEN_TO_18, 0.2 * TEN_TO_18]),
      ],
      `${0.000031 * TEN_TO_18}`
    );
    console.log(amm.toString(), "ROUTE");
  });
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
    (1.002 * sqrt(x1 * y2 * (2.257 * Math.pow(10, -6) * x1 * y2 + x2 * y1)) -
      x1 * y2) /
    y2
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
