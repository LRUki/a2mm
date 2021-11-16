import { ethers } from "hardhat";
import { expect } from "chai";
import { BigNumber } from "@ethersproject/bignumber";
const TEN_TO_18 = Math.pow(10, 18);
describe("==================================== SharedFunctions ====================================", function () {
  before(async function () {
    this.SharedFunctions = await ethers.getContractFactory("SharedFunctions");
  });
  beforeEach(async function () {
    this.sharedFunctions = await this.SharedFunctions.deploy();
    await this.sharedFunctions.deployed();
  });

  it("sqrt gives correct output", async function () {
    let num = 3000000;
    let res = await this.sharedFunctions.sqrt(num);
    expect(res.toString()).to.equal(Math.floor(Math.sqrt(num)).toString());
    num = 0;
    res = await this.sharedFunctions.sqrt(num);
    expect(res.toString()).to.equal(Math.floor(Math.sqrt(num)).toString());
  });

  it("quantityOfYForX gives correct output", async function () {
    const res = await this.sharedFunctions._quantityOfYForX(
      `${100 * TEN_TO_18}`,
      `${200 * TEN_TO_18}`,
      `${200}`
    );
    console.log(res.toString(), "x to approach in Solidity");
    const exp = quantityOfYForX(
      100 * TEN_TO_18,
      200 * TEN_TO_18,
      200
    );
    console.log(
      exp,
      "x to approach in TSX"
    );
  });

  it("sortAmmArrayIndicesByExchangeRate gives correct output", async function () {
    let testExamples =
      [
        {
          ammsArray: [
            toStringMap([1 * TEN_TO_18, 2 * TEN_TO_18]),
            toStringMap([1 * TEN_TO_18, 4 * TEN_TO_18]),
            toStringMap([0.2 * TEN_TO_18, 0.2 * TEN_TO_18]),
          ],
          result: [2, 0, 1]
        },
        {
          ammsArray: [
            toStringMap([1 * TEN_TO_18, 2 * TEN_TO_18]),
            toStringMap([2 * TEN_TO_18, 4 * TEN_TO_18]),
            toStringMap([0.2 * TEN_TO_18, 0.4 * TEN_TO_18]),
          ],
          result: [0, 1, 2]
        },
      ]
    for (const element of testExamples) {
      const res = await this.sharedFunctions.sortAmmArrayIndicesByExchangeRateWrapper(element.ammsArray)
      expect(res.toString()).to.equal((element.result).toString());
    }
  });


  it("calculates x to spend on better amm to approach the worse amm", async function () {
    const res = await this.sharedFunctions.howMuchXToSpendToLevelAmmsWrapper(
      toStringMap([100 * TEN_TO_18, 200 * TEN_TO_18]),
      toStringMap([100 * TEN_TO_18, 180 * TEN_TO_18])
    );
    //TODO: how to match the results?
    console.log(res.toString(), "x to approach the worse amm in Solidity");
    console.log(
      res,
      "x to approach the worse amm JS"
    );
  });

  it("leveledAmms get split correctly", async function () {
    const res = await this.sharedFunctions.howToSplitRoutingOnLeveledAmmsWrapper(
      [
        toStringMap([1 * TEN_TO_18, 2 * TEN_TO_18]),
        toStringMap([2 * TEN_TO_18, 4 * TEN_TO_18]),
        toStringMap([0.1 * TEN_TO_18, 0.2 * TEN_TO_18]),
      ],
      `${0.000031 * TEN_TO_18}`
    );
    const [p1, p2, p3]: number[] = res.map((v: BigNumber) => v.toNumber());
    expect(p2 / p1).to.equal(2);
    expect(p1 / p3).to.equal(10);
  });
});


// helper functions for testing
const toStringMap = (nums: number[]) => nums.map((num) => `${num}`);

const quantityOfYForX = (
  x: number,
  y: number,
  dx: number
): number => {
  expect(x > 0 && y > 0)
  if (dx == 0)
    return 0
  let q = y / (1000 * x + 997 * dx);
  let r = y - q * (1000 * x + 997 * dx); //r = y % (1000*amm.x + 997*x)
  return 1000 * dx * q + 1000 * dx * r / (1000 * x + 997 * dx);
};
